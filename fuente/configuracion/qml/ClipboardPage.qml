import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sistema › Portapapeles (como en Windows 11). En Plasma 6 el portapapeles vive en plasmashell.
ScrollView {
    id: root
    contentWidth: availableWidth
    property var cfg: backend.clipboardSettings()
    function set(key, value) { backend.setClipboardSetting(key, value); cfg = backend.clipboardSettings() }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader { Layout.topMargin: 4; Layout.bottomMargin: 20; parts: win.pathParts }

        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "edit-paste"
            title: "Historial del portapapeles"
            description: "Guarda varios elementos en el portapapeles para usarlos más tarde. Pulsa Meta + V para ver el historial y pegar."
            trailing: Switch { checked: root.cfg.history; onToggled: root.set("history", checked) }
        }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            enabled: root.cfg.history
            opacity: enabled ? 1 : 0.5
            iconName: "view-list-text"
            title: "Elementos que se recuerdan"
            description: "Los más antiguos se descartan al llegar al límite"
            trailing: SpinBox {
                from: 1; to: 2048
                value: root.cfg.size
                editable: true
                onValueModified: root.set("size", value)
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            enabled: root.cfg.history
            opacity: enabled ? 1 : 0.5
            iconName: "image-x-generic"
            title: "Guardar imágenes en el historial"
            description: "Incluye capturas e imágenes copiadas"
            trailing: Switch { checked: root.cfg.images; onToggled: root.set("images", checked) }
        }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "edit-select"
            title: "Sincronizar selección y portapapeles"
            description: "Lo que selecciones con el puntero también se copia"
            trailing: Switch { checked: root.cfg.sync; onToggled: root.set("sync", checked) }
        }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "edit-clear-history"
            title: "Borrar datos del portapapeles"
            description: "Borra todo excepto los elementos anclados"
            trailing: Button {
                id: clearBtn
                text: "Borrar"
                onClicked: { backend.clearClipboard(); text = "✓ Borrado"; reset.restart() }
                Timer { id: reset; interval: 2500; onTriggered: clearBtn.text = "Borrar" }
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
