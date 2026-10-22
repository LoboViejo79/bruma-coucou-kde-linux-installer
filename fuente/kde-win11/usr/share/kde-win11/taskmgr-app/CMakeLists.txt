cmake_minimum_required(VERSION 3.21)
project(win11-taskmgr LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickControls2 Widgets Svg OpenGL Network)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(win11-taskmgr main.cpp sysmon.cpp sysmon.h processmodel.cpp processmodel.h systools.cpp systools.h graph.h glyphprovider.h)
qt_add_qml_module(win11-taskmgr
  URI Win11TaskMgr
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    qml/NavItem.qml
    qml/CommandButton.qml
    qml/DataTable.qml
    qml/PageHeader.qml
    qml/ProcessesPage.qml
    qml/PerformancePage.qml
    qml/HistoryPage.qml
    qml/StartupPage.qml
    qml/UsersPage.qml
    qml/DetailsPage.qml
    qml/ServicesPage.qml
    qml/SettingsPage.qml
    qml/RunTaskDialog.qml
    qml/FluentIcon.qml
    qml/CaptionButtons.qml
    qml/ResizeEdges.qml
)
target_link_libraries(win11-taskmgr PRIVATE Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Svg Qt6::OpenGL Qt6::Network)
install(TARGETS win11-taskmgr RUNTIME DESTINATION bin)
