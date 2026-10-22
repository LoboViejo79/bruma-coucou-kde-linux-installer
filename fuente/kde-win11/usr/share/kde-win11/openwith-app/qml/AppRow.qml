import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fila de una aplicación: icono y nombre; la seleccionada lleva la barra de énfasis a la izquierda
Rectangle {
    id: root
    property var app: ({})
    property bool selected: false
    signal picked()
    signal activated()

    implicitHeight: 48
    radius: 4
    color: selected ? win.selectedBg : (mouse.containsMouse ? win.hoverBg : "transparent")
    Behavior on color { ColorAnimation { duration: 90 } }

    Rectangle {
        visible: root.selected
        width: 3; height: 18; radius: 1.5
        anchors.verticalCenter: parent.verticalCenter
        color: win.accent
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 14
        Image {
            source: "image://icon/" + (root.app.icon || "application-x-executable")
            sourceSize: Qt.size(28, 28)
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
        }
        Label {
            text: root.app.name || ""
            color: win.text
            font.pixelSize: 14
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.picked()
        onDoubleClicked: root.activated()
    }
}
