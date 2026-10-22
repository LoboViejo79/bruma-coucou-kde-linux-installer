#include "backend.h"

#include <KPluginMetaData>
#include <KQuickConfigModule>
#include <KQuickConfigModuleLoader>
#include <QQmlEngine>
#include <QQuickItem>

#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QLocale>
#include <QPalette>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleHints>
#include <QSysInfo>
#include <QTextStream>
#include <QUrl>

#include <functional>

namespace {

QString readFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll());
}

QString runSync(const QString &program, const QStringList &args, int timeoutMs = 5000)
{
    QProcess p;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    p.setProcessEnvironment(env);
    p.start(program, args);
    if (!p.waitForFinished(timeoutMs))
        return {};
    return QString::fromUtf8(p.readAllStandardOutput());
}

QString humanBytes(double bytes)
{
    return QLocale().formattedDataSize(qint64(bytes), 1, QLocale::DataSizeTraditionalFormat);
}

} // namespace

Backend::Backend(QObject *parent)
    : QObject(parent)
{
    loadTheme();
    applyPalette();
    m_hostname = QSysInfo::machineHostName();

    // Información del equipo (página Sistema / Acerca de)
    const QString osRelease = readFile(QStringLiteral("/etc/os-release"));
    QRegularExpression prettyRe(QStringLiteral("^PRETTY_NAME=\"?([^\"\\n]+)"), QRegularExpression::MultilineOption);
    const QString cpuinfo = readFile(QStringLiteral("/proc/cpuinfo"));
    QRegularExpression cpuRe(QStringLiteral("^model name\\s*:\\s*(.+)$"), QRegularExpression::MultilineOption);
    const QString meminfo = readFile(QStringLiteral("/proc/meminfo"));
    QRegularExpression memRe(QStringLiteral("^MemTotal:\\s*(\\d+)"), QRegularExpression::MultilineOption);
    QString gpu;
    const auto lspci = runSync(QStringLiteral("lspci"), {}).split(QLatin1Char('\n'));
    for (const QString &l : lspci) {
        if (l.contains(QLatin1String("VGA")) || l.contains(QLatin1String("3D controller"))) {
            gpu = l.section(QLatin1String(": "), 1);
            break;
        }
    }
    const QString user = qEnvironmentVariable("USER");
    QString fullName = runSync(QStringLiteral("getent"), {QStringLiteral("passwd"), user}).section(QLatin1Char(':'), 4, 4).section(QLatin1Char(','), 0, 0);
    QString avatar;
    for (const QString &p : {QDir::homePath() + QStringLiteral("/.face.icon"), QDir::homePath() + QStringLiteral("/.face"),
                             QStringLiteral("/var/lib/AccountsService/icons/") + user}) {
        if (QFileInfo::exists(p)) {
            avatar = QUrl::fromLocalFile(p).toString();
            break;
        }
    }
    const QString df = runSync(QStringLiteral("df"), {QStringLiteral("-B1"), QStringLiteral("--output=size,used"), QDir::homePath()});
    const QStringList dfl = df.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    double diskSize = 0, diskUsed = 0;
    if (dfl.size() > 1) {
        const QStringList parts = dfl.at(1).simplified().split(QLatin1Char(' '));
        if (parts.size() == 2) {
            diskSize = parts.at(0).toDouble();
            diskUsed = parts.at(1).toDouble();
        }
    }

    m_sysInfo = {
        {QStringLiteral("hostname"), QSysInfo::machineHostName()},
        {QStringLiteral("os"), prettyRe.match(osRelease).captured(1)},
        {QStringLiteral("kernel"), QSysInfo::kernelVersion()},
        {QStringLiteral("cpu"), cpuRe.match(cpuinfo).captured(1).simplified()},
        {QStringLiteral("ram"), humanBytes(memRe.match(meminfo).captured(1).toDouble() * 1024)},
        {QStringLiteral("gpu"), gpu},
        {QStringLiteral("user"), user},
        {QStringLiteral("fullName"), fullName.isEmpty() ? user : fullName},
        {QStringLiteral("avatar"), avatar},
        {QStringLiteral("diskSize"), humanBytes(diskSize)},
        {QStringLiteral("diskUsed"), humanBytes(diskUsed)},
        {QStringLiteral("diskRatio"), diskSize > 0 ? diskUsed / diskSize : 0.0},
        {QStringLiteral("model"), readFile(QStringLiteral("/sys/class/dmi/id/product_name")).trimmed()},
        {QStringLiteral("vendor"), readFile(QStringLiteral("/sys/class/dmi/id/sys_vendor")).trimmed()},
    };

    // Módulos de KDE disponibles (para ocultar enlaces a los que no existen)
    const QStringList lines = runSync(QStringLiteral("kcmshell6"), {QStringLiteral("--list")}).split(QLatin1Char('\n'));
    for (const QString &l : lines) {
        const QString name = l.section(QLatin1Char(' '), 0, 0).trimmed();
        if (name.startsWith(QLatin1String("kcm")))
            m_kcms << name;
    }
}

