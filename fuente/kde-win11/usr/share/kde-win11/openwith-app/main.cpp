#include "openwith.h"

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>

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

// Uso: win11-openwith ARCHIVO... (desde el clic derecho del Explorador: "Elegir otra aplicación")
int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("win11-openwith"));
    app.setApplicationDisplayName(QStringLiteral("Abrir con"));
    app.setDesktopFileName(QStringLiteral("win11-openwith"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("document-open")));
    QQuickStyle::setStyle(QStringLiteral("FluentWinUI3"));

    QCommandLineParser parser;
    parser.addPositionalArgument(QStringLiteral("archivos"), QStringLiteral("Archivos que abrir"));
    parser.process(app);
    QList<QUrl> urls;
    for (const QString &a : parser.positionalArguments())
        urls << QUrl::fromUserInput(a, QDir::currentPath(), QUrl::AssumeLocalFile);
    if (urls.isEmpty())
        return 1;

    OpenWith openWith(urls);
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("openWith"), &openWith);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Win11OpenWith", "Main");
    return app.exec();
}
