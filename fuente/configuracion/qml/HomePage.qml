import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Inicio de Configuración: una bienvenida con el fondo de pantalla, el estado del equipo en
// tarjetas (almacenamiento, memoria, batería, actualizaciones) y accesos de colores a lo que
// más se usa, como la portada de Configuración de Windows 11.
ScrollView {
    id: root
    contentWidth: availableWidth

    property var bat: backend.battery()
    property int updates: backend.pendingUpdates()
    Timer {
        interval: 30000; repeat: true; running: root.visible
        onTriggered: { root.bat = backend.battery(); root.updates = backend.pendingUpdates() }
    }

    readonly property string firstName: (backend.sysInfo.fullName || backend.sysInfo.user || "").split(" ")[0]
    readonly property string greeting: {
        var h = new Date().getHours()
        return h < 12 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches"
    }

    // Tarjeta de estado: icono de color, título, valor y una barra opcional
    component StatusTile: Rectangle {
        id: st
        property string glyph
        property color tint
        property string title
        property string value
        property string detail
        property real ratio: -1
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: 12
        color: mouse.containsMouse ? win.cardHover : win.cardBg
        border.color: win.cardBorder
        Behavior on color { ColorAnimation { duration: 100 } }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6
            RowLayout {
                spacing: 10
                Rectangle {
                    width: 32; height: 32; radius: 9; color: st.tint
                    FluentIcon { anchors.centerIn: parent; name: st.glyph; size: 17; color: "#FFFFFF"; stroke: 1.7 }
                }
                Label { text: st.title; color: win.subtext; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Label { text: st.value; color: win.text; font.pixelSize: 19; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Item {
                Layout.fillWidth: true
                implicitHeight: 6
                visible: st.ratio >= 0
                Rectangle { anchors.fill: parent; radius: 3; color: win.dark ? "#33FFFFFF" : "#1A000000" }
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, st.ratio)); height: parent.height; radius: 3
                    color: st.ratio > 0.9 ? "#E5484D" : st.tint
                }
            }
            Label { visible: st.detail !== "" && st.ratio < 0; text: st.detail; color: win.subtext; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: st.clicked() }
    }

    // Acceso rápido: un cuadrado de color con su icono y el nombre debajo
    component QuickTile: MouseArea {
        id: qt
        property string glyph
        property color tint
        property string text
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent; radius: 12
            color: qt.containsMouse ? win.cardHover : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 46; height: 46; radius: 13
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(qt.tint, 1.18) }
                    GradientStop { position: 1; color: qt.tint }
                }
                scale: qt.pressed ? 0.94 : (qt.containsMouse ? 1.06 : 1)
                Behavior on scale { NumberAnimation { duration: 120 } }
                FluentIcon { anchors.centerIn: parent; name: qt.glyph; size: 22; color: "#FFFFFF"; stroke: 1.7 }
            }
            Label { Layout.alignment: Qt.AlignHCenter; text: qt.text; color: win.text; font.pixelSize: 12 }
        }
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 18

        // ── Bienvenida, sobre el fondo de pantalla ─────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.preferredHeight: 196
            radius: 16
            clip: true
            color: "#1E1B48"
            Image {
                anchors.fill: parent
                source: backend.wallpaper
                sourceSize.width: 1200
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            // Un velo para que se lea el texto sobre cualquier fondo
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#D90E0B2A" }
                    GradientStop { position: 0.55; color: "#8C1E1B48" }
                    GradientStop { position: 1; color: "#141E1B48" }
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 18
                // Foto de la cuenta, o su inicial
                Rectangle {
                    width: 76; height: 76; radius: 38
                    color: win.accent
                    border.width: 3; border.color: "#59FFFFFF"
                    clip: true
                    Label {
                        anchors.centerIn: parent
                        visible: !backend.sysInfo.avatar
                        text: root.firstName.slice(0, 1).toUpperCase()
                        color: "#FFFFFF"; font.pixelSize: 32; font.weight: Font.DemiBold
                    }
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        visible: !!backend.sysInfo.avatar
                        source: backend.sysInfo.avatar ? "image://avatar/" + encodeURIComponent(backend.sysInfo.avatar) : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label { text: root.greeting + (root.firstName ? ", " + root.firstName : ""); color: "#FFFFFF"; font.pixelSize: 26; font.weight: Font.DemiBold }
                    Label {
                        text: backend.hostname + (backend.sysInfo.model ? " · " + backend.sysInfo.model : "")
                        color: "#E6FFFFFF"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Label { text: backend.sysInfo.os; color: "#B3FFFFFF"; font.pixelSize: 12 }
                    RowLayout {
                        Layout.topMargin: 10
                        spacing: 8
                        Button {
                            text: "Cambiar el fondo"
                            onClicked: win.openCategory("coucou")
                        }
                        Button {
                            text: "Cambiar nombre"
                            flat: true
                            palette.buttonText: "#FFFFFF"
                            onClicked: win.openCategory("system")
                        }
                    }
                }
                // Modo oscuro, a mano
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: darkRow.implicitWidth + 24
                    implicitHeight: 40
                    radius: 20
                    color: "#33FFFFFF"
                    border.color: "#4DFFFFFF"
                    RowLayout {
                        id: darkRow
                        anchors.centerIn: parent
                        spacing: 8
                        FluentIcon { name: "moon"; size: 16; color: "#FFFFFF" }
                        Label { text: "Modo oscuro"; color: "#FFFFFF"; font.pixelSize: 12 }
                        Switch {
                            checked: win.dark
                            enabled: !backend.busy
                            onToggled: win.setAppearance(checked ? "dark" : "light", backend.accent, backend.transparency)
                        }
                    }
                }
            }
        }

        // ── Estado del equipo ───────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: width > 760 ? 4 : 2
            columnSpacing: 12
            rowSpacing: 12
            StatusTile {
                glyph: "storage"; tint: "#3B82F6"; title: "Disco de " + backend.sysInfo.diskSize
                value: backend.sysInfo.diskUsed + " usados"
                ratio: backend.sysInfo.diskRatio
                onClicked: win.openPath("system", ["Almacenamiento"])
            }
            StatusTile {
                glyph: "memory"; tint: "#8B5CF6"; title: "Memoria"
                value: backend.sysInfo.ram
                detail: (backend.sysInfo.cpu || "").replace(/\(R\)|\(TM\)/g, "").replace(/ with .*/, "")
                onClicked: win.openPath("system", ["Acerca de"])
            }
            StatusTile {
                glyph: "battery"; tint: "#10B981"; title: "Batería"
                value: root.bat.present ? root.bat.percent + " %" : "Enchufado"
                detail: root.bat.present ? (root.bat.charging ? "Cargando" : "Con batería") : "Sin batería"
                ratio: root.bat.present ? root.bat.percent / 100 : -1
                onClicked: win.openPath("system", ["Energía y batería"])
            }
            StatusTile {
                glyph: "update"; tint: root.updates > 0 ? "#F59E0B" : "#14B8A6"; title: "Actualizaciones"
                value: root.updates > 0 ? root.updates + (root.updates === 1 ? " pendiente" : " pendientes") : root.updates === 0 ? "Al día" : "Revisar"
                detail: root.updates > 0 ? "Instálalas cuando quieras" : "El sistema está actualizado"
                onClicked: win.openCategory("update")
            }
        }

        // ── Accesos rápidos ─────────────────────────────────────────────────
        Label { text: "Accesos rápidos"; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text; Layout.topMargin: 4 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: quick.implicitHeight + 16
            radius: 14
            color: win.cardBg
            border.color: win.cardBorder
            GridLayout {
                id: quick
                anchors.fill: parent
                anchors.margins: 8
                columns: width > 760 ? 6 : 4
                columnSpacing: 4
                rowSpacing: 4
                QuickTile { glyph: "display"; tint: "#0EA5E9"; text: "Pantalla"; onClicked: win.openPath("system", ["Pantalla"]) }
                QuickTile { glyph: "sound"; tint: "#6366F1"; text: "Sonido"; onClicked: win.openPath("system", ["Sonido", "Dispositivos y volumen"]) }
                QuickTile { glyph: "wifi"; tint: "#10B981"; text: "Wi-Fi"; onClicked: win.openPath("network", ["Wi-Fi y Ethernet"]) }
                QuickTile { glyph: "bluetooth"; tint: "#2563EB"; text: "Bluetooth"; onClicked: win.openPath("devices", ["Bluetooth"]) }
                QuickTile { glyph: "power"; tint: "#F59E0B"; text: "Energía"; onClicked: win.openPath("system", ["Energía y batería", "Energía"]) }
                QuickTile { glyph: "bell"; tint: "#EF4444"; text: "Notificaciones"; onClicked: win.openPath("system", ["Notificaciones"]) }
                QuickTile { glyph: "image"; tint: "#EC4899"; text: "Fondo"; onClicked: win.openCategory("coucou") }
                QuickTile { glyph: "palette"; tint: "#A855F7"; text: "Colores"; onClicked: win.openPath("personalization", ["Colores"]) }
                QuickTile { glyph: "folder"; tint: "#F97316"; text: "Iconos"; onClicked: win.openPath("personalization", ["Iconos"]) }
                QuickTile { glyph: "taskbar"; tint: "#6574F6"; text: "Barra de tareas"; onClicked: win.openPath("personalization", ["Barra de tareas"]) }
                QuickTile { glyph: "apps"; tint: "#14B8A6"; text: "Aplicaciones"; onClicked: win.openPath("apps", ["Aplicaciones instaladas"]) }
                QuickTile { glyph: "update"; tint: "#22C55E"; text: "Actualizar"; onClicked: win.openCategory("update") }
            }
        }

        // ── Lo de siempre ───────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: width > 760 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 12
            SettingsCard {
                Layout.fillWidth: true
                glyph: "mouse"
                title: "Mouse y panel táctil"
                description: "Velocidad del puntero, desplazamiento y gestos"
                onClicked: win.openPath("devices", ["Mouse"])
            }
            SettingsCard {
                Layout.fillWidth: true
                glyph: "printer"
                title: "Impresoras"
                description: "Agregar y administrar impresoras"
                onClicked: win.openPath("devices", ["Impresoras"])
            }
            SettingsCard {
                Layout.fillWidth: true
                glyph: "user"
                title: "Tu cuenta"
                description: "Foto, nombre y contraseña"
                onClicked: win.openCategory("accounts")
            }
            SettingsCard {
                Layout.fillWidth: true
                glyph: "start"
                title: win.brand("Microsoft Store")
                description: "Aplicaciones y juegos para tu equipo"
                external: true
                onClicked: backend.launch("win11-store", [])
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
