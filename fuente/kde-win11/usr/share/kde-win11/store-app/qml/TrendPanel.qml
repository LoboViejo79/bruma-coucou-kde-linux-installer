import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Panel "Tendencias de juegos ›" de la Microsoft Store: tarjeta con cabecera, flechas de página
// y una cuadrícula de 2 columnas con icono grande, nombre, categoría y etiqueta de precio.
Rectangle {
    id: root
    property string title
    property var fetch: null          // fetch(page, perPage, cb)
    property var apps: []
    property int page: 0
    readonly property int perPage: 6
    readonly property int pages: Math.max(1, Math.ceil(apps.length / perPage))
    readonly property var shown: apps.slice(page * perPage, page * perPage + perPage)
    signal seeAll()

    implicitHeight: col.implicitHeight + 32
    radius: 8
    color: win.panelBg
    border.color: win.cardBorder

    Component.onCompleted: if (fetch) fetch(1, 24, function (a) { if (root) root.apps = a })

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 8
            Layout.topMargin: 14
            Layout.bottomMargin: 18
            MouseArea {
                implicitWidth: titleRow.implicitWidth
                implicitHeight: titleRow.implicitHeight
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.seeAll()
                RowLayout {
                    id: titleRow
                    spacing: 10
                    Label { text: root.title; font.pixelSize: 20; font.weight: Font.DemiBold; color: win.text }
                    FluentIcon { name: "next"; size: 14; stroke: 2.2; color: win.text }
                }
            }
            Item { Layout.fillWidth: true }
            component PageArrow: RoundButton {
                property string glyph
                implicitWidth: 28; implicitHeight: 28
                flat: true
                contentItem: Item { FluentIcon { anchors.centerIn: parent; name: parent.parent.glyph; size: 10; stroke: 2.6; color: win.text } }
            }
            PageArrow { glyph: "prev"; enabled: root.page > 0; opacity: enabled ? 1 : 0.35; onClicked: root.page-- }
            PageArrow { glyph: "next"; enabled: root.page < root.pages - 1; opacity: enabled ? 1 : 0.35; onClicked: root.page++ }
        }
        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; implicitHeight: 1; color: win.cardBorder }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            columns: 2
            columnSpacing: 8
            rowSpacing: 4
            Repeater {
                model: root.shown
                delegate: MouseArea {
                    id: item
                    readonly property string appId: modelData.app_id
                    readonly property bool installed: !!store.installed[appId.toLowerCase()]
                    readonly property var job: store.jobs[appId]
                    Layout.fillWidth: true
                    Layout.preferredHeight: 116
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.openApp(modelData)
                    Rectangle { anchors.fill: parent; radius: 6; color: item.containsMouse ? win.cardHover : "transparent" }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 16
                        Item {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 80
                            Layout.alignment: Qt.AlignTop
                            Image {
                                id: ic
                                anchors.fill: parent
                                source: modelData.icon || F.iconFor(item.appId)
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4
                            Label { Layout.fillWidth: true; text: modelData.name; color: win.text; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Label { Layout.fillWidth: true; text: F.categoryName(modelData.main_categories); color: win.subtext; font.pixelSize: 13; elide: Text.ElideRight }
                            Item { Layout.fillHeight: true }
                            RowLayout {
                                Layout.fillWidth: true
                                ProgressBar {
                                    Layout.fillWidth: true
                                    visible: !!item.job
                                    from: 0; to: 100
                                    value: item.job ? item.job.progress : 0
                                    indeterminate: !item.job || item.job.progress === 0
                                }
                                Item { Layout.fillWidth: true; visible: !item.job }
                                // Etiqueta como "Gratis" / "Propia" de la Store
                                Rectangle {
                                    visible: !item.job
                                    implicitWidth: priceText.implicitWidth + 16
                                    implicitHeight: 22
                                    radius: 4
                                    color: win.dark ? "#3A3A3A" : "#EDEDED"
                                    Label {
                                        id: priceText
                                        anchors.centerIn: parent
                                        text: item.installed ? "Propia" : "Gratis"
                                        font.pixelSize: 12
                                        color: win.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Esqueletos mientras carga
            Repeater {
                model: root.apps.length ? 0 : 6
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 116
                    radius: 6
                    color: "transparent"
                    Rectangle { x: 12; y: 12; width: 80; height: 80; radius: 6; color: win.dark ? "#333" : "#E8E8E8" }
                    Rectangle { x: 108; y: 16; width: 140; height: 12; radius: 3; color: win.dark ? "#333" : "#E8E8E8" }
                    Rectangle { x: 108; y: 38; width: 90; height: 10; radius: 3; color: win.dark ? "#2E2E2E" : "#EEE" }
                }
            }
        }
    }
}
