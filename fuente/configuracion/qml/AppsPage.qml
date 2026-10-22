import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Aplicaciones > Aplicaciones instaladas
ScrollView {
    id: root
    contentWidth: availableWidth

    property var apps: []
    property string filter: ""
    property int sortMode: 0
    readonly property var shown: {
        var f = filter.toLowerCase()
        var list = apps.filter(function (a) { return !f || a.name.toLowerCase().indexOf(f) >= 0 || (a.package || "").indexOf(f) >= 0 })
        if (sortMode === 1) list = list.slice().reverse()
        return list
    }

    Component.onCompleted: backend.loadInstalledApps()
    Connections {
        target: backend
        function onInstalledAppsLoaded(list) { root.apps = list }
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader { Layout.topMargin: 4; Layout.bottomMargin: 20; parts: [{ title: "Aplicaciones" }, { title: "Aplicaciones instaladas" }] }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 12
            TextField {
                Layout.preferredWidth: 320
                placeholderText: "Buscar aplicaciones"
                onTextChanged: root.filter = text
            }
            Item { Layout.fillWidth: true }
            Label { text: "Ordenar por:"; color: win.subtext }
            ComboBox {
                Layout.preferredWidth: 150
                model: ["Nombre (A-Z)", "Nombre (Z-A)"]
                onActivated: function (i) { root.sortMode = i }
            }
        }

        Label {
            text: root.apps.length ? root.shown.length + " aplicaciones encontradas" : "Cargando aplicaciones..."
            color: win.subtext; font.pixelSize: 12
            Layout.bottomMargin: 6
        }

        Repeater {
            model: root.shown
            SettingsCard {
                Layout.fillWidth: true
                clickable: false
                chevron: false
                iconName: modelData.icon || "application-x-executable"
                title: modelData.name
                description: modelData.package ? modelData.package + "  ·  " + modelData.version : (modelData.comment || "Instalada por el usuario")
                trailing: ToolButton {
                    text: "…"
                    font.pixelSize: 18
                    onClicked: menu.popup()
                    Menu {
                        id: menu
                        MenuItem {
                            text: "Abrir"
                            onTriggered: backend.launch("gtk-launch", [modelData.path.split("/").pop().replace(".desktop", "")])
                        }
                        MenuItem {
                            text: "Desinstalar"
                            enabled: modelData.package !== ""
                            onTriggered: { confirm.app = modelData; confirm.open() }
                        }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: 24 }
    }

    Dialog {
        id: confirm
        property var app: ({})
        anchors.centerIn: Overlay.overlay
        modal: true
        title: "Desinstalar " + (app.name || "")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label {
            text: "Se desinstalará el paquete «" + (confirm.app.package || "") + "» y sus dependencias que ya no se usen.\nSe abrirá una terminal para pedir tu contraseña."
            wrapMode: Text.WordWrap
            width: 380
        }
        onAccepted: backend.uninstall(app.package)
    }
}
