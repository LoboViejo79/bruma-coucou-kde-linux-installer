#include "backend.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleHints>
#include <QUrl>

static QString runSync(const QString &program, const QStringList &args)
{
    QProcess p;
    p.start(program, args);
    p.waitForFinished(5000);
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

static QString autostartFile()
{
    return QDir::homePath() + QStringLiteral("/.config/autostart/win11-welcome.desktop");
}

Backend::Backend(QObject *parent)
    : QObject(parent)
{
    loadTheme();
    applyPalette();
    refresh();
}

QString Backend::userName() const
{
    return qEnvironmentVariable("USER");
}

void Backend::loadTheme()
{
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    rc.beginGroup(QStringLiteral("Appearance"));
    m_mode = rc.value(QStringLiteral("mode"), QStringLiteral("light")).toString();
    m_accent = rc.value(QStringLiteral("accent"), QStringLiteral("#0078D4")).toString();
}

void Backend::applyPalette()
{
    QGuiApplication::styleHints()->setColorScheme(m_mode == QLatin1String("dark") ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    QPalette pal = QGuiApplication::palette();
    pal.setColor(QPalette::Accent, QColor(m_accent));
    pal.setColor(QPalette::Highlight, QColor(m_accent));
    QGuiApplication::setPalette(pal);
}

QString Backend::themeScript() const
{
    for (const QString &p : {QDir::homePath() + QStringLiteral("/.local/share/win11-kde/theme.sh"),
                             QDir::homePath() + QStringLiteral("/dotfiles/kde-win11/scripts/theme.sh"),
                             QStringLiteral("/usr/share/kde-win11/scripts/theme.sh")}) {
        if (QFileInfo::exists(p))
            return p;
    }
    return {};
}

void Backend::setTheme(const QString &mode, const QString &accent)
{
    // Vista previa al momento; el escritorio se actualiza en segundo plano
    m_mode = mode;
    m_accent = accent;
    applyPalette();
    Q_EMIT themeChanged();
    const QString script = themeScript();
    if (script.isEmpty())
        return;
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    const QString transparency = rc.value(QStringLiteral("Appearance/transparency"), QStringLiteral("on")).toString();
    QProcess::startDetached(QStringLiteral("bash"), {script, QStringLiteral("--mode"), mode, QStringLiteral("--accent"), accent,
                                                     QStringLiteral("--transparency"), transparency});
}

void Backend::refresh()
{
    auto enabled = [](const QStringList &args) { return runSync(QStringLiteral("systemctl"), args) == QLatin1String("enabled"); };
    auto installed = [](const QString &pkg) {
        QProcess p;
        p.start(QStringLiteral("pacman"), {QStringLiteral("-Q"), pkg});
        p.waitForFinished(5000);
        return p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
    };
    QVariantMap s;
    s[QStringLiteral("ananicy")] = enabled({QStringLiteral("is-enabled"), QStringLiteral("ananicy-cpp.service")});
    s[QStringLiteral("oomd")] = enabled({QStringLiteral("is-enabled"), QStringLiteral("systemd-oomd.service")});
    s[QStringLiteral("bluetooth")] = enabled({QStringLiteral("is-enabled"), QStringLiteral("bluetooth.service")});
    s[QStringLiteral("psd")] = installed(QStringLiteral("profile-sync-daemon"))
        && enabled({QStringLiteral("--user"), QStringLiteral("is-enabled"), QStringLiteral("psd.service")});
    s[QStringLiteral("updates")] = installed(QStringLiteral("cachy-update"))
        && enabled({QStringLiteral("--user"), QStringLiteral("is-enabled"), QStringLiteral("arch-update.timer")});
    s[QStringLiteral("hasUpdates")] = installed(QStringLiteral("cachy-update"));
    s[QStringLiteral("gaming")] = installed(QStringLiteral("cachyos-gaming-meta"));
    s[QStringLiteral("winboat")] = installed(QStringLiteral("winboat"));
    s[QStringLiteral("lock")] = QFileInfo::exists(QStringLiteral("/var/lib/pacman/db.lck"));
    m_state = s;
    Q_EMIT stateChanged();
}

QString Backend::helper() const
{
    const QString env = qEnvironmentVariable("WIN11_WELCOME_HELPER");
    if (!env.isEmpty())
        return env;
    const QString local = QDir::homePath() + QStringLiteral("/.local/bin/win11-welcome-helper");
    return QFileInfo::exists(local) ? local : QStandardPaths::findExecutable(QStringLiteral("win11-welcome-helper"));
}

void Backend::runAdmin(const QStringList &actions)
{
    if (m_proc || actions.isEmpty())
        return;
    m_output.clear();
    m_status = QStringLiteral("Esperando permiso de administrador…");
    Q_EMIT outputChanged();

    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::readyRead, this, [this] {
        while (m_proc->canReadLine()) {
            const QString line = QString::fromUtf8(m_proc->readLine()).trimmed();
            if (line.isEmpty())
                continue;
            if (line.startsWith(QLatin1String("@@ "))) {
                m_status = line.mid(3) + QStringLiteral("…");
            } else {
                m_output += line + QLatin1Char('\n');
                if (m_output.size() > 20000)
                    m_output = m_output.right(16000);
            }
            Q_EMIT outputChanged();
        }
    });
    connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus st) {
        m_output += QString::fromUtf8(m_proc->readAll());
        m_proc->deleteLater();
        m_proc = nullptr;
        // 126/127: se canceló la contraseña o no hay pkexec
        const bool ok = st == QProcess::NormalExit && code == 0;
        m_status = ok ? QStringLiteral("Listo") : (code == 126 || code == 127 ? QStringLiteral("Se canceló la autorización") : QStringLiteral("Algo salió mal"));
        Q_EMIT outputChanged();
        Q_EMIT runningChanged();
        refresh();
        Q_EMIT finished(ok);
    });
    m_proc->start(QStringLiteral("pkexec"), QStringList{helper()} + actions);
    Q_EMIT runningChanged();
}

