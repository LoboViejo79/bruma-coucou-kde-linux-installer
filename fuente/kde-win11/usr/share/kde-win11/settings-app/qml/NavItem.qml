import QtQuick
import QtQuick.Controls

// Elemento del panel de navegación de Configuración de Windows 11:
// fondo gris al seleccionar y "píldora" de color de énfasis a la izquierda.
Item {
    id: root
    property string title
    property string iconName
    property bool selected: false
    signal clicked()

    height: 38

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 4
        radius: 4
        color: root.selected || mouse.containsMouse ? win.navSelected : "transparent"
        opacity: root.selected ? 1 : (mouse.containsMouse ? 0.7 : 1)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        id: pill
        x: 4
        width: 3
        radius: 1.5
        anchors.verticalCenter: parent.verticalCenter
        height: root.selected ? (mouse.pressed ? 10 : 16) : 0
        color: win.accent
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Image {
        id: icon
        x: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 18; height: 18
        sourceSize: Qt.size(18, 18)
        source: "image://icon/" + root.iconName
    }

    Label {
        anchors.left: icon.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        elide: Text.ElideRight
        font.pixelSize: 14
        color: win.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
