import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fila horizontal del inicio: "Título  ›" + tarjetas con flechas al pasar el ratón
ColumnLayout {
    id: root
    property string title
    property var apps: []
    property bool loading: apps.length === 0
    signal seeAll()

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: root.title
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: win.text
        }
        ToolButton {
            text: "Ver todo  ›"
            flat: true
            font.pixelSize: 13
            onClicked: root.seeAll()
        }
        Item { Layout.fillWidth: true }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 246

        ListView {
            id: list
            anchors.fill: parent
            anchors.topMargin: 6
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: root.apps
            boundsBehavior: Flickable.StopAtBounds
            delegate: AppCard { app: modelData }
            Behavior on contentX { enabled: !list.moving; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // Esqueletos mientras carga
        Row {
            visible: root.loading
            y: 6
            spacing: 12
            Repeater {
                model: 6
                Rectangle {
                    width: 176; height: 228; radius: 8
                    color: win.cardBg
                    border.color: win.cardBorder
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.5; duration: 700 }
                        NumberAnimation { from: 0.5; to: 1; duration: 700 }
                    }
                }
            }
        }

        HoverHandler { id: hover }

        component Arrow: RoundButton {
            width: 32; height: 48; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            opacity: hover.hovered ? 0.95 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            icon.width: 12; icon.height: 12
        }
        Arrow {
            anchors.left: parent.left
            visible: !list.atXBeginning
            icon.source: "image://icon/go-previous"
            onClicked: list.contentX = Math.max(0, list.contentX - list.width * 0.8)
        }
        Arrow {
            anchors.right: parent.right
            visible: !list.atXEnd
            icon.source: "image://icon/go-next"
            onClicked: list.contentX = Math.min(list.contentWidth - list.width, list.contentX + list.width * 0.8)
        }
    }
}
