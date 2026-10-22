#include "glyphprovider.h"
#include "graph.h"
#include "processmodel.h"
#include "sysmon.h"
#include "systools.h"

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
#include <QDir>
#include <QPalette>
#include <QSettings>
#include <QStyleHints>
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
        QIcon icon = id.startsWith(QLatin1Char('/')) ? QIcon(id) : QIcon::fromTheme(id);
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
    app.setApplicationName(QStringLiteral("win11-taskmgr"));
    app.setOrganizationName(QStringLiteral("win11-kde"));
    app.setApplicationDisplayName(QStringLiteral("Administrador de tareas"));
    app.setDesktopFileName(QStringLiteral("win11-taskmgr"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("utilities-system-monitor")));
    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    // Tema (claro/oscuro y énfasis) de ~/.config/win11rc, como el resto de apps
    QSettings rc(QDir::homePath() + QStringLiteral("/.config/win11rc"), QSettings::IniFormat);
    const QString mode = rc.value(QStringLiteral("Appearance/mode"), QStringLiteral("light")).toString();
    const QColor accent(rc.value(QStringLiteral("Appearance/accent"), QStringLiteral("#0078D4")).toString());
    QGuiApplication::styleHints()->setColorScheme(mode == QLatin1String("dark") ? Qt::ColorScheme::Dark : Qt::ColorScheme::Light);
    QPalette pal = QGuiApplication::palette();
    pal.setColor(QPalette::Accent, accent);
    pal.setColor(QPalette::Highlight, accent);
    QGuiApplication::setPalette(pal);

    qmlRegisterType<Graph>("Win11TaskMgr.Core", 1, 0, "Graph");
    qmlRegisterType<ProcessModel>("Win11TaskMgr.Core", 1, 0, "ProcessModel");
    qmlRegisterUncreatableType<SysMon>("Win11TaskMgr.Core", 1, 0, "SysMon", QStringLiteral("usa sysmon"));

    SysMon sysmon;
    SysTools tools;
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.addImageProvider(QStringLiteral("glyph"), new GlyphProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("sysmon"), &sysmon);
    engine.rootContext()->setContextProperty(QStringLiteral("tools"), &tools);
    engine.rootContext()->setContextProperty(QStringLiteral("themeDark"), mode == QLatin1String("dark"));
    engine.rootContext()->setContextProperty(QStringLiteral("themeAccent"), accent);
    // Página inicial opcional: processes | performance | history | startup | users | details | services
    const QStringList args = app.arguments();
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), args.size() > 1 ? args.at(1) : QString());

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Win11TaskMgr", "Main");

    // Prueba: WIN11_TASKMGR_SHOT=/ruta.png [WIN11_TASKMGR_SHOT_DELAY=ms] guarda una captura y sale
    const QString shot = qEnvironmentVariable("WIN11_TASKMGR_SHOT");
    if (!shot.isEmpty() && !engine.rootObjects().isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
        const int delay = qEnvironmentVariableIntValue("WIN11_TASKMGR_SHOT_DELAY");
        QTimer::singleShot(delay > 0 ? delay : 3500, &app, [window, shot] {
            window->grabWindow().save(shot);
            QCoreApplication::quit();
        });
    }
    return app.exec();
}
