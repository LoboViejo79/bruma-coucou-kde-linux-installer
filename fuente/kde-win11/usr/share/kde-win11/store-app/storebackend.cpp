#include "storebackend.h"

#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFileSystemWatcher>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocale>
#include <QPalette>
#include <QProcess>
#include <QSettings>
#include <QStorageInfo>
#include <QStyleHints>
#include <QThread>
#include <QTimer>
#include <QUrl>

#include <flatpak.h>

#include <pwd.h>
#include <signal.h>
#include <unistd.h>

#include <functional>
#include <mutex>
#include <thread>

static const char FLATHUB_REPO[] = "https://dl.flathub.org/repo/flathub.flatpakrepo";

// Flathub en la instalación de usuario: instalar no pide contraseña
static void ensureUserRemote()
{
    static std::once_flag once;
    std::call_once(once, [] {
        QProcess::execute(QStringLiteral("flatpak"),
                          {QStringLiteral("remote-add"), QStringLiteral("--user"), QStringLiteral("--if-not-exists"), QStringLiteral("flathub"),
                           QString::fromLatin1(FLATHUB_REPO)});
    });
}

// Espacio libre donde se instalan las apps de usuario
static qint64 freeBytes()
{
    const QString dir = QDir::homePath() + QStringLiteral("/.local/share/flatpak");
    QStorageInfo info(QFileInfo::exists(dir) ? dir : QDir::homePath());
    return info.bytesAvailable();
}

// Mensajes de libflatpak/OSTree (en inglés) traducidos a algo comprensible
static QString friendlyError(const QString &raw)
{
    const QString m = raw.toLower();
    if (m.contains(QLatin1String("could not resolve")) || m.contains(QLatin1String("couldn't resolve")) || m.contains(QLatin1String("network"))
        || m.contains(QLatin1String("timeout")) || m.contains(QLatin1String("timed out")) || m.contains(QLatin1String("connection")))
        return QStringLiteral("no hay conexión con Flathub. Comprueba Internet y vuelve a intentarlo.");
    if (m.contains(QLatin1String("no space")) || m.contains(QLatin1String("not enough")))
        return QStringLiteral("no hay espacio suficiente en el disco.");
    if (m.contains(QLatin1String("not authorized")) || m.contains(QLatin1String("authentication")) || m.contains(QLatin1String("polkit")))
        return QStringLiteral("se canceló la autorización de administrador.");
    if (m.contains(QLatin1String("nothing matches")) || m.contains(QLatin1String("no remote refs")) || m.contains(QLatin1String("not found"))
        || m.contains(QLatin1String("can't find ref")))
        return QStringLiteral("esta aplicación ya no está disponible en Flathub para tu equipo.");
    if (m.contains(QLatin1String("already installed")))
        return QStringLiteral("ya está instalada.");
    return raw;
}

// Fallos pasajeros de red: merece la pena reintentar solos
static bool transient(const QString &raw)
{
    const QString m = raw.toLower();
    return m.contains(QLatin1String("timeout")) || m.contains(QLatin1String("timed out")) || m.contains(QLatin1String("connection"))
        || m.contains(QLatin1String("could not resolve")) || m.contains(QLatin1String("couldn't resolve")) || m.contains(QLatin1String("while fetching"))
        || m.contains(QLatin1String("server returned status 5"));
}

static QString qs(const char *s)
{
    return s ? QString::fromUtf8(s) : QString();
}

// Las apps se guardan por id en minúsculas: el catálogo de Arch los trae así (org.videolan.vlc)
static QString key(const QString &id)
{
    return id.toLower();
}

// El ayudante de las apps nativas (COUCOU_TIENDA_NATIVO lo cambia para probar)
static QString nativeHelper()
{
    const QString e = qEnvironmentVariable("COUCOU_TIENDA_NATIVO");
    return e.isEmpty() ? QStringLiteral("/usr/lib/coucou/tienda-nativo") : e;
}

static QString originLabel(const QString &origin)
{
    if (origin == QLatin1String("flathub-user"))
        return QStringLiteral("Flathub (solo para este usuario)");
    if (origin == QLatin1String("flathub-system"))
        return QStringLiteral("Flathub (todo el equipo)");
    if (origin == QLatin1String("repo"))
        return QStringLiteral("CachyOS / Arch (paquete del sistema)");
    if (origin == QLatin1String("aur"))
        return QStringLiteral("AUR (paquete de la comunidad)");
    return {};
}

// Corre tienda-nativo y devuelve su salida (para consultas cortas: buscar, instalados)
static QString runHelper(const QStringList &args, int timeoutMs)
{
    QProcess p;
    p.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    p.start(nativeHelper(), args);
    if (!p.waitForFinished(timeoutMs)) {
        p.kill();
        p.waitForFinished(1000);
        return {};
    }
    return QString::fromUtf8(p.readAllStandardOutput());
}

// Hilo de trabajo con su propio contexto GLib: libflatpak entrega ahí el progreso
struct ThreadContext {
    GMainContext *ctx = g_main_context_new();
    ThreadContext() { g_main_context_push_thread_default(ctx); }
    ~ThreadContext()
    {
        g_main_context_pop_thread_default(ctx);
        g_main_context_unref(ctx);
    }
};

static FlatpakInstallation *openInstallation(const QString &which, GError **error)
{
    return which == QLatin1String("system") ? flatpak_installation_new_system(nullptr, error) : flatpak_installation_new_user(nullptr, error);
}

