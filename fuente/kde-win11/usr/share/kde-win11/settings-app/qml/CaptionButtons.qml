import QtQuick
import QtQuick.Controls

// Botones de ventana de Windows 11 (minimizar, maximizar/restaurar, cerrar) para ventanas sin marco
Row {
    id: root
    property var window: Window.window
    readonly property bool maximized: window && window.visibility === Window.Maximized

    component Caption: Rectangle {
        id: b
        property string glyph
        property bool danger: false
        signal activated()
        width: 46; height: 32
        color: area.containsMouse ? (danger ? "#C42B1C" : (win.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05))) : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
        FluentIcon {
            anchors.centerIn: parent
            name: b.glyph
            size: 14
            stroke: 1.1
            color: area.containsMouse && b.danger ? "white" : win.text
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: b.activated()
        }
    }

    Caption { glyph: "min"; onActivated: root.window.showMinimized() }
    Caption {
        glyph: root.maximized ? "restore" : "max"
        onActivated: root.maximized ? root.window.showNormal() : root.window.showMaximized()
    }
    Caption { glyph: "close"; danger: true; onActivated: root.window.close() }
}
