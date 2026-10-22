// Genera el estado de ventana (QMainWindow::saveState) de Dolphin: barra superior, barra de
// comandos debajo (toda la anchura) y solo el panel Lugares visible a la izquierda. Uso: dolphin-state ANCHO_PANEL
// Compilar: g++ -std=c++17 -fPIC dolphin-state.cpp -o dolphin-state $(pkg-config --cflags --libs Qt6Widgets)
// El resultado va en DOLPHIN_STATE de scripts/explorer.sh.
#include <QApplication>
#include <QDockWidget>
#include <QMainWindow>
#include <QToolBar>
#include <cstdio>
int main(int argc, char **argv)
{
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QApplication app(argc, argv);
    QMainWindow w;
    w.setCentralWidget(new QWidget);
    auto tb = [&](const char *n) { auto *t = new QToolBar; t->setObjectName(QString::fromLatin1(n)); w.addToolBar(Qt::TopToolBarArea, t); };
    tb("mainToolBar");
    w.addToolBarBreak(Qt::TopToolBarArea);
    tb("commandBar");
    auto dock = [&](const char *n, Qt::DockWidgetArea a, bool vis) {
        auto *d = new QDockWidget; d->setObjectName(QString::fromLatin1(n)); d->setWidget(new QWidget);
        w.addDockWidget(a, d); d->setVisible(vis); return d;
    };
    auto *places = dock("placesDock", Qt::LeftDockWidgetArea, true);
    dock("foldersDock", Qt::LeftDockWidgetArea, false);
    dock("infoDock", Qt::RightDockWidgetArea, false);
    dock("terminalDock", Qt::BottomDockWidgetArea, false);
    w.resize(1000, 650);
    w.show();
    app.processEvents();
    w.resizeDocks({places}, {argc > 1 ? atoi(argv[1]) : 180}, Qt::Horizontal);
    app.processEvents();
    std::puts(w.saveState().toBase64().constData());
}