QString Backend::themeScript() const
{
    const QString env = qEnvironmentVariable("WIN11_THEME_SCRIPT");
    if (!env.isEmpty())
        return env;
    for (const QString &p : {QDir::homePath() + QStringLiteral("/.local/share/win11-kde/theme.sh"),
                             QDir::homePath() + QStringLiteral("/dotfiles/kde-win11/scripts/theme.sh"),
                             QStringLiteral("/usr/share/kde-win11/scripts/theme.sh")}) {
        if (QFileInfo::exists(p))
            return p;
    }
    return {};
}

void Backend::loadTheme()
{
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    rc.beginGroup(QStringLiteral("Appearance"));
    m_mode = rc.value(QStringLiteral("mode"), QStringLiteral("light")).toString();
    m_accent = rc.value(QStringLiteral("accent"), QStringLiteral("#0078D4")).toString();
    m_transparency = rc.value(QStringLiteral("transparency"), QStringLiteral("on")).toString() == QLatin1String("on");
}

QColor Backend::uiAccent() const
{
    QColor c(m_accent);
    auto mix = [](int v, double f) { return f > 0 ? int(v + (255 - v) * f + 0.5) : int(v * (1 + f) + 0.5); };
    const double f = 0; // igual que theme.sh: el énfasis tal cual
    return QColor(mix(c.red(), f), mix(c.green(), f), mix(c.blue(), f));
}

void Backend::applyPalette()
{
    const bool dark = m_mode == QLatin1String("dark");
    QGuiApplication::styleHints()->setColorScheme(dark ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    QPalette pal = QGuiApplication::palette();
    pal.setColor(QPalette::Accent, uiAccent());
    pal.setColor(QPalette::Highlight, uiAccent());
    QGuiApplication::setPalette(pal);
}

QString Backend::wallpaper() const
{
    // Fondo del escritorio actual según Plasma (el appletsrc puede tener contenedores antiguos)
    QString img = runSync(QStringLiteral("qdbus6"),
                          {QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"), QStringLiteral("org.kde.PlasmaShell.evaluateScript"),
                           QStringLiteral("var d=desktops()[0]; d.currentConfigGroup=[\"Wallpaper\",\"org.kde.image\",\"General\"]; print(d.readConfig(\"Image\"))")})
                      .trimmed();
    if (img.isEmpty())
        return {};
    if (!img.startsWith(QLatin1String("file://")))
        img = QUrl::fromLocalFile(img).toString();
    // Si es un paquete de fondo (carpeta), toma su imagen
    const QString local = QUrl(img).toLocalFile();
    if (QFileInfo(local).isDir()) {
        QDirIterator it(local + QStringLiteral("/contents/images"), {QStringLiteral("*.jpg"), QStringLiteral("*.png"), QStringLiteral("*.webp")});
        if (it.hasNext())
            return QUrl::fromLocalFile(it.next()).toString();
    }
    return img;
}

void Backend::setTheme(const QString &mode, const QString &accent, bool transparency)
{
    const QString script = themeScript();
    if (script.isEmpty())
        return;

    // Vista previa inmediata en la propia ventana
    m_mode = mode;
    m_accent = accent;
    m_transparency = transparency;
    applyPalette();
    Q_EMIT themeChanged();

    if (m_busy) {
        m_pending = true;
        return;
    }
    m_busy = true;
    Q_EMIT busyChanged();

    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p]() {
        p->deleteLater();
        m_busy = false;
        if (m_pending) {
            m_pending = false;
            setTheme(m_mode, m_accent, m_transparency);
            return;
        }
        loadTheme();
        applyPalette();
        Q_EMIT busyChanged();
        Q_EMIT themeChanged();
    });
    p->start(QStringLiteral("bash"),
             {script, QStringLiteral("--mode"), mode, QStringLiteral("--accent"), accent, QStringLiteral("--transparency"),
              transparency ? QStringLiteral("on") : QStringLiteral("off")});
}

void Backend::openKcm(const QString &name)
{
    QProcess::startDetached(QStringLiteral("kcmshell6"), {name});
}

