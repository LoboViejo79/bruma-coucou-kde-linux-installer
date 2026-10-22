import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tarjeta de ajuste de Windows 11: icono, título, descripción y un control
// (o una flecha ">" si abre otra página). `trailing` recibe el control.
Rectangle {
    id: root
    property string title
    property string description
    property string iconName
    property string glyph: ""              // icono de línea (FluentIcon); si no, icono del tema
    property bool clickable: true
    property bool chevron: clickable
    property bool external: false          // abre otra ventana: icono ↗ en vez de >
    property alias trailing: trailingSlot.data
    property int topRadius: 4
    property int bottomRadius: 4
    signal clicked()

    implicitHeight: Math.max(68, row.implicitHeight + 24)
    color: clickable && mouse.containsMouse ? (mouse.pressed ? win.cardBg : win.cardHover) : win.cardBg
    border.color: win.cardBorder
    topLeftRadius: topRadius; topRightRadius: topRadius
    bottomLeftRadius: bottomRadius; bottomRightRadius: bottomRadius
    Behavior on color { ColorAnimation { duration: 100 } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.clickable
        enabled: root.clickable
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 16

        FluentIcon {
            visible: root.glyph !== ""
            name: root.glyph
            size: 20
            Layout.preferredWidth: 20; Layout.preferredHeight: 20
        }

        Image {
            visible: root.glyph === "" && root.iconName !== ""
            Layout.preferredWidth: 20; Layout.preferredHeight: 20
            sourceSize: Qt.size(20, 20)
            source: root.iconName ? "image://icon/" + root.iconName : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 14
                color: win.text
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.description
                font.pixelSize: 12
                color: win.subtext
                elide: Text.ElideRight
            }
        }

        RowLayout { id: trailingSlot; spacing: 12 }

        FluentIcon {
            visible: root.chevron
            name: root.external ? "open" : "next"
            size: root.external ? 14 : 12
            stroke: 1.8
            color: win.text
            Layout.rightMargin: 4
        }
    }
}
