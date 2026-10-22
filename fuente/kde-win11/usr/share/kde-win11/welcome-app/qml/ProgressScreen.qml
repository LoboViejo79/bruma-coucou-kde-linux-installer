import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pantalla "Esto puede tardar unos minutos" de la instalación de Windows 11: fondo liso,
// anillo de progreso y texto centrados. Al terminar muestra el resultado y, si falla, opciones.
Rectangle {
    id: root
    property string heading: "Esto puede tardar unos minutos"
    property var actions: []
    property bool autoClose: true       // al acabar bien, cerrar y seguir (si no, mostrar "Listo")
    property bool done: false
    property bool ok: false
    signal closed(bool ok)

    color: win.dark ? "#0E1B30" : "#E4EDF8"
    visible: false
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    function start(title, list, close) {
        heading = title
        actions = list
        autoClose = close
        done = false
        ok = false
        details.checked = false
        visible = true
        backend.runAdmin(list)
    }
    function finish(result) {
        visible = false
        closed(result)
    }

    Connections {
        target: backend
        function onFinished(success) {
            if (!root.visible) return
            root.done = true
            root.ok = success
            if (success && root.autoClose) closeTimer.start()
        }
    }
    Timer { id: closeTimer; interval: 700; onTriggered: root.finish(true) }

    MouseArea { anchors.fill: parent; hoverEnabled: true }   // bloquea lo de debajo

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 640)
        spacing: 18

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            visible: !root.done
            running: visible
        }
        FluentIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.done
            name: root.ok ? "activation" : "info"
            size: 64
            stroke: 1.2
            color: root.ok ? win.accentText : "#E0A000"
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.done ? (root.ok ? "Todo listo" : backend.status) : root.heading
            color: win.text
            font.pixelSize: 28
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.done
                ? (root.ok ? "Se aplicaron los cambios." : "Puedes intentarlo de nuevo, hacerlo en una terminal para ver qué ocurre, u omitir este paso.")
                : (backend.status || "No apagues el equipo.")
            color: win.subtext
            font.pixelSize: 15
        }

        // Detalles (salida de pacman)
        Button {
            id: details
            Layout.alignment: Qt.AlignHCenter
            checkable: true
            flat: true
            text: checked ? "Ocultar detalles" : "Ver detalles"
            visible: backend.output !== ""
        }
        ScrollView {
            id: logView
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            visible: details.checked
            background: Rectangle { radius: 6; color: win.cardBg; border.color: win.cardBorder }
            TextArea {
                readOnly: true
                text: backend.output
                font.family: "monospace"
                font.pixelSize: 12
                color: win.text
                wrapMode: Text.WrapAnywhere
                background: null
                onTextChanged: cursorPosition = length
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.done && (!root.ok || !root.autoClose)
            spacing: 8
            Button {
                visible: !root.ok
                text: "Omitir"
                onClicked: root.finish(false)
            }
            Button {
                visible: !root.ok
                text: "Abrir en terminal"
                onClicked: { backend.runAdminInTerminal(root.actions); root.finish(false) }
            }
            Button {
                text: root.ok ? "Aceptar" : "Reintentar"
                highlighted: true
                Layout.preferredWidth: 120
                onClicked: root.ok ? root.finish(true) : root.start(root.heading, root.actions, root.autoClose)
            }
        }
    }
}
