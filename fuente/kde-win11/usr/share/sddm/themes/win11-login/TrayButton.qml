// Botón cuadrado transparente de la esquina inferior derecha
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: b
    property real s: 1
    property string iconSource: ""
    property string label: ""
    width: Math.max(44 * s, lbl.implicitWidth + 24 * s)
    height: 44 * s
    focusPolicy: Qt.NoFocus
    background: Rectangle {
        radius: 6 * b.s
        color: b.pressed ? Qt.rgba(1, 1, 1, 0.08) : b.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
    }
    contentItem: Item {
        Image {
            anchors.centerIn: parent
            visible: b.iconSource !== ""
            source: b.iconSource
            sourceSize: Qt.size(22 * b.s, 22 * b.s)
        }
        Text {
            id: lbl
            anchors.centerIn: parent
            visible: b.label !== ""
            text: b.label
            color: "white"
            font.family: "Selawik"
            font.pixelSize: 14 * b.s
            font.weight: Font.DemiBold
        }
    }
}
