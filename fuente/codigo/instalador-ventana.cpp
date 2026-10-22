/*
 * Coucou: la ventana del instalador (bin/coucou-instalador) con sus pantallas desde fuente/ventana.
 *
 * La ventana viene compilada con sus pantallas QML adentro y su código C++ no está en este
 * proyecto. Igual que con Configuración (configuracion-paginas.cpp): construir.sh arma con
 * fuente/ventana bin/ventana.rcc, y esta biblioteca (la carga instalador-ventana-carga.c) lo registra
 * ANTES que los recursos del programa, así valen las pantallas del proyecto. Como el programa trae
 * sus pantallas también precompiladas (y esas ganarían), se apaga esa caché solo en la ventana.
 *
 * Además suma lo que la ventana no traía (import CoucouCopias): ver el historial y las copias de
 * seguridad (copia.sh ver), abrir la carpeta de las copias y desinstalar (desinstalar.sh).
 *
 * También la deja siempre clara, aunque el tema del sistema sea oscuro.
 *
 * Si falta el .rcc (COUCOU_VENTANA), no hace nada: la ventana usa sus pantallas de siempre.
 */
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QIcon>
#include <QObject>
#include <QProcess>
#include <QQmlEngine>
#include <QResource>
#include <QSettings>
#include <QStandardPaths>
#include <QString>
#include <QUrl>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

class Copias : public QObject {
    Q_OBJECT
    // Desinstalando desde la ventana (desinstalar.sh --ventana): como la pantalla de instalar
    Q_PROPERTY(bool ocupado READ ocupado NOTIFY cambio)
    Q_PROPERTY(QString estado READ estado NOTIFY cambio)
    Q_PROPERTY(int progreso READ progreso NOTIFY cambio)
    Q_PROPERTY(QString salida READ salida NOTIFY cambio)
    Q_PROPERTY(int resultado READ resultado NOTIFY cambio)    // -1 = todavía no; 0 = bien
    Q_PROPERTY(int avisos READ avisos NOTIFY cambio)          // líneas "!!": pasos que no salieron
public:
    using QObject::QObject;
    bool ocupado() const { return m_ocupado; }
    QString estado() const { return m_estado; }
    int progreso() const { return m_progreso; }
    QString salida() const { return m_salida; }
    int resultado() const { return m_resultado; }
    int avisos() const { return m_avisos; }
Q_SIGNALS:
    void historial(const QString &texto);
    void cambio();
public:
    // Desinstala aquí mismo (pide la contraseña con pkexec); el avance llega por las propiedades
    Q_INVOKABLE void desinstalarAqui(const QString &carpeta, bool conApps) {
        if (m_ocupado) return;
        m_ocupado = true; m_estado = QStringLiteral("Empezando…"); m_progreso = 0; m_salida.clear();
        m_resultado = -1; m_avisos = 0; m_resto.clear();
        Q_EMIT cambio();
        auto *p = new QProcess(this);
        p->setProcessEnvironment(limpio());
        p->setProcessChannelMode(QProcess::MergedChannels);
        QStringList args{carpeta + QStringLiteral("/desinstalar.sh"), QStringLiteral("--ventana")};
        if (conApps) args << QStringLiteral("--con-apps");
        if (getuid() == 0) args << QStringLiteral("--usuario") << usuario();
        connect(p, &QProcess::readyRead, this, [this, p]() { leer(QString::fromUtf8(p->readAll())); });
        connect(p, &QProcess::finished, this, [this, p](int codigo, QProcess::ExitStatus) {
            leer(QString::fromUtf8(p->readAll()) + QLatin1Char('\n'));
            m_ocupado = false; m_resultado = codigo;
            if (codigo == 126 || codigo == 127) m_estado = QStringLiteral("Hace falta la contraseña de administrador para desinstalar. No se cambió nada.");
            Q_EMIT cambio();
            p->deleteLater();
        });
        p->start(QStringLiteral("bash"), args);
    }
    Q_INVOKABLE void olvidarDesinstalar() { m_resultado = -1; Q_EMIT cambio(); }
    Q_INVOKABLE void reiniciar() { QProcess::startDetached(QStringLiteral("systemctl"), {QStringLiteral("reboot")}); }
    // Primera instalación, historial y copias (copia.sh ver, no cambia nada): llega en historial()
    Q_INVOKABLE void ver(const QString &carpeta) {
        auto *p = new QProcess(this);
        p->setProcessEnvironment(limpio());
        connect(p, &QProcess::finished, this, [this, p](int, QProcess::ExitStatus) {
            const QString t = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
            Q_EMIT historial(t.isEmpty() ? QStringLiteral("No se pudo leer el historial.") : t);
            p->deleteLater();
        });
        connect(p, &QProcess::errorOccurred, this, [this, p](QProcess::ProcessError) {
            Q_EMIT historial(QStringLiteral("No se pudo leer el historial."));
            p->deleteLater();
        });
        p->start(QStringLiteral("bash"), {carpeta + QStringLiteral("/copia.sh"), QStringLiteral("ver"), usuario()});
    }
    // Abre una terminal con desinstalar.sh: muestra el historial, pregunta y pide la contraseña
    Q_INVOKABLE bool desinstalar(const QString &carpeta, bool simular) {
        QStringList args{QStringLiteral("--hold"), QStringLiteral("-e"), QStringLiteral("bash"), carpeta + QStringLiteral("/desinstalar.sh")};
        if (simular) args << QStringLiteral("--simular");
        if (getuid() == 0) args << QStringLiteral("--usuario") << usuario();
        QProcess p;
        p.setProgram(QStringLiteral("konsole"));
        p.setArguments(args);
        p.setProcessEnvironment(limpio());
        return p.startDetached();
    }
    // La carpeta con las copias de cada instalación y actualización
    Q_INVOKABLE void abrirCopias() {
        QString home = QDir::homePath();
        if (getuid() == 0) {
            QProcess p; p.start(QStringLiteral("getent"), {QStringLiteral("passwd"), usuario()}); p.waitForFinished(3000);
            const QStringList c = QString::fromUtf8(p.readAllStandardOutput()).split(QLatin1Char(':'));
            if (c.size() > 5) home = c[5];
        }
        QDesktopServices::openUrl(QUrl::fromLocalFile(home + QStringLiteral("/.local/share/coucou-instalador")));
    }
private:
    bool m_ocupado = false;
    QString m_estado, m_salida, m_resto;
    int m_progreso = 0, m_resultado = -1, m_avisos = 0;
    // "@@ N texto" es el paso y el porcentaje; "@@ texto", un mensaje; lo demás va a los detalles
    void leer(const QString &trozo) {
        m_resto += trozo;
        int i;
        while ((i = m_resto.indexOf(QLatin1Char('\n'))) >= 0) {
            const QString l = m_resto.left(i); m_resto.remove(0, i + 1);
            if (l.startsWith(QStringLiteral("@@ "))) {
                const QString r = l.mid(3);
                bool ok = false; const int n = r.section(QLatin1Char(' '), 0, 0).toInt(&ok);
                if (ok) { m_progreso = n; m_estado = r.section(QLatin1Char(' '), 1); }
                else m_estado = r;
            } else {
                if (l.startsWith(QStringLiteral("!!"))) m_avisos++;
                m_salida += l + QLatin1Char('\n');
            }
        }
        Q_EMIT cambio();
    }
    // El entorno sin lo de esta ventana (la biblioteca, sus pantallas y la caché apagada)
    static QProcessEnvironment limpio() {
        QProcessEnvironment e = QProcessEnvironment::systemEnvironment();
        e.remove(QStringLiteral("LD_PRELOAD"));
        e.remove(QStringLiteral("COUCOU_VENTANA"));
        if (e.contains(QStringLiteral("COUCOU_VENTANA_CACHE"))) {
            e.remove(QStringLiteral("QML_DISABLE_DISK_CACHE"));
            e.remove(QStringLiteral("COUCOU_VENTANA_CACHE"));
        }
        return e;
    }
    static QString usuario() {
        const QByteArray u = qgetenv("COUCOU_INSTALADOR_USUARIO");
        return u.isEmpty() ? QString::fromLocal8Bit(qgetenv("USER")) : QString::fromLocal8Bit(u);
    }
};

