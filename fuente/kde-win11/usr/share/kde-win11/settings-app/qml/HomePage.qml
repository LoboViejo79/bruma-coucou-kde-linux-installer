import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Inicio de Configuración (Windows 11 23H2+): equipo arriba y tarjetas con lo más usado
ScrollView {
    id: root
    contentWidth: availableWidth

    component HomeCard: Rectangle {
        id: hc
        property string title
        property string subtitle
        default property alias content: body.data
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        implicitHeight: col.implicitHeight + 40
        radius: 6
        color: win.cardBg
        border.color: win.cardBorder
        ColumnLayout {
            id: col
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 20
            spacing: 4
            Label { text: hc.title; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text }
            Label { visible: text !== ""; text: hc.subtitle; font.pixelSize: 12; color: win.subtext; Layout.fillWidth: true; wrapMode: Text.Wrap }
            ColumnLayout { id: body; Layout.fillWidth: true; Layout.topMargin: 10; spacing: 2 }
        }
    }
    // Fila dentro de una tarjeta: icono de línea, texto y flecha
    component HomeRow: MouseArea {
        id: hr
        property string glyph
        property string text
        property string detail
        property bool chevron: true
        Layout.fillWidth: true
        implicitHeight: 48
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle { anchors.fill: parent; radius: 4; color: hr.containsMouse ? win.cardHover : "transparent" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            spacing: 14
            FluentIcon { name: hr.glyph; size: 18 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { text: hr.text; color: win.text; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { visible: hr.detail !== ""; text: hr.detail; color: win.subtext; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            FluentIcon { visible: hr.chevron; name: "next"; size: 11; stroke: 1.8 }
        }
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 16

        Label { Layout.topMargin: 4; text: "Inicio"; font.pixelSize: 28; font.weight: Font.DemiBold; color: win.text }

        // Equipo
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 16
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 68
                Rectangle { anchors.fill: parent; radius: 4; color: "#000000" }
                Image { anchors.fill: parent; source: backend.wallpaper; sourceSize.width: 240; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }
            ColumnLayout {
                spacing: 1
                Label { text: backend.hostname; font.pixelSize: 18; font.weight: Font.DemiBold; color: win.text }
                Label { text: backend.sysInfo.os; color: win.text; opacity: 0.9; font.pixelSize: 13 }
                Label {
                    text: "Cambiar nombre"; color: win.accent; font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openCategory("system") }
                }
            }
            Item { Layout.fillWidth: true }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width > 820 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            HomeCard {
                title: "Configuración recomendada"
                subtitle: "Los ajustes que más se usan"
                HomeRow { glyph: "display"; text: "Pantalla"; detail: "Resolución, escala, luz nocturna"; onClicked: win.openPath("system", ["Pantalla"]) }
                HomeRow { glyph: "sound"; text: "Sonido"; detail: "Volumen y dispositivos"; onClicked: win.openPath("system", ["Sonido", "Dispositivos y volumen"]) }
                HomeRow { glyph: "wifi"; text: "Red e Internet"; detail: "Wi-Fi, Ethernet, VPN"; onClicked: win.openPath("network", ["Wi-Fi y Ethernet"]) }
                HomeRow { glyph: "power"; text: "Energía"; detail: "Suspensión y apagado de pantalla"; onClicked: win.openPath("system", ["Energía y batería", "Energía"]) }
            }

            HomeCard {
                title: "Personaliza tu dispositivo"
                subtitle: "Fondo, colores y modo oscuro"
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    Rectangle { anchors.fill: parent; radius: 6; color: "#000" }
                    Image { anchors.fill: parent; source: backend.wallpaper; sourceSize.width: 600; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openPath("personalization", ["Fondo"]) }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    FluentIcon { name: "moon"; size: 18; Layout.leftMargin: 10 }
                    Label { text: "Modo oscuro"; color: win.text; Layout.fillWidth: true; Layout.leftMargin: 8 }
                    Switch {
                        checked: win.dark
                        enabled: !backend.busy
                        onToggled: backend.setTheme(checked ? "dark" : "light", backend.accent, backend.transparency)
                    }
                }
                HomeRow { glyph: "palette"; text: "Colores"; detail: "Color de énfasis y transparencia"; onClicked: win.openPath("personalization", ["Colores"]) }
            }

            HomeCard {
                title: "Bluetooth y dispositivos"
                subtitle: backend.hasHardware("bluetooth") ? "Administra tus dispositivos" : "Este equipo no tiene Bluetooth"
                HomeRow { glyph: "bluetooth"; text: "Bluetooth"; detail: backend.hasHardware("bluetooth") ? "Agregar y conectar dispositivos" : "No se encontró ningún adaptador"; onClicked: win.openPath("devices", ["Bluetooth"]) }
                HomeRow { glyph: "mouse"; text: "Mouse"; onClicked: win.openPath("devices", ["Mouse"]) }
                HomeRow { glyph: "printer"; text: "Impresoras"; onClicked: win.openPath("devices", ["Impresoras"]) }
            }

            HomeCard {
                title: "Windows Update"
                subtitle: backend.lastUpdateCheck ? "Última comprobación: hoy a las " + backend.lastUpdateCheck : "Mantén el sistema al día"
                HomeRow { glyph: "update"; text: "Buscar actualizaciones"; detail: "Sistema y aplicaciones"; onClicked: win.openCategory("update") }
                HomeRow { glyph: "start"; text: "Microsoft Store"; detail: "Actualizar aplicaciones de la tienda"; chevron: false; onClicked: backend.launch("win11-store", ["updates"]) }
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