// Icono exportado por la app instalada (el mismo que usa el menú de inicio)
static QString findIcon(const QString &deployDir, const QString &id)
{
    const QString base = deployDir + QStringLiteral("/export/share/icons/hicolor/");
    for (const char *sub : {"128x128/apps/", "scalable/apps/", "256x256/apps/", "512x512/apps/", "64x64/apps/", "48x48/apps/"}) {
        for (const char *ext : {".png", ".svg"}) {
            const QString p = base + QLatin1String(sub) + id + QLatin1String(ext);
            if (QFileInfo::exists(p))
                return QUrl::fromLocalFile(p).toString();
        }
    }
    return {};
}

StoreBackend::StoreBackend(QObject *parent)
    : QObject(parent)
{
    // Mismo tema que el resto del escritorio (lo escribe coucou-colors / Configuración). Coucou
    // cambia solo entre claro y oscuro: la tienda abierta lo sigue sin reiniciarse
    loadTheme();
    auto *watcher = new QFileSystemWatcher(this);
    const QString cfg = QDir::homePath() + QStringLiteral("/.config");
    watcher->addPath(cfg); // kwriteconfig reemplaza el archivo: se mira la carpeta
    if (QFileInfo::exists(cfg + QStringLiteral("/win11rc")))
        watcher->addPath(cfg + QStringLiteral("/win11rc"));
    auto *debounce = new QTimer(this);
    debounce->setSingleShot(true);
    debounce->setInterval(300);
    connect(debounce, &QTimer::timeout, this, [this, watcher, cfg] {
        if (QFileInfo::exists(cfg + QStringLiteral("/win11rc")) && !watcher->files().contains(cfg + QStringLiteral("/win11rc")))
            watcher->addPath(cfg + QStringLiteral("/win11rc"));
        loadTheme();
    });
    connect(watcher, &QFileSystemWatcher::fileChanged, debounce, qOverload<>(&QTimer::start));
    connect(watcher, &QFileSystemWatcher::directoryChanged, debounce, qOverload<>(&QTimer::start));

    // Usuario: nombre completo (GECOS), iniciales y foto de perfil
    if (const passwd *pw = getpwuid(getuid())) {
        m_userName = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
        if (m_userName.isEmpty())
            m_userName = QString::fromLocal8Bit(pw->pw_name);
        for (const QString &p : {QDir::homePath() + QStringLiteral("/.face.icon"), QDir::homePath() + QStringLiteral("/.face"),
                                 QStringLiteral("/var/lib/AccountsService/icons/") + QString::fromLocal8Bit(pw->pw_name)}) {
            if (QFileInfo(p).isReadable()) {
                m_avatar = QUrl::fromLocalFile(p).toString();
                break;
            }
        }
    }
    const QStringList words = m_userName.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    for (const QString &w : words.mid(0, 2))
        m_initials += w.at(0).toUpper();
    if (m_initials.size() == 1 && words.value(0).size() > 1)
        m_initials += words.value(0).at(1).toUpper();

    refreshInstalled();
    checkUpdates();
}

void StoreBackend::loadTheme()
{
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    rc.beginGroup(QStringLiteral("Appearance"));
    const QString mode = rc.value(QStringLiteral("mode"), QStringLiteral("light")).toString();
    QColor accent(rc.value(QStringLiteral("accent"), QStringLiteral("#0078D4")).toString());
    if (!accent.isValid())
        accent = QColor(QStringLiteral("#0078D4"));
    if (mode == m_mode && accent == m_accent && !m_accentSet)
        return;
    m_accentSet = false;
    m_mode = mode;
    m_accent = accent;
    QGuiApplication::styleHints()->setColorScheme(m_mode == QLatin1String("dark") ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    QPalette pal = QGuiApplication::palette();
    pal.setColor(QPalette::Accent, m_accent);
    pal.setColor(QPalette::Highlight, m_accent);
    QGuiApplication::setPalette(pal);
    Q_EMIT themeChanged();
}

StoreBackend::~StoreBackend()
{
    if (void *c = m_cancellable.load())
        g_cancellable_cancel(G_CANCELLABLE(c));
}

void StoreBackend::refreshInstalled()
{
    const int gen = ++m_refreshGen;
    std::thread([this, gen] {
        ThreadContext tc;
        QVariantMap result;
        for (const QString which : {QStringLiteral("system"), QStringLiteral("user")}) {
            GError *error = nullptr;
            FlatpakInstallation *inst = openInstallation(which, &error);
            if (!inst) {
                g_clear_error(&error);
                continue;
            }
            GPtrArray *refs = flatpak_installation_list_installed_refs_by_kind(inst, FLATPAK_REF_KIND_APP, nullptr, &error);
            g_clear_error(&error);
            for (guint i = 0; refs && i < refs->len; ++i) {
                auto *ref = FLATPAK_INSTALLED_REF(g_ptr_array_index(refs, i));
                const QString id = qs(flatpak_ref_get_name(FLATPAK_REF(ref)));
                QVariantMap app;
                app[QStringLiteral("id")] = id;
                const QString name = qs(flatpak_installed_ref_get_appdata_name(ref));
                app[QStringLiteral("name")] = name.isEmpty() ? id.section(QLatin1Char('.'), -1) : name;
                app[QStringLiteral("summary")] = qs(flatpak_installed_ref_get_appdata_summary(ref));
                app[QStringLiteral("version")] = qs(flatpak_installed_ref_get_appdata_version(ref));
                app[QStringLiteral("installation")] = which;
                app[QStringLiteral("origin")] = QStringLiteral("flathub-") + which;
                app[QStringLiteral("originLabel")] = originLabel(QStringLiteral("flathub-") + which);
                app[QStringLiteral("ref")] = QString::fromUtf8(flatpak_ref_format_ref_cached(FLATPAK_REF(ref)));
                app[QStringLiteral("size")] = double(flatpak_installed_ref_get_installed_size(ref));
                app[QStringLiteral("deploy")] = qs(flatpak_installed_ref_get_deploy_dir(ref));
                app[QStringLiteral("icon")] = findIcon(app[QStringLiteral("deploy")].toString(), id);
                // En las dos instalaciones de Flathub (dos copias): vale la de usuario y se recuerda la otra
                if (result.contains(key(id)))
                    app[QStringLiteral("alsoSystem")] = result.value(key(id));
                result[key(id)] = app;
            }
            if (refs)
                g_ptr_array_unref(refs);
            g_object_unref(inst);
        }
        // Nativas: id, paquete, versión, repo|aur, nombre, icono, propia
        QVariantMap native;
        const QStringList lines = runHelper({QStringLiteral("instalados")}, 30000).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            const QStringList f = line.split(QLatin1Char('\t'));
            if (f.size() < 7 || native.contains(key(f.at(0))))
                continue;
            QString icon = f.at(5);
            if (icon.startsWith(QLatin1Char('/')))
                icon = QUrl::fromLocalFile(icon).toString();
            else if (!icon.isEmpty())
                icon = QStringLiteral("image://icon/") + icon;
            native[key(f.at(0))] = QVariantMap{{QStringLiteral("id"), f.at(0)},
                                               {QStringLiteral("pkg"), f.at(1)},
                                               {QStringLiteral("version"), f.at(2)},
                                               {QStringLiteral("origin"), f.at(3)},
                                               {QStringLiteral("originLabel"), originLabel(f.at(3))},
                                               {QStringLiteral("name"), f.at(4)},
                                               {QStringLiteral("icon"), icon},
                                               {QStringLiteral("listed"), f.at(6) == QLatin1String("1")}};
        }
        QMetaObject::invokeMethod(this, [this, result, native, gen] {
            m_flatpaks = result;
            m_native = native;
            mergeInstalled();
            // Las tareas que terminaron mientras se armaba esta lista ya se ven en ella
            // (una lista que se empezó a armar antes de terminar no cuenta: se espera la siguiente)
            bool changed = false;
            for (auto it = m_finishing.begin(); it != m_finishing.end();) {
                if (gen >= it.value()) {
                    m_jobs.remove(it.key());
                    it = m_finishing.erase(it);
                    changed = true;
                } else {
                    ++it;
                }
            }
            if (changed)
                Q_EMIT jobsChanged();
        }, Qt::QueuedConnection);
    }).detach();
}

