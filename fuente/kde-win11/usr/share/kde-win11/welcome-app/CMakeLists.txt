cmake_minimum_required(VERSION 3.21)
project(win11-welcome LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickControls2 Widgets Svg OpenGL)
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

qt_add_executable(win11-welcome main.cpp backend.cpp backend.h glyphprovider.h)
qt_add_qml_module(win11-welcome
  URI Win11Welcome
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    qml/Illustration.qml
    qml/OptionCard.qml
    qml/ProgressScreen.qml
    qml/FluentIcon.qml
    qml/CaptionButtons.qml
)
target_link_libraries(win11-welcome PRIVATE Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Widgets Qt6::Svg Qt6::OpenGL)
install(TARGETS win11-welcome RUNTIME DESTINATION bin)
install(PROGRAMS win11-welcome-helper DESTINATION bin)