void Backend::launch(const QString &program, const QStringList &args)
{
    QProcess::startDetached(program, args);
}

bool Backend::runInTerminal(const QString &commandLine)
{
    const QString wrapped = commandLine + QStringLiteral("; echo; read -rp 'Pulsa Enter para cerrar...'");
    // Terminal y argumentos que preceden a la orden; la primera instalada gana
    static const QList<QPair<QString, QStringList>> terminals = {
        {QStringLiteral("konsole"), {QStringLiteral("-e")}},
        {QStringLiteral("alacritty"), {QStringLiteral("-e")}},
        {QStringLiteral("kitty"), {}},
        {QStringLiteral("foot"), {}},
        {QStringLiteral("wezterm"), {QStringLiteral("start"), QStringLiteral("--")}},
        {QStringLiteral("gnome-terminal"), {QStringLiteral("--")}},
        {QStringLiteral("xterm"), {QStringLiteral("-e")}},
    };
    for (const auto &[program, prefix] : terminals) {
        if (QStandardPaths::findExecutable(program).isEmpty())
            continue;
        return QProcess::startDetached(program, prefix + QStringList{QStringLiteral("bash"), QStringLiteral("-c"), wrapped});
    }
    return false;
}

void Backend::editPanel()
{
    // Modo edición de Plasma: permite mover, añadir y configurar elementos de la barra
    QProcess::startDetached(QStringLiteral("qdbus6"), {QStringLiteral("org.kde.plasmashell"), QStringLiteral("/PlasmaShell"),
                                                       QStringLiteral("org.kde.PlasmaShell.editMode"), QStringLiteral("true")});
}

bool Backend::canCheckUpdates() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("checkupdates")).isEmpty();
}

void Backend::checkUpdates()
{
    if (!canCheckUpdates()) {
        m_lastUpdateCheck = QLocale().toString(QTime::currentTime(), QStringLiteral("HH:mm"));
        Q_EMIT updatesChecked(false, {}, QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat));
        return;
    }
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p](int code) {
        p->deleteLater();
        const QStringList pkgs = QString::fromUtf8(p->readAllStandardOutput()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        // checkupdates: 0 = hay actualizaciones, 2 = ninguna, 1 = error
        const bool ok = code == 0 || code == 2;
        m_lastUpdateCheck = QLocale().toString(QTime::currentTime(), QStringLiteral("HH:mm"));
        Q_EMIT updatesChecked(ok, pkgs, QLocale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat));
    });
    p->start(QStringLiteral("checkupdates"), {});
}

void Backend::loadInstalledApps()
{
    QHash<QString, QVariantMap> byFile;
    QStringList files;
    const QString lang = QLocale().name().section(QLatin1Char('_'), 0, 0);
    for (const QString &dir : QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation)) {
        QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            QFile f(path);
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
                continue;
            QTextStream ts(&f);
            bool inEntry = false;
            QString name, nameLoc, icon, comment, commentLoc;
            bool hidden = false, isApp = false;
            while (!ts.atEnd()) {
                const QString l = ts.readLine().trimmed();
                if (l.startsWith(QLatin1Char('['))) {
                    if (inEntry)
                        break;
                    inEntry = l == QLatin1String("[Desktop Entry]");
                    continue;
                }
                if (!inEntry)
                    continue;
                const QString k = l.section(QLatin1Char('='), 0, 0), v = l.section(QLatin1Char('='), 1);
                if (k == QLatin1String("Name")) name = v;
                else if (k == QStringLiteral("Name[%1]").arg(lang)) nameLoc = v;
                else if (k == QLatin1String("Comment")) comment = v;
                else if (k == QStringLiteral("Comment[%1]").arg(lang)) commentLoc = v;
                else if (k == QLatin1String("Icon")) icon = v;
                else if (k == QLatin1String("Type")) isApp = v == QLatin1String("Application");
                else if ((k == QLatin1String("NoDisplay") || k == QLatin1String("Hidden")) && v == QLatin1String("true")) hidden = true;
            }
            const QString id = QFileInfo(path).fileName();
            if (!isApp || hidden || name.isEmpty() || byFile.contains(id))
                continue;
            byFile.insert(id, {{QStringLiteral("name"), nameLoc.isEmpty() ? name : nameLoc},
                               {QStringLiteral("comment"), commentLoc.isEmpty() ? comment : commentLoc},
                               {QStringLiteral("icon"), icon},
                               {QStringLiteral("path"), path},
                               {QStringLiteral("package"), QString()},
                               {QStringLiteral("version"), QString()}});
            files << path;
        }
    }

    // Paquete propietario de cada .desktop (una sola llamada a pacman, sin bloquear la interfaz)
    auto finish = [this, byFile](const QString &pacmanOut) {
        QHash<QString, QPair<QString, QString>> owners;
        static const QRegularExpression re(QStringLiteral("^(.+) is owned by (\\S+) (\\S+)$"));
        for (const QString &l : pacmanOut.split(QLatin1Char('\n'))) {
            const auto m = re.match(l);
            if (m.hasMatch())
                owners.insert(m.captured(1), {m.captured(2), m.captured(3)});
        }
        QVariantList result;
        for (auto it = byFile.begin(); it != byFile.end(); ++it) {
            QVariantMap app = it.value();
            const auto o = owners.value(app.value(QStringLiteral("path")).toString());
            app[QStringLiteral("package")] = o.first;
            app[QStringLiteral("version")] = o.second;
            result << app;
        }
        std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
        });
        Q_EMIT installedAppsLoaded(result);
    };
    if (files.isEmpty()) {
        finish({});
        return;
    }
    auto *p = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    p->setProcessEnvironment(env);
    connect(p, &QProcess::finished, this, [p, finish]() {
        p->deleteLater();
        finish(QString::fromUtf8(p->readAllStandardOutput()));
    });
    connect(p, &QProcess::errorOccurred, this, [p, finish](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) { // sin pacman: lista sin paquetes
            p->deleteLater();
            finish({});
        }
    });
    p->start(QStringLiteral("pacman"), QStringList{QStringLiteral("-Qo")} + files);
}

