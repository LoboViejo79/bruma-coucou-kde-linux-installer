import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Personalización: vista previa del escritorio + temas rápidos (claro/oscuro) + enlaces
LinksPage {
    id: root

    header: [
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 20
            spacing: 24

            // Vista previa: fondo + ventana de ejemplo con el modo y el énfasis actuales
            Rectangle {
                Layout.preferredWidth: 320; Layout.preferredHeight: 190
                radius: 8
                clip: true
                color: "#000"
                Image {
                    anchors.fill: parent
                    source: backend.wallpaper
                    sourceSize.width: 640
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {
                    x: 60; y: 36; width: 200; height: 112
                    radius: 6
                    color: win.dark ? "#2B2B2B" : "#FFFFFF"
                    opacity: backend.transparency ? 0.92 : 1
                    Column {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        Rectangle { width: 90; height: 8; radius: 4; color: win.dark ? "#555" : "#CCC" }
                        Rectangle { width: 140; height: 8; radius: 4; color: win.dark ? "#444" : "#E0E0E0" }
                        Rectangle { width: 110; height: 8; radius: 4; color: win.dark ? "#444" : "#E0E0E0" }
                        Rectangle { width: 70; height: 22; radius: 4; color: win.accent }
                    }
                }
                // Barra de tareas en miniatura
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 18
                    color: win.dark ? "#1C1C1C" : "#EEEEEE"
                    opacity: backend.transparency ? 0.85 : 1
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Repeater { model: 5; Rectangle { width: 10; height: 10; radius: 2; color: index === 0 ? win.accent : (win.dark ? "#666" : "#AAA") } }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Selecciona un tema para aplicar"; color: win.text }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: [
                            { name: "Claro", mode: "light", accent: "#0078D4" },
                            { name: "Oscuro", mode: "dark", accent: "#0078D4" },
                            { name: "Brillo", mode: "light", accent: "#8764B8" },
                            { name: "Captura", mode: "dark", accent: "#E81123" },
                            { name: "Flujo", mode: "light", accent: "#00B294" },
                            { name: "Amanecer", mode: "dark", accent: "#FF8C00" }
                        ]
                        delegate: Rectangle {
                            width: 112; height: 72; radius: 6
                            color: modelData.mode === "dark" ? "#202020" : "#F3F3F3"
                            border.width: backend.mode === modelData.mode && backend.accent === modelData.accent ? 2 : 1
                            border.color: border.width === 2 ? win.accent : win.cardBorder
                            Rectangle {
                                x: 12; y: 12; width: 56; height: 34; radius: 4
                                color: modelData.mode === "dark" ? "#2B2B2B" : "#FFFFFF"
                                Rectangle { x: 8; y: 20; width: 24; height: 8; radius: 2; color: modelData.accent }
                            }
                            Label {
                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6
                                text: modelData.name; font.pixelSize: 11
                                color: modelData.mode === "dark" ? "#FFF" : "#1A1A1A"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.setAppearance(modelData.mode, modelData.accent, backend.transparency)
                            }
                        }
                    }
                }
            }
        }
    ]
}
