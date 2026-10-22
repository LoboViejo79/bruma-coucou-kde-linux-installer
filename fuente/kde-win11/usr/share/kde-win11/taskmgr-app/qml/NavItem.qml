import QtQuick
import QtQuick.Controls

// Elemento del panel de navegación del Administrador de tareas: glifo, texto,
// fondo al pasar/seleccionar y la "píldora" de color de énfasis.
Item {
    id: root
    property string title
    property string glyph
    property bool selected: false
    property bool compact: false
    signal clicked()

    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        radius: 4
        color: root.selected ? win.navSelected : (mouse.containsMouse ? win.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    Rectangle {
        x: 4
        width: 3
        radius: 1.5
        anchors.verticalCenter: parent.verticalCenter
        height: root.selected ? (mouse.pressed ? 10 : 16) : 0
        color: win.accent
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    FluentIcon {
        id: icon
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.glyph
        size: 18
        stroke: 1.4
    }
    Label {
        anchors.left: icon.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.compact
        text: root.title
        elide: Text.ElideRight
        color: win.text
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
    ToolTip.visible: root.compact && root.title !== "" && mouse.containsMouse
    ToolTip.text: root.title
    ToolTip.delay: 500
}
