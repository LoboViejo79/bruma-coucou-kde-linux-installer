#include "systools.h"

#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

SysTools::SysTools(QObject *parent)
    : QObject(parent)
{
}

// ---------------- Servicios ----------------

void SysTools::loadServices()
{
    if (m_loading)
        return;
    m_loading = true;
    // Se piden los del sistema y los de la sesión a la vez, en segundo plano
    auto *results = new QVariantList;
    auto *pending = new int(2);
    auto finish = [this, results, pending] {
        if (--*pending)
            return;
        std::sort(results->begin(), results->end(), [](const QVariant &a, const QVariant &b) {
            return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
        });
        m_services = *results;
        delete results;
        delete pending;
        m_loading = false;
        Q_EMIT servicesChanged();
    };
    for (bool user : {false, true}) {
        auto *p = new QProcess(this);
        connect(p, &QProcess::finished, this, [p, user, results, finish] {
            const QJsonArray units = QJsonDocument::fromJson(p->readAllStandardOutput()).array();
            p->deleteLater();
            // PID principal de cada servicio en marcha
            for (const QJsonValue &v : units) {
                const QJsonObject o = v.toObject();
                QString name = o.value(QStringLiteral("unit")).toString();
                // Plantillas y envoltorios de autoarranque (esos están en "Aplicaciones de arranque")
                if (name.endsWith(QLatin1String("@.service")) || name.startsWith(QLatin1String("app-")) || name.startsWith(QLatin1String("dbus-:")))
                    continue;
                // Nombres escapados de systemd: \x2d -> -
                static const QRegularExpression esc(QStringLiteral("\\\\x([0-9a-fA-F]{2})"));
                for (auto m = esc.match(name); m.hasMatch(); m = esc.match(name))
                    name.replace(m.capturedStart(), m.capturedLength(), QChar(m.captured(1).toInt(nullptr, 16)));
                const QString sub = o.value(QStringLiteral("sub")).toString();
                const QString active = o.value(QStringLiteral("active")).toString();
                name.chop(8);   // ".service"
                results->append(QVariantMap{
                    {QStringLiteral("name"), name},
                    {QStringLiteral("description"), o.value(QStringLiteral("description")).toString()},
                    {QStringLiteral("running"), active == QLatin1String("active")},
                    {QStringLiteral("status"), active == QLatin1String("active") ? QStringLiteral("En ejecución")
                                               : active == QLatin1String("failed") ? QStringLiteral("Con errores")
                                                                                   : QStringLiteral("Detenido")},
                    {QStringLiteral("group"), user ? QStringLiteral("Usuario") : QStringLiteral("Sistema")},
                    {QStringLiteral("user"), user},
                    {QStringLiteral("sub"), sub},
                });
            }
            finish();
        });
        QStringList args{QStringLiteral("list-units"), QStringLiteral("--type=service"), QStringLiteral("--all"), QStringLiteral("--no-pager"), QStringLiteral("-o"), QStringLiteral("json")};
        if (user)
            args.prepend(QStringLiteral("--user"));
        p->start(QStringLiteral("systemctl"), args);
    }
}

void SysTools::serviceAction(const QString &unit, const QString &action, bool user)
{
    static const QStringList allowed{QStringLiteral("start"), QStringLiteral("stop"), QStringLiteral("restart")};
    if (!allowed.contains(action) || unit.isEmpty())
        return;
    auto *p = new QProcess(this);
    connect(p, &QProcess::finished, this, [this, p] {
        p->deleteLater();
        loadServices();
    });
    // systemctl pide la contraseña él mismo (polkit) para los servicios del sistema
    QStringList args{action, unit + QStringLiteral(".service")};
    if (user)
        args.prepend(QStringLiteral("--user"));
    p->start(QStringLiteral("systemctl"), args);
}

// ---------------- Aplicaciones de arranque ----------------

static QString userAutostart()
{
    return QDir::homePath() + QStringLiteral("/.config/autostart");
}

