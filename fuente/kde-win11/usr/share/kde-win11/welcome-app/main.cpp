#include "backend.h"
#include "glyphprovider.h"

#include <QApplication>
#include <QIcon>
#include <QOffscreenSurface>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

// image://icon/<nombre> -> icono del tema actual
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
    app.setApplicationName(QStringLiteral("win11-welcome"));
    app.setApplicationDisplayName(QStringLiteral("Bienvenido"));
    app.setDesktopFileName(QStringLiteral("win11-welcome"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("org.cachyos.hello")));
    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    Backend backend;
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.addImageProvider(QStringLiteral("glyph"), new GlyphProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    // Paso inicial opcional: win11-welcome theme | tweaks | apps | maintenance | help | done
    QStringList args = app.arguments();
    // --first-run: lanzado por el autoarranque tras la instalación; solo se muestra esa vez
    if (args.removeAll(QStringLiteral("--first-run")))
        backend.setAutostart(false);
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), args.size() > 1 ? args.at(1) : QString());

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Win11Welcome", "Main");

    // Prueba: WIN11_WELCOME_SHOT=/ruta.png [WIN11_WELCOME_SHOT_DELAY=ms] guarda una captura y sale
    const QString shot = qEnvironmentVariable("WIN11_WELCOME_SHOT");
    if (!shot.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        const int delay = qEnvironmentVariableIntValue("WIN11_WELCOME_SHOT_DELAY");
        QTimer::singleShot(delay > 0 ? delay : 3000, &app, [window, shot] {
            window->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