bool Backend::runAdminInTerminal(const QStringList &actions)
{
    QString cmd = QStringLiteral("sudo ") + helper();
    for (const QString &a : actions)
        cmd += QLatin1Char(' ') + a;
    cmd += QStringLiteral("; echo; read -rp 'Pulsa Enter para cerrar...'");
    static const QList<QPair<QString, QStringList>> terminals = {
        {QStringLiteral("konsole"), {QStringLiteral("-e")}},
        {QStringLiteral("alacritty"), {QStringLiteral("-e")}},
        {QStringLiteral("kitty"), {}},
        {QStringLiteral("foot"), {}},
        {QStringLiteral("xterm"), {QStringLiteral("-e")}},
    };
    for (const auto &[program, prefix] : terminals) {
        if (!QStandardPaths::findExecutable(program).isEmpty())
            return QProcess::startDetached(program, prefix + QStringList{QStringLiteral("bash"), QStringLiteral("-c"), cmd});
    }
    return false;
}

void Backend::setUserService(const QString &unit, bool on)
{
    runSync(QStringLiteral("systemctl"), {QStringLiteral("--user"), on ? QStringLiteral("enable") : QStringLiteral("disable"), QStringLiteral("--now"), unit});
    refresh();
}

void Backend::openUrl(const QString &url)
{
    QDesktopServices::openUrl(QUrl(url));
}

// Programas del sistema o de ~/.local/bin (donde se instalan Configuración y la Store)
static QString findProgram(const QString &program)
{
    const QString found = QStandardPaths::findExecutable(program);
    return found.isEmpty() ? QStandardPaths::findExecutable(program, {QDir::homePath() + QStringLiteral("/.local/bin")}) : found;
}

void Backend::launch(const QString &program, const QStringList &args)
{
    const QString path = findProgram(program);
    QProcess::startDetached(path.isEmpty() ? program : path, args);
}

bool Backend::has(const QString &program) const
{
    return !findProgram(program).isEmpty();
}

bool Backend::autostart() const
{
    return QFileInfo::exists(autostartFile());
}

void Backend::setAutostart(bool on)
{
    if (on == autostart())
        return;
    if (on) {
        QDir().mkpath(QFileInfo(autostartFile()).path());
        QFile f(autostartFile());
        if (f.open(QIODevice::WriteOnly)) {
            const QString bin = QFileInfo::exists(QDir::homePath() + QStringLiteral("/.local/bin/win11-welcome"))
                ? QDir::homePath() + QStringLiteral("/.local/bin/win11-welcome")
                : QStringLiteral("win11-welcome");
            f.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=Bienvenido\nExec=%1\nIcon=org.cachyos.hello\n").arg(bin).toUtf8());
        }
    } else {
        QFile::remove(autostartFile());
    }
    Q_EMIT autostartChanged();
}