void Backend::uninstall(const QString &package)
{
    static const QRegularExpression safe(QStringLiteral("^[a-zA-Z0-9@._+-]+$"));
    if (!safe.match(package).hasMatch())
        return;
    runInTerminal(QStringLiteral("sudo pacman -Rns ") + package);
}

// ---------- Módulos de KDE dentro de la ventana ----------

static KPluginMetaData findKcm(const QString &name)
{
    for (const char *dir : {"plasma/kcms/systemsettings", "plasma/kcms", "plasma/kcms/kinfocenter"}) {
        const KPluginMetaData md = KPluginMetaData::findPluginById(QString::fromLatin1(dir), name);
        if (md.isValid())
            return md;
    }
    return {};
}

bool Backend::canEmbed(const QString &name) const
{
    return findKcm(name).isValid();
}

QObject *Backend::loadKcm(const QString &name, QObject *context)
{
    QQmlEngine *engine = qmlEngine(context);
    const KPluginMetaData md = findKcm(name);
    if (!engine || !md.isValid())
        return nullptr;
    // El motor es de la app: se comparte sin pasarle la propiedad
    std::shared_ptr<QQmlEngine> shared(engine, [](QQmlEngine *) {});
    auto result = KQuickConfigModuleLoader::loadModule(md, nullptr, {}, shared);
    if (!result) {
        qWarning() << "No se pudo cargar" << name << result.errorText;
        return nullptr;
    }
    KQuickConfigModule *module = result.plugin;
    if (!module->mainUi()) {
        qWarning() << "El módulo" << name << "no tiene interfaz QML";
        delete module;
        return nullptr;
    }
    module->load();
    QQmlEngine::setObjectOwnership(module, QQmlEngine::CppOwnership);
    return module;
}

void Backend::unloadKcm(QObject *module)
{
    if (!module)
        return;
    // La interfaz es hija del módulo: se suelta de la escena antes de borrar
    if (auto *m = qobject_cast<KQuickConfigModule *>(module)) {
        if (QQuickItem *ui = m->mainUi())
            ui->setParentItem(nullptr);
    }
    module->deleteLater();
}

// ---------- Portapapeles ----------

void Backend::clearClipboard()
{
    QProcess::startDetached(QStringLiteral("qdbus6"), {QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
                                                       QStringLiteral("org.kde.klipper.klipper.clearClipboardHistory")});
}

QVariantMap Backend::clipboardSettings() const
{
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/klipperrc"), QSettings::IniFormat);
    rc.beginGroup(QStringLiteral("General"));
    return {
        {QStringLiteral("history"), rc.value(QStringLiteral("KeepClipboardContents"), true).toBool()},
        {QStringLiteral("size"), rc.value(QStringLiteral("MaxClipItems"), 20).toInt()},
        {QStringLiteral("images"), !rc.value(QStringLiteral("IgnoreImages"), false).toBool()},
        {QStringLiteral("sync"), rc.value(QStringLiteral("SyncClipboards"), false).toBool()},
    };
}

