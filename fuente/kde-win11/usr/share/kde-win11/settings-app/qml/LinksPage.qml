import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Pages.js" as P

// Página genérica: título + tarjetas que abren módulos de KDE o subpáginas.
// `header` permite insertar contenido propio (tarjeta de equipo, vista previa...).
ScrollView {
    id: root
    property var category
    property alias header: headerSlot.data
    contentWidth: availableWidth

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 20
            parts: win.pathParts
        }

        ColumnLayout { id: headerSlot; Layout.fillWidth: true; spacing: 4 }

        Repeater {
            model: P.visibleItems(root.category.items, backend.kcms)
            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    visible: !!modelData.section
                    Layout.topMargin: index > 0 ? 18 : 0
                    Layout.bottomMargin: 6
                    text: modelData.section || ""
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: win.text
                }
                SettingsCard {
                    visible: !modelData.section
                    Layout.fillWidth: true
                    title: modelData.title || ""
                    description: (modelData.desc || "").replace("%HOST%", backend.sysInfo.hostname)
                    iconName: modelData.icon || ""
                    glyph: modelData.section ? "" : P.glyphFor(modelData)
                    external: !modelData.page && !modelData.items && !(modelData.kcm && backend.canEmbed(modelData.kcm))
                    onClicked: win.activate(modelData)
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
