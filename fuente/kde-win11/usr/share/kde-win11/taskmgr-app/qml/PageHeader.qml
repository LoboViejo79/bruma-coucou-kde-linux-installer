import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Título de la página a la izquierda y la barra de comandos a la derecha
RowLayout {
    id: root
    property string title
    default property alias commands: bar.data
    Layout.fillWidth: true
    Layout.leftMargin: 24
    Layout.rightMargin: 16
    Layout.topMargin: 14
    Layout.bottomMargin: 8
    spacing: 8

    Label {
        text: root.title
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: win.text
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.minimumWidth: 120
    }
    Row {
        id: bar
        spacing: 2
    }
}
