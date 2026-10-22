#pragma once

#include <QColor>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <atomic>

// Puente entre la tienda (QML) y Flatpak: lista lo instalado, busca actualizaciones e
// instala/actualiza/desinstala con libflatpak en un hilo aparte, una tarea cada vez.
// Las apps nuevas van a la instalación de usuario: no piden contraseña, como en Windows.
// También las nativas (paquetes de CachyOS/Arch o del AUR), por /usr/lib/coucou/tienda-nativo:
// cada app se puede instalar de una u otra forma, y se dice de dónde vino.
class StoreBackend : public QObject
{
    Q_OBJECT
    // Claro/oscuro y color de énfasis de Coucou (~/.config/win11rc): cambian en vivo
    Q_PROPERTY(QString mode READ mode NOTIFY themeChanged)
    // Foto de perfil (file://…, vacío si no hay) e iniciales para la barra de título
    Q_PROPERTY(QString avatar READ avatar CONSTANT)
    Q_PROPERTY(QString initials READ initials CONSTANT)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged)
    // id en minúsculas -> {id, name, version, installation (user|system|native), origin
    // (flathub-user|flathub-system|repo|aur), originLabel, size, icon, pkg} y, si también está
    // instalada como nativa además de Flathub, native: {pkg, version, origin, originLabel}
    Q_PROPERTY(QVariantMap installed READ installed NOTIFY installedChanged)
    // ids con actualización pendiente
    Q_PROPERTY(QStringList updates READ updates NOTIFY updatesChanged)
    // runtimes y extensiones con actualización (no se muestran como apps)
    Q_PROPERTY(int componentUpdates READ componentUpdates NOTIFY updatesChanged)
    Q_PROPERTY(bool checkingUpdates READ checkingUpdates NOTIFY updatesChanged)
    Q_PROPERTY(QString lastCheck READ lastCheck NOTIFY updatesChanged)
    // id -> {action: install|update|uninstall, state: queued|running, progress 0-100, status}
    Q_PROPERTY(QVariantMap jobs READ jobs NOTIFY jobsChanged)
    // id -> {state: checking|ok|error, size (bytes que ocupará), message}: resultado de check()
    Q_PROPERTY(QVariantMap availability READ availability NOTIFY availabilityChanged)
    // id -> {state: checking|ok, repo: {pkg, version, repo}, aur: {pkg, version}, preferred:
    // flathub|repo|aur}: de dónde más se puede instalar (resultado de findSources())
    Q_PROPERTY(QVariantMap sources READ sources NOTIFY sourcesChanged)

public:
    explicit StoreBackend(QObject *parent = nullptr);
    ~StoreBackend() override;

    QString mode() const { return m_mode; }
    QString avatar() const { return m_avatar; }
    QString initials() const { return m_initials; }
    QString userName() const { return m_userName; }
    QColor accent() const { return m_accent; }
    QVariantMap installed() const { return m_installed; }
    QStringList updates() const { return m_updates; }
    int componentUpdates() const { return m_componentUpdates; }
    bool checkingUpdates() const { return m_checking; }
    QString lastCheck() const { return m_lastCheck; }
    QVariantMap jobs() const { return m_jobs; }
    QVariantMap availability() const { return m_availability; }
    QVariantMap sources() const { return m_sources; }

    Q_INVOKABLE void refreshInstalled();
    Q_INVOKABLE void checkUpdates();
    // source: flathub | repo | aur; vacío = el preferido para esa app (apps.conf), o Flathub
    Q_INVOKABLE void install(const QString &id, const QString &name = {}, const QString &source = {});
    Q_INVOKABLE void update(const QString &id);
    Q_INVOKABLE void updateAll();
    // source: flatpak | native; vacío = la que haya (Flathub si están las dos)
    Q_INVOKABLE void uninstall(const QString &id, const QString &source = {});
    // Busca el paquete nativo de una app (homepage: su sitio web, para reconocerla en el AUR)
    Q_INVOKABLE void findSources(const QString &id, const QString &homepage = {});
    // Cancela una tarea en cola o la que está en marcha
    Q_INVOKABLE void cancel(const QString &id);
    Q_INVOKABLE void launch(const QString &id);
    // Simula la instalación (dependencias, arquitectura, espacio) sin descargar nada
    Q_INVOKABLE void check(const QString &id);
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE QString formatSize(double bytes) const;

    // Progreso de la tarea en curso (llega desde el hilo de trabajo ya en el hilo principal)
    void onProgress(const QString &id, int pct, const QString &status);

Q_SIGNALS:
    void installedChanged();
    void updatesChanged();
    void jobsChanged();
    void availabilityChanged();
    void sourcesChanged();
    void themeChanged();
    // Aviso breve para la interfaz (p. ej. "No se pudo instalar Spotify: ...")
    void notify(const QString &text, bool error);

private:
    struct Job {
        QString id;
        QString name;
        QString action;
        QString source; // install: flathub|repo|aur · uninstall: flatpak|native
    };
    void enqueue(const QString &id, const QString &name, const QString &action, const QString &source);
    bool runNative(const Job &job, QString *error); // en el hilo de trabajo
    void mergeInstalled();
    void loadTheme();
    void startNext();
    void runJob(const Job &job); // en el hilo de trabajo
    void setJob(const QString &id, const QVariantMap &values);

    QString m_mode = QStringLiteral("light");
    bool m_accentSet = true;   // la primera vez se aplica siempre
    QString m_avatar;
    QString m_initials;
    QString m_userName;
    QColor m_accent = QColor(QStringLiteral("#0078D4"));
    QVariantMap m_installed;      // lo que ve la interfaz (Flathub + nativas)
    QVariantMap m_flatpaks;       // id en minúsculas -> app de Flathub
    QVariantMap m_native;         // id en minúsculas -> app nativa
    QVariantMap m_sources;
    QStringList m_updates;
    int m_componentUpdates = 0;
    bool m_checking = false;
    QString m_lastCheck;
    QVariantMap m_jobs;
    QVariantMap m_availability;
    QList<Job> m_queue;
    bool m_running = false;
    QString m_current;
    int m_refreshGen = 0;                 // cada pedido de la lista de instaladas
    QHash<QString, int> m_finishing;      // id -> lista que ya la refleja: terminadas bien, esperando a verse en la lista de instaladas
    std::atomic<void *> m_cancellable{nullptr};
    std::atomic<qint64> m_nativePid{0};     // tienda-nativo en marcha (para cancelar)
};
