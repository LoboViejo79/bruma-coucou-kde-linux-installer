import QtQuick
import QtQuick.Controls

// Botón de la barra de comandos (arriba a la derecha de cada página): glifo + texto, sin borde
ToolButton {
    id: root
    property string glyph
    flat: true
    implicitHeight: 34
    leftPadding: 10
    rightPadding: 12
    opacity: enabled ? 1 : 0.4
    contentItem: Row {
        spacing: 8
        FluentIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: 16
            stroke: 1.4
            color: root.checked ? win.accentText : win.text
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            visible: root.text !== ""
            color: win.text
        }
    }
}