// Lo que ve la interfaz: las de Flathub (con "native" si además está la nativa: dos copias que
// se pelean, la ficha avisa) y las solo nativas
void StoreBackend::mergeInstalled()
{
    QVariantMap all;
    for (auto it = m_flatpaks.cbegin(); it != m_flatpaks.cend(); ++it) {
        QVariantMap app = it.value().toMap();
        // Todas las copias instaladas: con más de una, la ficha avisa y deja quitar las que sobran
        QVariantList copies{QVariantMap{{QStringLiteral("source"), app.value(QStringLiteral("origin"))},
                                        {QStringLiteral("label"), app.value(QStringLiteral("originLabel"))}}};
        if (app.contains(QStringLiteral("alsoSystem")))
            copies << QVariantMap{{QStringLiteral("source"), QStringLiteral("flathub-system")},
                                  {QStringLiteral("label"), originLabel(QStringLiteral("flathub-system"))}};
        if (m_native.contains(it.key())) {
            const QVariantMap n = m_native.value(it.key()).toMap();
            app[QStringLiteral("native")] = n;
            copies << QVariantMap{{QStringLiteral("source"), QStringLiteral("native")},
                                  {QStringLiteral("label"), n.value(QStringLiteral("originLabel"))},
                                  {QStringLiteral("pkg"), n.value(QStringLiteral("pkg"))}};
        }
        if (copies.size() > 1)
            app[QStringLiteral("copies")] = copies;
        all[it.key()] = app;
    }
    for (auto it = m_native.cbegin(); it != m_native.cend(); ++it) {
        if (all.contains(it.key()))
            continue;
        QVariantMap app = it.value().toMap();
        app[QStringLiteral("installation")] = QStringLiteral("native");
        app[QStringLiteral("size")] = 0.0;
        all[it.key()] = app;
    }
    m_installed = all;
    Q_EMIT installedChanged();
}

void StoreBackend::findSources(const QString &id, const QString &homepage)
{
    if (id.isEmpty() || m_sources.contains(id))
        return;
    m_sources[id] = QVariantMap{{QStringLiteral("state"), QStringLiteral("checking")}};
    Q_EMIT sourcesChanged();
    std::thread([this, id, homepage] {
        QVariantMap r{{QStringLiteral("state"), QStringLiteral("ok")}, {QStringLiteral("preferred"), QStringLiteral("flathub")}};
        const QStringList lines = runHelper({QStringLiteral("buscar"), id, homepage}, 30000).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            const QStringList f = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
            if (f.value(0) == QLatin1String("repo") && f.size() >= 3)
                r[QStringLiteral("repo")] = QVariantMap{{QStringLiteral("pkg"), f.at(1)}, {QStringLiteral("version"), f.at(2)}, {QStringLiteral("repo"), f.value(3)}};
            else if (f.value(0) == QLatin1String("aur") && f.size() >= 3)
                r[QStringLiteral("aur")] = QVariantMap{{QStringLiteral("pkg"), f.at(1)}, {QStringLiteral("version"), f.at(2)}};
            else if (f.value(0) == QLatin1String("preferido") && f.size() >= 2 && f.at(1) != QLatin1String("-"))
                r[QStringLiteral("preferred")] = f.at(1);
        }
        // Un preferido que no se encontró (sin Internet para el AUR…) no vale
        if (!r.contains(r.value(QStringLiteral("preferred")).toString()))
            r[QStringLiteral("preferred")] = QStringLiteral("flathub");
        QMetaObject::invokeMethod(this, [this, id, r] {
            m_sources[id] = r;
            Q_EMIT sourcesChanged();
        }, Qt::QueuedConnection);
    }).detach();
}