void Backend::setClipboardSetting(const QString &key, const QVariant &value)
{
    static const QMap<QString, QString> keys{{QStringLiteral("history"), QStringLiteral("KeepClipboardContents")},
                                             {QStringLiteral("size"), QStringLiteral("MaxClipItems")},
                                             {QStringLiteral("images"), QStringLiteral("IgnoreImages")},
                                             {QStringLiteral("sync"), QStringLiteral("SyncClipboards")}};
    if (!keys.contains(key))
        return;
    QVariant v = key == QLatin1String("images") ? QVariant(!value.toBool()) : value;
    // kwriteconfig6 respeta el formato de KConfig y avisa a plasmashell del cambio
    QProcess::execute(QStringLiteral("kwriteconfig6"), {QStringLiteral("--file"), QStringLiteral("klipperrc"), QStringLiteral("--group"),
                                                        QStringLiteral("General"), QStringLiteral("--key"), keys.value(key),
                                                        v.typeId() == QMetaType::Bool ? (v.toBool() ? QStringLiteral("true") : QStringLiteral("false")) : v.toString()});
    QProcess::startDetached(QStringLiteral("qdbus6"), {QStringLiteral("org.kde.klipper"), QStringLiteral("/klipper"),
                                                       QStringLiteral("org.kde.klipper.klipper.reloadConfig")});
}

// ---------- Hardware ----------

bool Backend::hasHardware(const QString &what) const
{
    auto anyIn = [](const QString &dir, const std::function<bool(const QString &)> &test) {
        const auto entries = QDir(dir).entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::System);
        for (const QString &e : entries)
            if (test(dir + QLatin1Char('/') + e))
                return true;
        return false;
    };
    if (what == QLatin1String("battery"))
        return anyIn(QStringLiteral("/sys/class/power_supply"), [](const QString &p) { return readFile(p + QStringLiteral("/type")).trimmed() == QLatin1String("Battery"); });
    if (what == QLatin1String("wifi"))
        return anyIn(QStringLiteral("/sys/class/net"), [](const QString &p) { return QFileInfo::exists(p + QStringLiteral("/wireless")) || QFileInfo::exists(p + QStringLiteral("/phy80211")); });
    if (what == QLatin1String("bluetooth"))
        return QDir(QStringLiteral("/sys/class/bluetooth")).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System).size() > 0;
    if (what == QLatin1String("thunderbolt"))
        return QDir(QStringLiteral("/sys/bus/thunderbolt/devices")).entryList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System).size() > 0;
    if (what == QLatin1String("modem"))
        return anyIn(QStringLiteral("/sys/class/net"), [](const QString &p) { return readFile(p + QStringLiteral("/uevent")).contains(QLatin1String("DEVTYPE=wwan")); })
            || QDir(QStringLiteral("/dev")).entryList({QStringLiteral("cdc-wdm*"), QStringLiteral("wwan*")}, QDir::System).size() > 0;
    // Dispositivos de entrada: nombres en /proc/bus/input/devices
    const QString input = readFile(QStringLiteral("/proc/bus/input/devices")).toLower();
    if (what == QLatin1String("touchpad"))
        return input.contains(QLatin1String("touchpad")) || input.contains(QLatin1String("trackpad"));
    if (what == QLatin1String("touchscreen"))
        return input.contains(QLatin1String("touchscreen")) || input.contains(QLatin1String("touch screen"));
    if (what == QLatin1String("tablet"))
        return input.contains(QLatin1String("wacom")) || input.contains(QLatin1String("pen")) || input.contains(QLatin1String("stylus")) || input.contains(QLatin1String("tablet"));
    return true;
}

// ---------- Nombre del equipo ----------

void Backend::renameHost(const QString &name)
{
    // Igual que Windows: letras, números y guiones; máximo 63 caracteres
    static const QRegularExpression valid(QStringLiteral("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$"));
    if (!valid.match(name).hasMatch()) {
        Q_EMIT hostRenamed(false, QStringLiteral("Usa solo letras, números y guiones (sin espacios), hasta 63 caracteres."));
        return;
    }
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p, name](int code) {
        p->deleteLater();
        if (code == 0) {
            m_hostname = name;
            Q_EMIT hostnameChanged();
            Q_EMIT hostRenamed(true, {});
        } else {
            Q_EMIT hostRenamed(false, code == 126 || code == 127 ? QStringLiteral("Se canceló la autorización.")
                                                                   : QString::fromUtf8(p->readAllStandardError()).trimmed());
        }
    });
    p->start(QStringLiteral("pkexec"), {QStringLiteral("hostnamectl"), QStringLiteral("set-hostname"), name});
}
