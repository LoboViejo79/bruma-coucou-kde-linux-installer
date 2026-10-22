cmake_minimum_required(VERSION 3.21)
project(win11-settings LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickControls2 Widgets Svg)
find_package(KF6KCMUtils REQUIRED)
find_package(KF6I18n REQUIRED)
find_package(KF6CoreAddons REQUIRED)
qt_policy(SET QTP0001 NEW)

qt_add_executable(win11-settings main.cpp backend.cpp backend.h glyphprovider.h)
qt_add_qml_module(win11-settings
  URI Win11Settings
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    qml/NavItem.qml
    qml/SettingsCard.qml
    qml/PageHeader.qml
    qml/LinksPage.qml
    qml/SystemPage.qml
    qml/PersonalizationPage.qml
    qml/ColorsPage.qml
    qml/AppsPage.qml
    qml/UpdatePage.qml
    qml/SearchPage.qml
    qml/Pages.js
    qml/KcmPage.qml
    qml/HomePage.qml
    qml/FluentIcon.qml
    qml/CaptionButtons.qml
    qml/ResizeEdges.qml
    qml/ClipboardPage.qml
)
target_link_libraries(win11-settings PRIVATE Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Svg
  KF6::KCMUtilsQuick KF6::KCMUtilsCore KF6::I18n KF6::I18nQml KF6::CoreAddons)
install(TARGETS win11-settings RUNTIME DESTINATION bin)
