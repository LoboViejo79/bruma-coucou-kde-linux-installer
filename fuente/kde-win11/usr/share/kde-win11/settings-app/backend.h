#pragma once

#include <QColor>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Puente entre la interfaz QML y el sistema: lee/aplica el tema (theme.sh),
// abre módulos de KDE (kcmshell6), consulta actualizaciones y lista aplicaciones.
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY themeChanged)
    Q_PROPERTY(QString accent READ accent NOTIFY themeChanged)
    Q_PROPERTY(bool transparency READ transparency NOTIFY themeChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString wallpaper READ wallpaper NOTIFY themeChanged)
    Q_PROPERTY(QVariantMap sysInfo READ sysInfo CONSTANT)
    Q_PROPERTY(QStringList kcms READ kcms CONSTANT)
    Q_PROPERTY(QString hostname READ hostname NOTIFY hostnameChanged)
    // Hora de la última búsqueda de actualizaciones ("" si aún no se buscó)
    Q_PROPERTY(QString lastUpdateCheck READ lastUpdateCheck NOTIFY updatesChecked)
    // checkupdates viene en pacman-contrib, que puede no estar instalado
    Q_PROPERTY(bool canCheckUpdates READ canCheckUpdates CONSTANT)

public:
    explicit Backend(QObject *parent = nullptr);

    QString mode() const { return m_mode; }
    QString accent() const { return m_accent; }
    bool transparency() const { return m_transparency; }
    bool busy() const { return m_busy; }
    QString wallpaper() const;
    QVariantMap sysInfo() const { return m_sysInfo; }
    QStringList kcms() const { return m_kcms; }
    QString hostname() const { return m_hostname; }
    QString lastUpdateCheck() const { return m_lastUpdateCheck; }
    // Cambia el nombre del equipo (pide la contraseña de administrador)
    Q_INVOKABLE void renameHost(const QString &name);
    bool canCheckUpdates() const;

    Q_INVOKABLE void setTheme(const QString &mode, const QString &accent, bool transparency);
    Q_INVOKABLE void openKcm(const QString &name);
    // ¿Se puede mostrar dentro de la ventana? (módulos QML; los de QWidget van en ventana aparte)
    Q_INVOKABLE bool canEmbed(const QString &name) const;
    // Carga un módulo de KDE en el motor QML de la app; devuelve el KQuickConfigModule o null
    Q_INVOKABLE QObject *loadKcm(const QString &name, QObject *context);
    Q_INVOKABLE void unloadKcm(QObject *module);
    // Portapapeles (lo gestiona plasmashell en Plasma 6)
    Q_INVOKABLE void clearClipboard();
    Q_INVOKABLE QVariantMap clipboardSettings() const;
    Q_INVOKABLE void setClipboardSetting(const QString &key, const QVariant &value);
    // Hardware presente (para ocultar páginas sin sentido: batería, táctil, módem...)
    Q_INVOKABLE bool hasHardware(const QString &what) const;
    Q_INVOKABLE void launch(const QString &program, const QStringList &args = {});
    // Devuelve false si no hay ninguna terminal conocida instalada
    Q_INVOKABLE bool runInTerminal(const QString &commandLine);
    Q_INVOKABLE void editPanel();
    Q_INVOKABLE void checkUpdates();
    // Lista asíncrona: emite installedAppsLoaded (pacman -Qo puede tardar con la caché fría)
    Q_INVOKABLE void loadInstalledApps();
    Q_INVOKABLE void uninstall(const QString &package);

    // Color de interfaz derivado del énfasis (más claro en oscuro, como Windows)
    Q_INVOKABLE QColor uiAccent() const;

Q_SIGNALS:
    void themeChanged();
    void busyChanged();
    void hostnameChanged();
    void hostRenamed(bool ok, const QString &message);
    void updatesChecked(bool ok, const QStringList &packages, const QString &checkedAt);
    void installedAppsLoaded(const QVariantList &apps);

private:
    void loadTheme();
    void applyPalette();
    QString themeScript() const;

    QString m_mode = QStringLiteral("light");
    QString m_accent = QStringLiteral("#0078D4");
    bool m_transparency = true;
    bool m_busy = false;
    // Última elección hecha mientras theme.sh trabajaba; se aplica al terminar
    bool m_pending = false;
    QVariantMap m_sysInfo;
    QStringList m_kcms;
    QString m_hostname;
    QString m_lastUpdateCheck;
};
