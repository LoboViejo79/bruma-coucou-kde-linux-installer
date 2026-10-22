#include "openwith.h"

#include <KApplicationTrader>
#include <KIO/ApplicationLauncherJob>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>

namespace
{
bool visibleApp(const KService::Ptr &s)
{
    return s && s->isApplication() && !s->noDisplay() && !s->exec().isEmpty();
}

bool byName(const QVariant &a, const QVariant &b)
{
    return a.toMap().value(QStringLiteral("name")).toString().localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
}
} // namespace

OpenWith::OpenWith(const QList<QUrl> &urls, QObject *parent)
    : QObject(parent)
    , m_urls(urls)
{
    // Modo y color de énfasis de theme.sh (~/.config/win11rc); el énfasis se aclara en modo oscuro
    // y se oscurece en claro, como hace theme.sh para la interfaz
    const QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    m_dark = rc.value(QStringLiteral("Appearance/mode")).toString() == QLatin1String("dark");
    QColor accent(rc.value(QStringLiteral("Appearance/accent"), QStringLiteral("#0078D4")).toString());
    if (!accent.isValid())
        accent = QColor(QStringLiteral("#0078D4"));
    auto mix = [](int c, double f) {
        return f > 0 ? qRound(c + (255 - c) * f) : qRound(c * (1 + f));
    };
    const double f = 0; // igual que theme.sh: el énfasis tal cual
    m_accent = QColor(mix(accent.red(), f), mix(accent.green(), f), mix(accent.blue(), f));

    const QMimeDatabase db;
    const QMimeType mime = m_urls.isEmpty() ? db.mimeTypeForName(QStringLiteral("application/octet-stream"))
                                            : (m_urls.first().isLocalFile() ? db.mimeTypeForFile(m_urls.first().toLocalFile())
                                                                            : db.mimeTypeForUrl(m_urls.first()));
    m_mime = mime.name();
    m_fileIcon = mime.iconName();
    m_typeName = mime.comment();

    const KService::Ptr preferred = KApplicationTrader::preferredService(m_mime);
    if (visibleApp(preferred))
        m_current = entry(preferred);

    QStringList seen;
    if (!m_current.isEmpty())
        seen << m_current.value(QStringLiteral("id")).toString();
    for (const KService::Ptr &s : KApplicationTrader::queryByMimeType(m_mime, visibleApp)) {
        if (!seen.contains(s->storageId())) {
            seen << s->storageId();
            m_suggested << entry(s);
        }
    }
    for (const KService::Ptr &s : KApplicationTrader::query(visibleApp)) {
        if (!seen.contains(s->storageId())) {
            seen << s->storageId();
            m_others << entry(s);
        }
    }
    std::sort(m_others.begin(), m_others.end(), byName);
}

QString OpenWith::title() const
{
    return m_urls.size() > 1 ? QStringLiteral("¿Cómo quieres abrir estos archivos?") : QStringLiteral("¿Cómo quieres abrir este archivo?");
}

QString OpenWith::fileName() const
{
    if (m_urls.size() > 1)
        return QStringLiteral("%1 archivos").arg(m_urls.size());
    return m_urls.isEmpty() ? QString() : m_urls.first().fileName();
}

QVariantMap OpenWith::entry(const KService::Ptr &service) const
{
    return {{QStringLiteral("id"), service->storageId().isEmpty() ? service->entryPath() : service->storageId()},
            {QStringLiteral("name"), service->name()},
            {QStringLiteral("icon"), service->icon()},
            {QStringLiteral("comment"), service->genericName().isEmpty() ? service->comment() : service->genericName()}};
}

KService::Ptr OpenWith::service(const QString &id) const
{
    if (m_extra.contains(id))
        return m_extra.value(id);
    KService::Ptr s = KService::serviceByStorageId(id);
    return s ? s : KService::serviceByDesktopPath(id);
}

void OpenWith::open(const QString &id, bool always)
{
    const KService::Ptr s = service(id);
    if (!s) {
        Q_EMIT failed(QStringLiteral("No se encuentra la aplicación"));
        return;
    }
    if (always) {
        KApplicationTrader::setPreferredService(m_mime, s);
        // La base de datos de apps de KDE debe enterarse de la nueva asociación
        QProcess::startDetached(QStringLiteral("kbuildsycoca6"), {QStringLiteral("--noincremental")});
    }
    auto *job = new KIO::ApplicationLauncherJob(s);
    job->setUrls(m_urls);
    connect(job, &KJob::result, this, [this, job]() {
        if (job->error()) {
            Q_EMIT failed(job->errorString());
            return;
        }
        QCoreApplication::quit();
    });
    job->start();
}

QVariantMap OpenWith::browse()
{
    const QString path = QFileDialog::getOpenFileName(nullptr, QStringLiteral("Buscar otra aplicación en este equipo"), QStringLiteral("/usr/bin"));
    if (path.isEmpty())
        return {};
    const QFileInfo fi(path);
    if (!fi.isExecutable()) {
        Q_EMIT failed(QStringLiteral("«%1» no es una aplicación").arg(fi.fileName()));
        return {};
    }
    // Entrada .desktop oculta para el ejecutable (como hace KDE con "Otra aplicación…"), para poder
    // abrirlo y, con "Siempre", dejarlo como predeterminado
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
    QDir().mkpath(dir);
    const QString file = dir + QStringLiteral("/userapp-%1-win11.desktop").arg(fi.fileName());
    QFile f(file);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return {};
    QString exec = path;
    exec.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    f.write(QStringLiteral("[Desktop Entry]\nType=Application\nName=%1\nExec=\"%2\" %F\nIcon=application-x-executable\nNoDisplay=true\nMimeType=%3;\n")
                .arg(fi.fileName(), exec, m_mime)
                .toUtf8());
    f.close();
    KService::Ptr s(new KService(file));
    const QString id = QFileInfo(file).fileName();
    m_extra.insert(id, s);
    QVariantMap e = entry(s);
    e[QStringLiteral("id")] = id;
    return e;
}