static void registrar() {
    // El tema de KDE ya se cargó (o no): lo que abra la ventana (instalar.sh, la barra, Plasma)
    // vuelve a tener el de siempre
    if (const char *t = getenv("COUCOU_VENTANA_TEMA")) {
        if (strcmp(t, "-") == 0) unsetenv("QT_QPA_PLATFORMTHEME");
        else setenv("QT_QPA_PLATFORMTHEME", t, 1);
        unsetenv("COUCOU_VENTANA_TEMA");
        // Sin el tema de KDE, los iconos de los botones: los del tema de iconos de la cuenta
        QSettings kde(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/kdeglobals"),
                      QSettings::IniFormat);
        const QString iconos = kde.value(QStringLiteral("Icons/Theme")).toString();
        QIcon::setThemeName(iconos.isEmpty() ? QStringLiteral("breeze") : iconos);
        QIcon::setFallbackThemeName(QStringLiteral("breeze"));
    }
    qmlRegisterSingletonType<Copias>("CoucouCopias", 1, 0, "Copias",
                                     [](QQmlEngine *, QJSEngine *) -> QObject * { return new Copias; });
}
Q_COREAPP_STARTUP_FUNCTION(registrar)

// La carga instalador-ventana-carga.c, solo dentro de la ventana del instalador
__attribute__((constructor)) static void coucou_ventana() {
    const char *p = getenv("COUCOU_VENTANA");
    if (p && access(p, R_OK) == 0 && QResource::registerResource(QString::fromLocal8Bit(p))) {
        // Sin esto valen las pantallas precompiladas del programa. (instalar.sh la quita para lo que
        // abre: COUCOU_VENTANA_CACHE dice que la puso esta biblioteca)
        if (!getenv("QML_DISABLE_DISK_CACHE")) { setenv("QML_DISABLE_DISK_CACHE", "1", 1); setenv("COUCOU_VENTANA_CACHE", "1", 1); }
        // Siempre clara, como la pintan sus pantallas: el estilo de los controles (FluentWinUI3)
        // sigue al tema de KDE, y con uno oscuro (el de CachyOS, que vuelve al desinstalar Coucou)
        // los interruptores salían con la bolita negra y las casillas oscuras sobre la tarjeta
        // clara. Pedirle "claro" (QStyleHints::setColorScheme) el tema de KDE no lo hace caso: la
        // ventana arranca con el genérico de Qt, que es claro, y registrar() devuelve el de antes
        // (la ventana se vuelve a abrir a sí misma: el de antes se guarda una sola vez)
        if (!getenv("COUCOU_VENTANA_TEMA")) {
            const char *t = getenv("QT_QPA_PLATFORMTHEME");
            setenv("COUCOU_VENTANA_TEMA", t && *t ? t : "-", 1);
        }
        setenv("QT_QPA_PLATFORMTHEME", "generic", 1);
    }
}

#include "instalador-ventana.moc"