void StoreBackend::checkUpdates()
{
    if (m_checking)
        return;
    m_checking = true;
    Q_EMIT updatesChanged();
    std::thread([this] {
        ThreadContext tc;
        QStringList apps;
        int components = 0;
        QString failure;
        for (const QString which : {QStringLiteral("system"), QStringLiteral("user")}) {
            GError *error = nullptr;
            FlatpakInstallation *inst = openInstallation(which, &error);
            if (!inst) {
                g_clear_error(&error);
                continue;
            }
            GPtrArray *refs = flatpak_installation_list_installed_refs_for_update(inst, nullptr, &error);
            if (error) {
                failure = qs(error->message);
                g_clear_error(&error);
            }
            for (guint i = 0; refs && i < refs->len; ++i) {
                auto *ref = FLATPAK_REF(g_ptr_array_index(refs, i));
                if (flatpak_ref_get_kind(ref) == FLATPAK_REF_KIND_APP)
                    apps << qs(flatpak_ref_get_name(ref));
                else
                    ++components;
            }
            if (refs)
                g_ptr_array_unref(refs);
            g_object_unref(inst);
        }
        QMetaObject::invokeMethod(this, [this, apps, components, failure] {
            m_updates = apps;
            m_componentUpdates = components;
            m_checking = false;
            m_lastCheck = QLocale().toString(QTime::currentTime(), QStringLiteral("HH:mm"));
            Q_EMIT updatesChanged();
            if (!failure.isEmpty())
                Q_EMIT notify(QStringLiteral("No se pudieron buscar actualizaciones: ") + failure, true);
        }, Qt::QueuedConnection);
    }).detach();
}

void StoreBackend::install(const QString &id, const QString &name, const QString &source)
{
    // Ya instalada (de cualquier forma): otra copia se pelearía con la que hay
    if (m_installed.contains(key(id))) {
        Q_EMIT notify(name + QStringLiteral(" ya está instalada desde ") + m_installed.value(key(id)).toMap().value(QStringLiteral("originLabel")).toString()
                          + QStringLiteral(". Para cambiarla, desinstálala primero."), true);
        return;
    }
    QString src = source;
    if (src.isEmpty())
        src = m_sources.value(id).toMap().value(QStringLiteral("preferred"), QStringLiteral("flathub")).toString();
    enqueue(id, name, QStringLiteral("install"), src);
}

void StoreBackend::update(const QString &id)
{
    enqueue(id, {}, QStringLiteral("update"), {});
}

void StoreBackend::updateAll()
{
    // Una sola tarea que actualiza apps y componentes de ambas instalaciones
    enqueue(QStringLiteral("*"), QStringLiteral("Todas las actualizaciones"), QStringLiteral("updateall"), {});
}

void StoreBackend::uninstall(const QString &id, const QString &source)
{
    QString src = source;
    if (src.isEmpty())
        src = m_flatpaks.contains(key(id)) ? QStringLiteral("flatpak") : QStringLiteral("native");
    else if (src.startsWith(QLatin1String("flathub-")))
        src = m_flatpaks.value(key(id)).toMap().value(QStringLiteral("origin")) == src ? QStringLiteral("flatpak") : QStringLiteral("flatpak-system");
    enqueue(id, {}, QStringLiteral("uninstall"), src);
}

void StoreBackend::cancel(const QString &id)
{
    if (id == m_current) {
        if (void *c = m_cancellable.load())
            g_cancellable_cancel(G_CANCELLABLE(c));
        if (const qint64 pid = m_nativePid.load())
            ::kill(pid_t(pid), SIGTERM); // tienda-nativo: lo que ya instaló pacman queda instalado
        setJob(id, {{QStringLiteral("status"), QStringLiteral("Cancelando…")}});
        return;
    }
    for (int i = 0; i < m_queue.size(); ++i) {
        if (m_queue.at(i).id == id) {
            m_queue.removeAt(i);
            m_jobs.remove(id);
            Q_EMIT jobsChanged();
            return;
        }
    }
}

void StoreBackend::launch(const QString &id)
{
    // Nativa (también si además está la de Flathub: es la que trae lo que la hace andar bien)
    const QString pkg = m_native.value(key(id)).toMap().value(QStringLiteral("pkg")).toString();
    if (!pkg.isEmpty()) {
        QProcess::startDetached(nativeHelper(), {QStringLiteral("abrir"), pkg});
        return;
    }
    // Las herramientas de terminal no exportan lanzador: se abren dentro de Konsole
    const QString deploy = m_installed.value(key(id)).toMap().value(QStringLiteral("deploy")).toString();
    if (!deploy.isEmpty() && !QFileInfo::exists(deploy + QStringLiteral("/export/share/applications/") + id + QStringLiteral(".desktop"))) {
        if (QProcess::startDetached(QStringLiteral("konsole"), {QStringLiteral("--hold"), QStringLiteral("-e"), QStringLiteral("flatpak"), QStringLiteral("run"), id}))
            return;
    }
    QProcess::startDetached(QStringLiteral("flatpak"), {QStringLiteral("run"), id});
}

