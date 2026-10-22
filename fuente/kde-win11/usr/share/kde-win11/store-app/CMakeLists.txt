cmake_minimum_required(VERSION 3.21)
project(win11-store LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickControls2 Widgets Network Svg)
find_package(PkgConfig REQUIRED)
pkg_check_modules(FLATPAK REQUIRED IMPORTED_TARGET flatpak)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(win11-store main.cpp storebackend.cpp storebackend.h glyphprovider.h)
qt_add_qml_module(win11-store
  URI Win11Store
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    qml/RailButton.qml
    qml/AppCard.qml
    qml/AppRow.qml
    qml/AppGrid.qml
    qml/HomePage.qml
    qml/BrowsePage.qml
    qml/SearchPage.qml
    qml/AppPage.qml
    qml/LibraryPage.qml
    qml/ActionButton.qml
    qml/FluentIcon.qml
    qml/RoundCorners.qml
    qml/CaptionButtons.qml
    qml/ResizeEdges.qml
    qml/TrendPanel.qml
    qml/GameRow.qml
    qml/Rounded.qml
    qml/Glow.qml
    qml/Flathub.js
  RESOURCES
    icons/win11-store.svg
)
# GLib define "signals" como macro de Qt; libflatpak usa ese nombre en sus cabeceras
target_compile_definitions(win11-store PRIVATE QT_NO_KEYWORDS)
target_link_libraries(win11-store PRIVATE Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Network Qt6::Svg PkgConfig::FLATPAK)
install(TARGETS win11-store RUNTIME DESTINATION bin)
install(FILES icons/win11-store.svg DESTINATION share/icons/hicolor/scalable/apps)