void SysTools::loadStartup()
{
    // Las del usuario tapan a las del sistema con el mismo nombre de archivo
    QMap<QString, QString> files;
    for (const QString &dir : {QStringLiteral("/etc/xdg/autostart"), userAutostart()}) {
        QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files);
        while (it.hasNext()) {
            const QString f = it.next();
            files.insert(QFileInfo(f).fileName(), f);
        }
    }
    const QString lang = QLocale().name().left(2);
    const QString desktop = qEnvironmentVariable("XDG_CURRENT_DESKTOP");
    QVariantList out;
    for (auto it = files.cbegin(); it != files.cend(); ++it) {
        QSettings d(it.value(), QSettings::IniFormat);
        d.beginGroup(QStringLiteral("Desktop Entry"));
        // Lo que no se ejecuta en Plasma (OnlyShowIn=GNOME, etc.) no se muestra
        const QStringList only = d.value(QStringLiteral("OnlyShowIn")).toString().split(QLatin1Char(';'), Qt::SkipEmptyParts);
        const QStringList notIn = d.value(QStringLiteral("NotShowIn")).toString().split(QLatin1Char(';'), Qt::SkipEmptyParts);
        if ((!only.isEmpty() && !only.contains(desktop)) || notIn.contains(desktop))
            continue;
        // Los componentes internos de Plasma no son "aplicaciones de arranque"
        if (d.value(QStringLiteral("X-KDE-autostart-phase")).isValid() && it.value().startsWith(QLatin1String("/etc")))
            continue;
        const QString exec = d.value(QStringLiteral("Exec")).toString();
        if (exec.isEmpty())
            continue;
        const bool enabled = !d.value(QStringLiteral("Hidden")).toBool() && d.value(QStringLiteral("X-GNOME-Autostart-enabled"), true).toBool();
        QString name = d.value(QStringLiteral("Name[%1]").arg(lang), d.value(QStringLiteral("Name"))).toString();
        out.append(QVariantMap{
            {QStringLiteral("id"), it.key()},
            {QStringLiteral("name"), name.isEmpty() ? it.key() : name},
            {QStringLiteral("icon"), d.value(QStringLiteral("Icon")).toString()},
            {QStringLiteral("publisher"), it.value().startsWith(QDir::homePath()) && !QFileInfo::exists(QStringLiteral("/etc/xdg/autostart/") + it.key())
                                              ? QStringLiteral("Usuario") : QStringLiteral("Sistema")},
            {QStringLiteral("enabled"), enabled},
            {QStringLiteral("exec"), exec},
        });
    }
    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return QString::localeAwareCompare(a.toMap().value(QStringLiteral("name")).toString(), b.toMap().value(QStringLiteral("name")).toString()) < 0;
    });
    m_startup = out;
    Q_EMIT startupChanged();
}

void SysTools::setStartupEnabled(const QString &id, bool on)
{
    if (id.contains(QLatin1Char('/')))
        return;
    QDir().mkpath(userAutostart());
    const QString userFile = userAutostart() + QLatin1Char('/') + id;
    const QString systemFile = QStringLiteral("/etc/xdg/autostart/") + id;
    if (!QFileInfo::exists(userFile) && QFileInfo::exists(systemFile))
        QFile::copy(systemFile, userFile);
    // QSettings reescribiría el archivo entero (y escaparía claves): se cambia solo la línea Hidden
    QFile f(userFile);
    if (!f.open(QIODevice::ReadOnly))
        return;
    QStringList lines = QString::fromUtf8(f.readAll()).split(QLatin1Char('\n'));
    f.close();
    lines.removeIf([](const QString &l) { return l.startsWith(QLatin1String("Hidden=")) || l.startsWith(QLatin1String("X-GNOME-Autostart-enabled=")); });
    const int entry = lines.indexOf(QStringLiteral("[Desktop Entry]"));
    if (!on)
        lines.insert(entry >= 0 ? entry + 1 : 0, QStringLiteral("Hidden=true"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(lines.join(QLatin1Char('\n')).toUtf8());
    f.close();
    loadStartup();
}

void SysTools::openStartupLocation(const QString &id)
{
    const QString userFile = userAutostart() + QLatin1Char('/') + id;
    const QString file = QFileInfo::exists(userFile) ? userFile : QStringLiteral("/etc/xdg/autostart/") + id;
    if (!QStandardPaths::findExecutable(QStringLiteral("dolphin")).isEmpty())
        QProcess::startDetached(QStringLiteral("dolphin"), {QStringLiteral("--select"), file});
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(file).path()));
}

void SysTools::launch(const QString &program, const QStringList &args)
{
    QString path = QStandardPaths::findExecutable(program);
    if (path.isEmpty())
        path = QStandardPaths::findExecutable(program, {QDir::homePath() + QStringLiteral("/.local/bin")});
    QProcess::startDetached(path.isEmpty() ? program : path, args);
}