void StoreBackend::openUrl(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

QString StoreBackend::formatSize(double bytes) const
{
    if (bytes <= 0)
        return {};
    return QLocale().formattedDataSize(qint64(bytes), 1, QLocale::DataSizeTraditionalFormat);
}

void StoreBackend::enqueue(const QString &id, const QString &name, const QString &action, const QString &source)
{
    if (m_jobs.contains(id))
        return;
    QString display = name;
    if (display.isEmpty())
        display = m_installed.value(key(id)).toMap().value(QStringLiteral("name")).toString();
    if (display.isEmpty())
        display = id;
    m_queue.append({id, display, action, source});
    m_jobs[id] = QVariantMap{{QStringLiteral("action"), action},
                             {QStringLiteral("source"), source},
                             {QStringLiteral("name"), display},
                             {QStringLiteral("state"), QStringLiteral("queued")},
                             {QStringLiteral("progress"), 0},
                             {QStringLiteral("status"), QStringLiteral("En cola")}};
    Q_EMIT jobsChanged();
    startNext();
}

void StoreBackend::setJob(const QString &id, const QVariantMap &values)
{
    if (!m_jobs.contains(id))
        return;
    QVariantMap job = m_jobs.value(id).toMap();
    for (auto it = values.begin(); it != values.end(); ++it)
        job[it.key()] = it.value();
    m_jobs[id] = job;
    Q_EMIT jobsChanged();
}

void StoreBackend::startNext()
{
    if (m_running || m_queue.isEmpty())
        return;
    const Job job = m_queue.takeFirst();
    m_running = true;
    m_current = job.id;
    const bool flathub = job.source.isEmpty() || job.source == QLatin1String("flathub") || job.source.startsWith(QLatin1String("flatpak"));
    setJob(job.id, {{QStringLiteral("state"), QStringLiteral("running")},
                    {QStringLiteral("status"), flathub && job.action != QLatin1String("uninstall") ? QStringLiteral("Conectando con Flathub…") : QStringLiteral("Preparando…")}});
    std::thread([this, job] { runJob(job); }).detach();
}

namespace
{
// Estado compartido con las señales de FlatpakTransaction (todas en el hilo de trabajo)
struct RunState {
    StoreBackend *backend;
    QString id;
    QString action;
    int opIndex = -1;
    int opCount = 1;
    QString error;
    bool dryRun = false;      // solo comprobar: se resuelve todo y se aborta antes de descargar
    qint64 neededBytes = 0;   // espacio que ocupará lo que falta instalar
    // Lo que baja cada operación (en orden) y el total: el avance se mide en bytes, no en
    // operaciones (la app suele ser la última de varias y la barra saltaba de 0 a 67 %)
    QList<qint64> opBytes;
    qint64 totalBytes = 0;
};

void postProgress(RunState *st, double fraction, const QString &status)
{
    const int pct = qBound(0, int(fraction * 100), 100);
    StoreBackend *b = st->backend;
    const QString id = st->id;
    QMetaObject::invokeMethod(b, [b, id, pct, status] { b->onProgress(id, pct, status); }, Qt::QueuedConnection);
}

void progressChanged(FlatpakTransactionProgress *progress, gpointer data)
{
    auto *st = static_cast<RunState *>(data);
    const int p = flatpak_transaction_progress_get_progress(progress);
    const guint64 total = flatpak_transaction_progress_get_bytes_transferred(progress);
    double fraction = (std::max(st->opIndex, 0) + p / 100.0) / std::max(st->opCount, 1);
    if (st->totalBytes > 0 && st->action != QLatin1String("uninstall")) {
        qint64 before = 0;
        for (int i = 0; i < st->opIndex && i < st->opBytes.size(); ++i)
            before += st->opBytes.at(i);
        const qint64 cur = st->opBytes.value(std::max(st->opIndex, 0));
        // bytes_transferred cuenta lo bajado de esta operación (a veces sin tope): se limita a su tamaño
        const qint64 done = before + (cur > 0 ? std::min<qint64>(qint64(total), cur) : 0);
        fraction = double(done) / double(st->totalBytes);
    }
    QString status;
    if (st->action == QLatin1String("uninstall"))
        status = QStringLiteral("Desinstalando…");
    else if (st->opCount > 1)
        status = QStringLiteral("Descargando %1 de %2…").arg(st->opIndex + 1).arg(st->opCount);
    else
        status = QStringLiteral("Descargando…");
    if (st->totalBytes > 0 && st->action != QLatin1String("uninstall"))
        status = QStringLiteral("Descargando…  %1 de %2")
                     .arg(QLocale().formattedDataSize(qint64(fraction * st->totalBytes), 1, QLocale::DataSizeTraditionalFormat),
                          QLocale().formattedDataSize(st->totalBytes, 1, QLocale::DataSizeTraditionalFormat));
    else if (total > 0 && st->action != QLatin1String("uninstall"))
        status += QStringLiteral("  ") + QLocale().formattedDataSize(qint64(total), 1, QLocale::DataSizeTraditionalFormat);
    if (p >= 100 && st->opIndex + 1 >= st->opCount && st->action != QLatin1String("uninstall"))
        status = QStringLiteral("Instalando…");
    postProgress(st, fraction, status);
}

void newOperation(FlatpakTransaction *transaction, FlatpakTransactionOperation *, FlatpakTransactionProgress *progress, gpointer data)
{
    auto *st = static_cast<RunState *>(data);
    GList *ops = flatpak_transaction_get_operations(transaction);
    st->opCount = std::max<int>(1, g_list_length(ops));
    g_list_free_full(ops, g_object_unref);
    st->opIndex++;
    flatpak_transaction_progress_set_update_frequency(progress, 250);
    g_signal_connect(progress, "changed", G_CALLBACK(progressChanged), data);
}

gboolean operationError(FlatpakTransaction *, FlatpakTransactionOperation *, GError *error, gint details, gpointer data)
{
    auto *st = static_cast<RunState *>(data);
    // Un fallo "no fatal" (p. ej. ya actualizado) no detiene el resto
    if (details & FLATPAK_TRANSACTION_ERROR_DETAILS_NON_FATAL)
        return TRUE;
    if (g_error_matches(error, FLATPAK_ERROR, FLATPAK_ERROR_SKIPPED))
        return TRUE;
    st->error = qs(error->message);
    return FALSE;
}

gint chooseRemote(FlatpakTransaction *, const char *, const char *, const char *const *, gpointer)
{
    return 0;
}

gboolean ready(FlatpakTransaction *transaction, gpointer data)
{
    auto *st = static_cast<RunState *>(data);
    // Suma lo que se va a instalar y comprueba el espacio libre antes de descargar nada
    qint64 needed = 0;
    GList *ops = flatpak_transaction_get_operations(transaction);
    st->opBytes.clear();
    st->totalBytes = 0;
    for (GList *l = ops; l; l = l->next) {
        auto *op = FLATPAK_TRANSACTION_OPERATION(l->data);
        const bool uninstall = flatpak_transaction_operation_get_operation_type(op) == FLATPAK_TRANSACTION_OPERATION_UNINSTALL;
        if (!uninstall)
            needed += qint64(flatpak_transaction_operation_get_installed_size(op));
        const qint64 dl = uninstall ? 0 : qint64(flatpak_transaction_operation_get_download_size(op));
        st->opBytes << dl;
        st->totalBytes += dl;
    }
    if (!st->dryRun && st->totalBytes > 0)
        postProgress(st, 0, QStringLiteral("Descargando…  0 de %1").arg(QLocale().formattedDataSize(st->totalBytes, 1, QLocale::DataSizeTraditionalFormat)));
    g_list_free_full(ops, g_object_unref);
    st->neededBytes = needed;
    if (st->action == QLatin1String("install") && needed > 0 && needed + 200 * 1024 * 1024 > freeBytes()) {
        st->error = QStringLiteral("no hay espacio suficiente en el disco (necesita %1).")
                        .arg(QLocale().formattedDataSize(needed, 1, QLocale::DataSizeTraditionalFormat));
        return FALSE;
    }
    return !st->dryRun;
}

gboolean noRebase(FlatpakTransaction *, const char *, const char *, const char *, const char *, const char **, gpointer)
{
    return FALSE;
}

bool runTransaction(FlatpakInstallation *inst, RunState *st, GCancellable *cancellable,
                    const std::function<bool(FlatpakTransaction *, GError **)> &fill, bool *empty = nullptr)
{
    GError *error = nullptr;
    FlatpakTransaction *t = flatpak_transaction_new_for_installation(inst, cancellable, &error);
    if (!t) {
        st->error = qs(error->message);
        g_clear_error(&error);
        return false;
    }
    flatpak_transaction_add_default_dependency_sources(t);
    g_signal_connect(t, "new-operation", G_CALLBACK(newOperation), st);
    g_signal_connect(t, "operation-error", G_CALLBACK(operationError), st);
    g_signal_connect(t, "choose-remote-for-ref", G_CALLBACK(chooseRemote), st);
    g_signal_connect(t, "ready", G_CALLBACK(ready), st);
    g_signal_connect(t, "end-of-lifed-with-rebase", G_CALLBACK(noRebase), st);

    bool ok = fill(t, &error);
    if (ok) {
        if (empty)
            *empty = flatpak_transaction_is_empty(t);
        st->opIndex = -1;
        ok = flatpak_transaction_run(t, cancellable, &error);
    }
    if (!ok && st->dryRun && st->error.isEmpty() && g_error_matches(error, FLATPAK_ERROR, FLATPAK_ERROR_ABORTED))
        ok = true; // comprobación superada
    else if (!ok && st->error.isEmpty()) {
        if (g_error_matches(error, G_IO_ERROR, G_IO_ERROR_CANCELLED) || g_error_matches(error, FLATPAK_ERROR, FLATPAK_ERROR_ABORTED))
            st->error = QStringLiteral("cancelado");
        else
            st->error = error ? qs(error->message) : QStringLiteral("error desconocido");
    }
    g_clear_error(&error);
    g_object_unref(t);
    return ok;
}
} // namespace

// tienda-nativo instalar|quitar, con su avance ("PROGRESO <n> <texto>") en la barra de la app
bool StoreBackend::runNative(const Job &job, QString *error)
{
    QStringList args;
    if (job.action == QLatin1String("install")) {
        QVariantMap src;
        QMetaObject::invokeMethod(this, [this, &src, &job] { src = m_sources.value(job.id).toMap().value(job.source).toMap(); }, Qt::BlockingQueuedConnection);
        const QString pkg = src.value(QStringLiteral("pkg")).toString();
        if (pkg.isEmpty()) {
            *error = QStringLiteral("no se encontró su paquete nativo.");
            return false;
        }
        args = {QStringLiteral("instalar"), job.source, pkg, job.id};
    } else {
        QVariantMap native;
        QMetaObject::invokeMethod(this, [this, &native, &job] { native = m_native.value(key(job.id)).toMap(); }, Qt::BlockingQueuedConnection);
        const QString pkg = native.value(QStringLiteral("pkg")).toString();
        if (pkg.isEmpty()) {
            *error = QStringLiteral("la aplicación no está instalada");
            return false;
        }
        args = {QStringLiteral("quitar"), pkg, job.id};
    }
    QProcess p;
    p.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    p.start(nativeHelper(), args);
    if (!p.waitForStarted(5000)) {
        *error = QStringLiteral("no se encontró ") + nativeHelper();
        return false;
    }
    m_nativePid = p.processId();
    const QString id = job.id;
    QString last;
    auto readLines = [&] {
        while (p.canReadLine()) {
            const QString line = QString::fromUtf8(p.readLine()).trimmed();
            if (line.startsWith(QLatin1String("PROGRESO "))) {
                const int pct = line.section(QLatin1Char(' '), 1, 1).toInt();
                const QString status = line.section(QLatin1Char(' '), 2);
                QMetaObject::invokeMethod(this, [this, id, pct, status] { onProgress(id, pct, status); }, Qt::QueuedConnection);
            } else if (line.startsWith(QLatin1String("ERROR "))) {
                last = line.mid(6);
            }
        }
    };
    // Sin límite de tiempo: armar un paquete del AUR puede tardar
    while (p.state() != QProcess::NotRunning) {
        p.waitForReadyRead(500);
        readLines();
    }
    readLines();
    m_nativePid = 0;
    if (p.exitStatus() == QProcess::CrashExit) {
        *error = QStringLiteral("cancelado");
        return false;
    }
    if (p.exitCode() != 0) {
        *error = last.isEmpty() ? QStringLiteral("no se pudo terminar (el detalle está en la terminal).") : last;
        return false;
    }
    return true;
}

void StoreBackend::runJob(const Job &job)
{
    ThreadContext tc;
    GCancellable *cancellable = g_cancellable_new();
    m_cancellable = cancellable;
    RunState st{this, job.id, job.action};
    bool ok = true;
    GError *error = nullptr;

    const bool native = (job.action == QLatin1String("install") && (job.source == QLatin1String("repo") || job.source == QLatin1String("aur")))
        || (job.action == QLatin1String("uninstall") && job.source == QLatin1String("native"));
    if (native) {
        ok = runNative(job, &st.error);
    } else if (job.action == QLatin1String("install")) {
        ensureUserRemote();
        FlatpakInstallation *inst = flatpak_installation_new_user(cancellable, &error);
        if (!inst) {
            ok = false;
            st.error = qs(error->message);
        } else {
            const QByteArray ref = QStringLiteral("app/%1/%2/stable").arg(job.id, qs(flatpak_get_default_arch())).toUtf8();
            auto add = [&](FlatpakTransaction *t, GError **e) {
                return bool(flatpak_transaction_add_install(t, "flathub", ref.constData(), nullptr, e));
            };
            ok = runTransaction(inst, &st, cancellable, add);
            // Un corte de red momentáneo no debería obligar a darle otra vez: se reintenta (lo ya bajado se conserva)
            for (int attempt = 0; !ok && attempt < 2 && transient(st.error) && !g_cancellable_is_cancelled(cancellable); ++attempt) {
                postProgress(&st, 0, QStringLiteral("Reintentando…"));
                QThread::sleep(3);
                st.error.clear();
                st.opIndex = -1;
                ok = runTransaction(inst, &st, cancellable, add);
            }
            g_object_unref(inst);
        }
    } else if (job.action == QLatin1String("updateall")) {
        for (const QString which : {QStringLiteral("system"), QStringLiteral("user")}) {
            FlatpakInstallation *inst = openInstallation(which, &error);
            if (!inst) {
                g_clear_error(&error);
                continue;
            }
            GPtrArray *refs = flatpak_installation_list_installed_refs_for_update(inst, cancellable, &error);
            g_clear_error(&error);
            if (refs && refs->len) {
                ok = runTransaction(inst, &st, cancellable, [&](FlatpakTransaction *t, GError **e) {
                    for (guint i = 0; i < refs->len; ++i) {
                        const char *r = flatpak_ref_format_ref_cached(FLATPAK_REF(g_ptr_array_index(refs, i)));
                        if (!flatpak_transaction_add_update(t, r, nullptr, nullptr, e))
                            return false;
                    }
                    return true;
                }) && ok;
            }
            if (refs)
                g_ptr_array_unref(refs);
            g_object_unref(inst);
            if (g_cancellable_is_cancelled(cancellable))
                break;
        }
    } else {
        // update / uninstall sobre una app ya instalada
        QVariantMap app;
        QMetaObject::invokeMethod(this, [this, &app, &job] {
            app = m_flatpaks.value(key(job.id)).toMap();
            // La copia de "todo el equipo" cuando también está la de usuario
            if (job.source == QLatin1String("flatpak-system"))
                app = app.value(QStringLiteral("alsoSystem")).toMap();
        }, Qt::BlockingQueuedConnection);
        const QByteArray ref = app.value(QStringLiteral("ref")).toString().toUtf8();
        FlatpakInstallation *inst = ref.isEmpty() ? nullptr : openInstallation(app.value(QStringLiteral("installation")).toString(), &error);
        if (!inst) {
            ok = false;
            st.error = error ? qs(error->message) : QStringLiteral("la aplicación no está instalada");
        } else {
            const bool remove = job.action == QLatin1String("uninstall");
            ok = runTransaction(inst, &st, cancellable, [&](FlatpakTransaction *t, GError **e) {
                if (remove) {
                    // Los datos de ~/.var/app se conservan: al reinstalar recupera su configuración
                    return bool(flatpak_transaction_add_uninstall(t, ref.constData(), e));
                }
                return bool(flatpak_transaction_add_update(t, ref.constData(), nullptr, nullptr, e));
            });
            if (ok && remove) {
                // Quita runtimes que ya no usa ninguna app (equivale a "flatpak uninstall --unused")
                GPtrArray *unused = flatpak_installation_list_unused_refs(inst, nullptr, cancellable, nullptr);
                if (unused && unused->len) {
                    RunState quiet{this, job.id, job.action};
                    runTransaction(inst, &quiet, cancellable, [&](FlatpakTransaction *t, GError **e) {
                        for (guint i = 0; i < unused->len; ++i)
                            flatpak_transaction_add_uninstall(t, flatpak_ref_format_ref_cached(FLATPAK_REF(g_ptr_array_index(unused, i))), e);
                        return true;
                    });
                }
                if (unused)
                    g_ptr_array_unref(unused);
            }
            g_object_unref(inst);
        }
    }
    g_clear_error(&error);
    m_cancellable = nullptr;
    g_object_unref(cancellable);

    const QString failure = st.error;
    QMetaObject::invokeMethod(this, [this, job, ok, failure] {
        if (ok && job.action != QLatin1String("updateall")) {
            m_finishing[job.id] = m_refreshGen + 1; // la lista que se pide justo abajo
            setJob(job.id, {{QStringLiteral("progress"), 100}, {QStringLiteral("status"), QStringLiteral("Terminando…")}});
        } else {
            m_jobs.remove(job.id);
        }
        m_running = false;
        m_current.clear();
        Q_EMIT jobsChanged();
        if (job.action == QLatin1String("updateall")) {
            if (ok) {
                m_updates.clear();
                m_componentUpdates = 0;
                Q_EMIT updatesChanged();
            }
        } else if (ok && m_updates.removeAll(job.id)) {
            Q_EMIT updatesChanged();
        }
        if (!ok && failure != QLatin1String("cancelado")) {
            static const QMap<QString, QString> verbs{{QStringLiteral("install"), QStringLiteral("instalar")},
                                                     {QStringLiteral("update"), QStringLiteral("actualizar")},
                                                     {QStringLiteral("updateall"), QStringLiteral("actualizar")},
                                                     {QStringLiteral("uninstall"), QStringLiteral("desinstalar")}};
            Q_EMIT notify(QStringLiteral("No se pudo %1 %2: %3").arg(verbs.value(job.action), job.name, friendlyError(failure)), true);
        } else if (ok && job.action == QLatin1String("install")) {
            const QString from = job.source == QLatin1String("repo") ? QStringLiteral(" desde CachyOS / Arch")
                : job.source == QLatin1String("aur")                ? QStringLiteral(" desde el AUR")
                                                                    : QStringLiteral(" desde Flathub");
            Q_EMIT notify(job.name + QStringLiteral(" se instaló correctamente") + from + QStringLiteral("."), false);
        }
        refreshInstalled();
        startNext();
    }, Qt::QueuedConnection);
}

void StoreBackend::onProgress(const QString &id, int pct, const QString &status)
{
    setJob(id, {{QStringLiteral("progress"), pct}, {QStringLiteral("status"), status}});
}

void StoreBackend::check(const QString &id)
{
    if (id.isEmpty() || m_availability.contains(id))
        return;
    m_availability[id] = QVariantMap{{QStringLiteral("state"), QStringLiteral("checking")}};
    Q_EMIT availabilityChanged();
    std::thread([this, id] {
        ThreadContext tc;
        ensureUserRemote();
        RunState st{this, id, QStringLiteral("install")};
        st.dryRun = true;
        GError *error = nullptr;
        bool ok = false;
        if (FlatpakInstallation *inst = flatpak_installation_new_user(nullptr, &error)) {
            const QByteArray ref = QStringLiteral("app/%1/%2/stable").arg(id, qs(flatpak_get_default_arch())).toUtf8();
            ok = runTransaction(inst, &st, nullptr, [&](FlatpakTransaction *t, GError **e) {
                return bool(flatpak_transaction_add_install(t, "flathub", ref.constData(), nullptr, e));
            });
            g_object_unref(inst);
        } else {
            st.error = qs(error->message);
        }
        g_clear_error(&error);
        QVariantMap result;
        if (ok) {
            result[QStringLiteral("state")] = QStringLiteral("ok");
            result[QStringLiteral("size")] = double(st.neededBytes);
        } else {
            // Ya instalada (p. ej. en la instalación del sistema) no es un problema
            const bool installed = st.error.contains(QLatin1String("already installed"), Qt::CaseInsensitive);
            result[QStringLiteral("state")] = installed ? QStringLiteral("ok") : QStringLiteral("error");
            result[QStringLiteral("message")] = friendlyError(st.error);
            result[QStringLiteral("raw")] = st.error;
        }
        QMetaObject::invokeMethod(this, [this, id, result] {
            // Un fallo de red no se recuerda: se vuelve a comprobar la próxima vez
            if (result.value(QStringLiteral("state")) == QLatin1String("error") && transient(result.value(QStringLiteral("raw")).toString()))
                m_availability.remove(id);
            else
                m_availability[id] = result;
            Q_EMIT availabilityChanged();
        }, Qt::QueuedConnection);
    }).detach();
}
