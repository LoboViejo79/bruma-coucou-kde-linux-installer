#include "backend.h"
#include "glyphprovider.h"

#include <QApplication>
#include <QIcon>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QTimer>

#include <KLocalizedQmlContext>
#include <KLocalizedString>

// image://icon/<nombre> -> icono del tema actual (Win11 / Win11-dark)
class IconProvider : public QQuickImageProvider
{
public:
    IconProvider()
        : QQuickImageProvider(QQuickImageProvider::Pixmap)
    {
    }

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        const int s = requestedSize.width() > 0 ? requestedSize.width() : 32;
        QIcon icon = QIcon::fromTheme(id);
        if (icon.isNull())
            icon = QIcon::fromTheme(QStringLiteral("application-x-executable"));
        const QPixmap pm = icon.pixmap(QSize(s, s));
        if (size)
            *size = pm.size();
        return pm;
    }
};

// ¿OpenGL por software (llvmpipe, p. ej. máquina virtual sin 3D)? Entonces el renderizador
// "software" de Qt Quick es más fluido y gasta la mitad de memoria y CPU.
static bool softwareGL()
{
    QOpenGLContext ctx;
    if (!ctx.create())
        return true;
    QOffscreenSurface surface;
    surface.create();
    if (!ctx.makeCurrent(&surface))
        return true;
    const QByteArray renderer = reinterpret_cast<const char *>(ctx.functions()->glGetString(GL_RENDERER));
    ctx.doneCurrent();
    return renderer.contains("llvmpipe") || renderer.contains("softpipe") || renderer.contains("Software Rasterizer");
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND") && softwareGL())
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    app.setApplicationName(QStringLiteral("win11-settings"));
    app.setApplicationDisplayName(QStringLiteral("Configuración"));
    app.setDesktopFileName(QStringLiteral("win11-settings"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("preferences-system")));

    // Controles oficiales de Windows 11 incluidos en Qt
    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    Backend backend;
    QQmlApplicationEngine engine;
    // Los módulos de KDE incrustados usan i18n() en QML: sin esto saldrían en inglés
    KLocalizedString::setApplicationDomain("systemsettings");
    KLocalization::setupLocalizedContext(&engine);
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.addImageProvider(QStringLiteral("glyph"), new GlyphProvider);
    engine.addImageProvider(QStringLiteral("avatar"), new AvatarProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);

    // Página inicial opcional: win11-settings colors | update | apps | system ...
    const QStringList args = app.arguments();
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), args.size() > 1 ? args.at(1) : QString());

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Win11Settings", "Main");

    // Prueba: WIN11_SETTINGS_SHOT=/ruta.png [WIN11_SETTINGS_SHOT_DELAY=ms] guarda una captura y sale
    const QString shot = qEnvironmentVariable("WIN11_SETTINGS_SHOT");
    if (!shot.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        const int delay = qEnvironmentVariableIntValue("WIN11_SETTINGS_SHOT_DELAY");
        QTimer::singleShot(delay > 0 ? delay : 4000, &app, [window, shot] {
            window->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
