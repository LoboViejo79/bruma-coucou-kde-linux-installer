#pragma once

#include <QColor>
#include <QObject>
#include <QProcess>
#include <QVariantMap>

// Lo que hace CachyOS Hello (ajustes, paquetes, mantenimiento, enlaces), para la interfaz de "Bienvenido"
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY themeChanged)
    Q_PROPERTY(QString accent READ accent NOTIFY themeChanged)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QVariantMap state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(QString status READ status NOTIFY outputChanged)
    Q_PROPERTY(QString output READ output NOTIFY outputChanged)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY autostartChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QString mode() const { return m_mode; }
    QString accent() const { return m_accent; }
    QString userName() const;
    QVariantMap state() const { return m_state; }
    bool running() const { return m_proc != nullptr; }
    QString status() const { return m_status; }
    QString output() const { return m_output; }
    bool autostart() const;
    void setAutostart(bool on);

    Q_INVOKABLE void setTheme(const QString &mode, const QString &accent);
    Q_INVOKABLE void refresh();
    // Tareas de administrador (pide la contraseña una vez): ver win11-welcome-helper
    Q_INVOKABLE void runAdmin(const QStringList &actions);
    // Lo mismo en una terminal, para ver o responder a pacman
    Q_INVOKABLE bool runAdminInTerminal(const QStringList &actions);
    Q_INVOKABLE void setUserService(const QString &unit, bool on);
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE void launch(const QString &program, const QStringList &args = {});
    Q_INVOKABLE bool has(const QString &program) const;

Q_SIGNALS:
    void themeChanged();
    void stateChanged();
    void runningChanged();
    void outputChanged();
    void autostartChanged();
    void finished(bool ok);

private:
    void loadTheme();
    void applyPalette();
    QString themeScript() const;
    QString helper() const;

    QString m_mode = QStringLiteral("light");
    QString m_accent = QStringLiteral("#0078D4");
    QVariantMap m_state;
    QProcess *m_proc = nullptr;
    QString m_status;
    QString m_output;
};
