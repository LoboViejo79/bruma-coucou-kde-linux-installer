import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Fila compacta de la página Juegos: "Título ›" y una tira de tarjetas chicas que se recorre de
// costado (touchpad, Mayús + rueda o las flechas). La rueda normal sigue bajando la página.
ColumnLayout {
    id: root
    property string title
    property var fetch: null          // fetch(page, perPage, cb)
    property var apps: []
    readonly property bool loading: apps.length === 0
    signal seeAll()

    spacing: 8
    Component.onCompleted: if (fetch) fetch(1, 24, function (a) { if (root) root.apps = a })

    RowLayout {
        Layout.fillWidth: true
        MouseArea {
            implicitWidth: titleRow.implicitWidth
            implicitHeight: titleRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: root.seeAll()
            RowLayout {
                id: titleRow
                spacing: 8
                Label { text: root.title; font.pixelSize: 17; font.weight: Font.DemiBold; color: win.text }
                FluentIcon { name: "next"; size: 12; stroke: 2.2; color: win.text }
            }
        }
        Item { Layout.fillWidth: true }
        component PageArrow: RoundButton {
            property string glyph
            implicitWidth: 28; implicitHeight: 28
            flat: true
            contentItem: Item { FluentIcon { anchors.centerIn: parent; name: parent.parent.glyph; size: 10; stroke: 2.6; color: win.text } }
        }
        PageArrow { glyph: "prev"; enabled: !list.atXBeginning; opacity: enabled ? 1 : 0.35; onClicked: list.mover(-1) }
        PageArrow { glyph: "next"; enabled: !list.atXEnd; opacity: enabled ? 1 : 0.35; onClicked: list.mover(1) }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 150

        ListView {
            id: list
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: root.apps
            // Sin arrastre ni rueda propia: la rueda la reparte el MouseArea de abajo
            interactive: false
            // Con las flechas se anima; con la rueda o el touchpad, sigue al dedo
            property bool animar: false
            function mover(lado) {
                animar = true
                contentX = Math.max(0, Math.min(contentWidth - width, contentX + lado * width * 0.85))
            }
            Behavior on contentX { enabled: list.animar; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            delegate: MouseArea {
                id: item
                readonly property string appId: modelData.app_id
                readonly property bool installed: !!store.installed[appId.toLowerCase()]
                readonly property var job: store.jobs[appId]
                width: 132; height: list.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.openApp(modelData)
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: item.containsMouse ? win.cardHover : win.cardBg
                    border.color: win.cardBorder
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 64; Layout.preferredHeight: 64
                        Layout.bottomMargin: 6
                        source: modelData.icon || F.iconFor(item.appId)
                        sourceSize: Qt.size(128, 128)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: win.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item { Layout.fillHeight: true }
                    ProgressBar {
                        Layout.fillWidth: true
                        visible: !!item.job
                        from: 0; to: 100
                        value: item.job ? item.job.progress : 0
                        indeterminate: !item.job || item.job.progress === 0
                    }
                    Rectangle {
                        visible: !item.job
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: priceText.implicitWidth + 14
                        implicitHeight: 20
                        radius: 4
                        color: win.dark ? "#3A3A3A" : "#EDEDED"
                        Label { id: priceText; anchors.centerIn: parent; text: item.installed ? "Propia" : "Gratis"; font.pixelSize: 11; color: win.text }
                    }
                }
            }
        }

        // La rueda: de costado (touchpad o Mayús + rueda) recorre la fila; la normal baja la página
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                var dx = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x
                       : (wheel.modifiers & Qt.ShiftModifier) ? wheel.angleDelta.y : 0
                if (dx === 0 || list.contentWidth <= list.width) { wheel.accepted = false; return }
                list.animar = false
                list.contentX = Math.max(0, Math.min(list.contentWidth - list.width, list.contentX - dx))
            }
        }

        // Esqueletos mientras carga
        Row {
            visible: root.loading
            spacing: 8
            Repeater {
                model: 8
                Rectangle {
                    width: 132; height: 150; radius: 8
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
    }
}
