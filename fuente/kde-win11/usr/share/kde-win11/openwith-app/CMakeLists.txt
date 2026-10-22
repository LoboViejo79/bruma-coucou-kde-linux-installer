cmake_minimum_required(VERSION 3.21)
project(win11-openwith LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickControls2 Widgets)
find_package(KF6Service REQUIRED)
find_package(KF6KIO REQUIRED)
qt_policy(SET QTP0001 NEW)

qt_add_executable(win11-openwith main.cpp openwith.cpp openwith.h)
qt_add_qml_module(win11-openwith
  URI Win11OpenWith
  VERSION 1.0
  QML_FILES qml/Main.qml qml/AppRow.qml
)
target_link_libraries(win11-openwith PRIVATE Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Widgets KF6::Service KF6::KIOGui)
install(TARGETS win11-openwith RUNTIME DESTINATION bin)
