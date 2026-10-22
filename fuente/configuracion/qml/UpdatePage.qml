import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Actualizaciones (equivalente a Windows Update) usando pacman/checkupdates
ScrollView {
    id: root
    contentWidth: availableWidth

    property bool checking: false
    property bool checked: false
    property bool ok: true
    property var packages: []
    property string checkedAt: ""
    // Aviso discreto cuando hay actualizaciones (coucou-actualizaciones.timer)
    property bool notify: backend.coucouState("avisar-actualizaciones") !== "off"

    function check() { checking = true; backend.checkUpdates() }

    Connections {
        target: backend
        function onUpdatesChecked(ok, packages, checkedAt) {
            root.checking = false; root.checked = true
            root.ok = ok; root.packages = packages; root.checkedAt = checkedAt
        }
    }
    Component.onCompleted: { check(); loadErrors(); if (Qt.application.arguments.indexOf("--al-final") >= 0) toEnd.start() }
    // Prueba (capturas): `win11-settings update --al-final` muestra el final de la página
    Timer { id: toEnd; interval: 2500; onTriggered: root.contentItem.contentY = Math.max(0, root.contentItem.contentHeight - root.height) }
    // Registro de errores: la barra, el instalador y los cierres inesperados (solo se lee, no se envía)
    property var errors: []
    property bool allErrors: false
    property string savedTo: ""
    function loadErrors() { errors = backend.errorLog(); savedTo = "" }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader { Layout.topMargin: 4; Layout.bottomMargin: 20; parts: [{ title: win.brand("Windows Update") }] }

        // Estado principal
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 20
            spacing: 20
            Item {
                width: 72; height: 72
                Image {
                    anchors.fill: parent
                    source: "image://icon/" + (root.checking ? "system-software-update" : (root.packages.length ? "update-high" : "update-none"))
                    sourceSize: Qt.size(72, 72)
                    RotationAnimator on rotation { running: root.checking; from: 0; to: 360; duration: 1600; loops: Animation.Infinite }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    font.pixelSize: 20; font.weight: Font.DemiBold; color: win.text
                    text: root.checking ? "Buscando actualizaciones..."
                        : !backend.canCheckUpdates ? "Falta el paquete pacman-contrib"
                        : !root.ok ? "No se pudieron buscar actualizaciones"
                        : root.packages.length ? "Hay actualizaciones disponibles"
                        : "Estás al día"
                }
                Label {
                    color: win.subtext; font.pixelSize: 13
                    visible: root.checked && !root.checking
                    text: !backend.canCheckUpdates ? "Hace falta para buscar actualizaciones. Después de instalarlo, vuelve a abrir Configuración."
                        : root.packages.length ? root.packages.length + " paquetes listos para instalar" : "Última comprobación: " + root.checkedAt
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
            Button {
                visible: !backend.canCheckUpdates
                text: "Instalar pacman-contrib"
                highlighted: true
                onClicked: backend.runInTerminal("sudo pacman -S --needed pacman-contrib")
            }
            Button {
                visible: root.packages.length > 0 && !root.checking
                text: "Instalar todo"
                highlighted: true
                onClicked: backend.runInTerminal("sudo pacman -Syu")
            }
            Button {
                text: "Buscar actualizaciones"
                enabled: !root.checking
                highlighted: root.packages.length === 0
                onClicked: root.check()
            }
        }

        // Lista de paquetes
        Repeater {
            model: root.packages
            SettingsCard {
                Layout.fillWidth: true
                implicitHeight: 52
                clickable: false
                iconName: "package-x-generic"
                title: modelData.split(" ")[0]
                description: modelData.split(" ").slice(1).join(" ")
            }
        }

        Label { Layout.topMargin: 24; text: "Más opciones"; font.weight: Font.DemiBold; color: win.text }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "preferences-desktop-notification"
            title: "Avisarme cuando haya actualizaciones"
            description: "Una notificación discreta, sin sonido, con cuántos paquetes hay (cada 3 horas, solo si hay nuevos)"
            trailing: Switch {
                checked: root.notify
                onToggled: {
                    root.notify = checked
                    backend.setCoucouState("avisar-actualizaciones", checked ? "on" : "off")
                }
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            iconName: "utilities-terminal"
            title: "Actualizar el sistema en la terminal"
            description: "Ejecuta sudo pacman -Syu y muestra el progreso"
            external: true
            onClicked: backend.runInTerminal("sudo pacman -Syu")
        }
        SettingsCard {
            Layout.fillWidth: true
            iconName: "document-open-recent"
            title: "Historial de actualizaciones"
            description: "Registro de pacman (/var/log/pacman.log)"
            external: true
            onClicked: backend.runInTerminal("grep -E 'upgraded|installed|removed' /var/log/pacman.log | tail -n 200 | less +G")
        }
        Label { Layout.topMargin: 24; text: "Registro de errores"; font.weight: Font.DemiBold; color: win.text }
        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: root.errors.length ? "dialog-warning" : "dialog-ok"
            title: root.errors.length ? (root.errors.length === 1 ? "1 error anotado" : root.errors.length + " errores anotados")
                                      : "Sin errores anotados"
            description: root.savedTo !== "" ? "Guardado en " + root.savedTo
                : "De la barra, del instalador y de los cierres inesperados"
            trailing: [
                Button { text: "Actualizar"; onClicked: root.loadErrors() },
                Button { text: "Copiar"; enabled: root.errors.length > 0; onClicked: { backend.copyErrorReport(); root.savedTo = "" ; copied.restart() } },
                Button { text: "Guardar"; enabled: root.errors.length > 0; onClicked: root.savedTo = backend.saveErrorReport() }
            ]
        }
        Timer { id: copied; interval: 2500 }
        Label {
            visible: copied.running
            text: "Copiado: pégalo en un mensaje o un correo."
            color: win.subtext; font.pixelSize: 12
        }
        Repeater {
            model: root.allErrors ? root.errors : root.errors.slice(0, 6)
            SettingsCard {
                Layout.fillWidth: true
                clickable: false
                iconName: modelData.source === "Cierre inesperado" ? "tools-report-bug"
                        : modelData.source.indexOf("Instalador") === 0 ? "system-software-install" : "dialog-error"
                title: modelData.source + " · " + modelData.when
                // La primera línea (sin la pila de llamadas): todo va al copiar o guardar
                description: modelData.text.split("\n")[0].replace(/^ui  /, "")
            }
        }
        Button {
            visible: root.errors.length > 6
            flat: true
            text: root.allErrors ? "Ver menos" : "Ver los " + root.errors.length
            onClicked: root.allErrors = !root.allErrors
        }
        SettingsCard {
            Layout.fillWidth: true
            iconName: "cpu"
            title: "Actualizaciones de firmware"
            description: "BIOS y dispositivos compatibles (fwupd)"
            external: true
            onClicked: backend.runInTerminal("fwupdmgr refresh; fwupdmgr get-updates")
        }
        Item { Layout.preferredHeight: 24 }
    }
}
