// Elemento del menú: alto, con barrita azul si está elegido
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: it
    signal triggered()
    readonly property real s: parent && parent.s ? parent.s : 1
    width: Math.max(172 * s, txt.implicitWidth + 48 * s)
    implicitHeight: 36 * s
    focusPolicy: Qt.NoFocus
    onClicked: {
        triggered()
        if (parent && parent.popupRef)
            parent.popupRef.close()
    }
    background: Rectangle {
        radius: 4 * it.s
        color: it.pressed ? Qt.rgba(1, 1, 1, 0.04) : it.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Rectangle {
            visible: it.checked
            anchors.verticalCenter: parent.verticalCenter
            width: 3 * it.s; height: 16 * it.s; radius: 2
            color: "#60cdff"
        }
    }
    contentItem: Text {
        id: txt
        leftPadding: 16 * it.s
        verticalAlignment: Text.AlignVCenter
        text: it.text
        color: "white"
        font.family: "Selawik"
        font.pixelSize: 14 * it.s
    }
}
