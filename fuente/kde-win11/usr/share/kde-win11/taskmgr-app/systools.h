#pragma once

#include <QObject>
#include <QVariantList>

// Servicios (systemd) y aplicaciones de arranque (autostart de XDG)
class SysTools : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList services READ services NOTIFY servicesChanged)
    Q_PROPERTY(QVariantList startupApps READ startupApps NOTIFY startupChanged)

public:
    explicit SysTools(QObject *parent = nullptr);

    QVariantList services() const { return m_services; }
    QVariantList startupApps() const { return m_startup; }

    Q_INVOKABLE void loadServices();
    // action: start | stop | restart; user: servicio de la sesión (sin contraseña)
    Q_INVOKABLE void serviceAction(const QString &unit, const QString &action, bool user);
    Q_INVOKABLE void loadStartup();
    Q_INVOKABLE void setStartupEnabled(const QString &id, bool on);
    Q_INVOKABLE void openStartupLocation(const QString &id);
    Q_INVOKABLE void launch(const QString &program, const QStringList &args = {});

Q_SIGNALS:
    void servicesChanged();
    void startupChanged();

private:
    QVariantList m_services, m_startup;
    bool m_loading = false;
};
