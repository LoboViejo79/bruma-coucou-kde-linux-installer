import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: page
    clip: true
    contentHeight: col.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    component Card: Rectangle {
        default property alias content: inner.data
        property string title
        property string description
        Layout.fillWidth: true
        implicitHeight: Math.max(68, inner.implicitHeight + 24)
        radius: 6
        color: win.dark ? "#2B2B2B" : "#FFFFFF"
        border.color: win.dark ? "#1D1D1D" : "#E5E5E5"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: parent.parent.parent.title; color: win.text }
                Label {
                    visible: text !== ""
                    text: parent.parent.parent.description
                    color: win.subtext
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout { id: inner }
        }
    }

    ColumnLayout {
        id: col
        x: 24
        width: page.width - 48
        spacing: 4

        Label {
            Layout.topMargin: 14
            Layout.bottomMargin: 12
            text: "Configuración"
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: win.text
        }

        Card {
            title: "Página de inicio predeterminada"
            description: "La página que se abre al iniciar el Administrador de tareas"
            ComboBox {
                Layout.preferredWidth: 240
                model: win.pages.map(function (p) { return p.title })
                currentIndex: Math.max(0, win.pages.findIndex(function (p) { return p.id === prefs.startPage }))
                onActivated: function (i) { prefs.startPage = win.pages[i].id }
            }
        }
        Card {
            title: "Velocidad de actualización en tiempo real"
            description: "Cada cuánto se actualizan los datos"
            ComboBox {
                id: speedBox
                Layout.preferredWidth: 240
                readonly property var values: [500, 1000, 4000, 0]
                model: ["Alta (cada 0,5 s)", "Normal (cada 1 s)", "Baja (cada 4 s)", "En pausa"]
                currentIndex: Math.max(0, values.indexOf(prefs.speed))
                onActivated: function (i) { prefs.speed = values[i]; win.applySpeed() }
            }
        }
        Card {
            title: "Siempre visible"
            description: "El Administrador de tareas queda encima de las demás ventanas"
            Switch {
                checked: prefs.alwaysOnTop
                text: checked ? "Activado" : "Desactivado"
                LayoutMirroring.enabled: true
                onToggled: prefs.alwaysOnTop = checked
            }
        }
        Card {
            title: "Acerca de"
            description: "Administrador de tareas estilo Windows 11 para KDE Plasma. Atajo: Ctrl+Mayús+Esc"
        }
    }
}
