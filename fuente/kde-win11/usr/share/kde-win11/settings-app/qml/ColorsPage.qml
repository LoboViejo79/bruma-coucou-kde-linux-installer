import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "Pages.js" as P

// Personalización > Colores (réplica de la página de Windows 11)
ScrollView {
    id: root
    contentWidth: availableWidth

    // Valores pendientes: se aplican en bloque para no lanzar varios cambios a la vez
    property string mode: backend.mode
    property string accent: backend.accent
    property bool transparency: backend.transparency

    function apply() {
        if (mode !== backend.mode || accent.toUpperCase() !== backend.accent.toUpperCase() || transparency !== backend.transparency)
            backend.setTheme(mode, accent.toUpperCase(), transparency)
    }
    // Pequeño retardo para agrupar clics rápidos
    Timer { id: applyTimer; interval: 350; onTriggered: root.apply() }
    function schedule() { applyTimer.restart() }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 20
            parts: [{ title: "Personalización" }, { title: "Colores" }]
        }

        // Vista previa
        Rectangle {
            Layout.preferredWidth: 360; Layout.preferredHeight: 150
            Layout.bottomMargin: 20
            radius: 8; clip: true; color: "#000"
            Image { anchors.fill: parent; source: backend.wallpaper; sourceSize.width: 720; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Rectangle {
                anchors.centerIn: parent; width: 210; height: 100; radius: 6
                color: root.mode === "dark" ? "#2B2B2B" : "#FFFFFF"
                opacity: root.transparency ? 0.9 : 1
                Behavior on color { ColorAnimation { duration: 250 } }
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8
                    Label { text: "Aa"; font.pixelSize: 18; color: root.mode === "dark" ? "#FFF" : "#1A1A1A" }
                    Rectangle { width: 120; height: 8; radius: 4; color: root.mode === "dark" ? "#444" : "#E0E0E0" }
                    Rectangle { width: 80; height: 24; radius: 4; color: win.accent
                        Label { anchors.centerIn: parent; text: "Botón"; font.pixelSize: 11; color: root.mode === "dark" ? "#000" : "#FFF" } }
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "preferences-desktop-color"
            title: "Elige tu modo"
            description: "Cambia los colores que aparecen en el sistema y en tus aplicaciones"
            trailing: ComboBox {
                Layout.preferredWidth: 160
                model: ["Claro", "Oscuro"]
                currentIndex: root.mode === "dark" ? 1 : 0
                onActivated: function (i) { root.mode = i === 1 ? "dark" : "light"; root.schedule() }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            clickable: false
            iconName: "preferences-desktop-effects"
            title: "Efectos de transparencia"
            description: "Barra de tareas, menú Inicio y paneles del sistema translúcidos con desenfoque; desactivado, todo es sólido"
            trailing: [
                Label { text: sw.checked ? "Activado" : "Desactivado"; color: win.text },
                Switch {
                    id: sw
                    checked: root.transparency
                    onToggled: { root.transparency = checked; root.schedule() }
                }
            ]
        }

        // Color de énfasis (expansor)
        SettingsCard {
            id: accentCard
            Layout.fillWidth: true
            Layout.topMargin: 0
            iconName: "color-management"
            title: "Color de énfasis"
            description: "Barra de tareas, menú Inicio, ajustes rápidos, selecciones y enlaces. Las apps ya abiertas lo toman al volver a abrirlas"
            bottomRadius: expanded ? 0 : 6
            chevron: false
            property bool expanded: true
            onClicked: expanded = !expanded
            trailing: [
                Rectangle { width: 26; height: 26; radius: 4; color: root.accent; border.color: win.cardBorder },
                ComboBox {
                    Layout.preferredWidth: 140
                    model: ["Manual"]
                    enabled: false
                },
                Label {
                    text: "›"; font.pixelSize: 22; color: win.subtext
                    rotation: accentCard.expanded ? -90 : 90
                    Behavior on rotation { NumberAnimation { duration: 150 } }
                }
            ]
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: -5
            visible: accentCard.expanded
            implicitHeight: accentCol.implicitHeight + 36
            color: win.cardBg
            border.color: win.cardBorder
            bottomLeftRadius: 6; bottomRightRadius: 6

            ColumnLayout {
                id: accentCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 18
                anchors.leftMargin: 54
                spacing: 12

                Label { text: "Colores de énfasis del sistema"; color: win.text }

                Grid {
                    columns: 8
                    spacing: 4
                    Repeater {
                        model: P.accents
                        delegate: Rectangle {
                            id: swatch
                            readonly property bool current: root.accent.toUpperCase() === modelData
                            width: 44; height: 44; radius: 4
                            color: modelData
                            border.width: current ? 2 : 0
                            border.color: win.text
                            scale: sm.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: 80 } }
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 2; radius: 3
                                color: "transparent"
                                border.width: swatch.current ? 2 : (sm.containsMouse ? 2 : 0)
                                border.color: swatch.current ? win.bg : Qt.rgba(1, 1, 1, 0.5)
                            }
                            // Marca de selección (esquina superior derecha, como Windows)
                            Rectangle {
                                visible: swatch.current
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                                width: 16; height: 16; radius: 8
                                color: win.text
                                Label { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; color: win.bg }
                            }
                            MouseArea {
                                id: sm
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { root.accent = modelData; root.schedule() }
                            }
                            ToolTip.visible: sm.containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Label { text: "Color personalizado"; color: win.text; Layout.fillWidth: true }
                    Button {
                        text: "Ver colores"
                        onClicked: colorDialog.open()
                    }
                }
            }
        }

        RowLayout {
            Layout.topMargin: 16
            visible: backend.busy
            spacing: 10
            BusyIndicator { running: backend.busy; Layout.preferredWidth: 22; Layout.preferredHeight: 22 }
            Label { text: "Aplicando..."; color: win.subtext }
        }

        Label {
            Layout.topMargin: 24
            text: "Configuración relacionada"
            font.weight: Font.DemiBold
            color: win.text
        }
        SettingsCard {
            Layout.fillWidth: true
            iconName: "preferences-desktop-color"
            title: "Esquemas de color de KDE"
            description: "Opciones avanzadas de color"
            external: true
            onClicked: backend.openKcm("kcm_colors")
        }
        SettingsCard {
            Layout.fillWidth: true
            iconName: "preferences-desktop-effects"
            title: "Efectos visuales"
            description: "Animaciones y efectos de ventanas"
            external: true
            onClicked: backend.openKcm("kcm_kwin_effects")
        }

        Item { Layout.preferredHeight: 24 }
    }

    ColorDialog {
        id: colorDialog
        title: "Elige un color de énfasis personalizado"
        selectedColor: root.accent
        onAccepted: {
            root.accent = selectedColor.toString().toUpperCase().slice(0, 7)
            root.schedule()
        }
    }
}
