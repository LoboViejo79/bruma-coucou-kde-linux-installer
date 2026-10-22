/* Lista de pasos al estilo del programa de instalación de Windows 11:
   columna clara a la izquierda, paso actual resaltado y pasos hechos con ✓ */

import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick 2.15
import QtQuick.Layouts 1.3

Rectangle {
    id: sideBar
    color: Branding.styleString(Branding.SidebarBackground)
    implicitWidth: 240
    width: 240
    height: parent ? parent.height : 680

    readonly property color accent: "#0067c0"

    // borde derecho fino
    Rectangle {
        anchors.right: parent.right
        width: 1; height: parent.height
        color: "#e0e5ec"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 28
        spacing: 0

        RowLayout {
            spacing: 10
            Image {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: Branding.string(Branding.ProductName)
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "#1b1b1b"
                }
                Text {
                    text: qsTr("Instalación")
                    font.pixelSize: 12
                    color: "#5f6368"
                }
            }
        }

        Item { Layout.preferredHeight: 28 }

        Repeater {
            model: ViewManager
            delegate: Item {
                id: step
                readonly property bool current: index == ViewManager.currentStepIndex
                readonly property bool done: index < ViewManager.currentStepIndex
                readonly property bool last: index == ViewManager.rowCount() - 1
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                // línea que une los pasos
                Rectangle {
                    visible: !step.last
                    x: 21; y: 30
                    width: 2; height: 20
                    color: step.done ? sideBar.accent : "#c9d3e0"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: step.current ? Branding.styleString(Branding.SidebarBackgroundCurrent) : "transparent"

                    // marca azul del elemento activo, como en la Configuración de Windows 11
                    Rectangle {
                        visible: step.current
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 16; radius: 2
                        color: sideBar.accent
                    }
                }

                Rectangle {
                    id: dot
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 10
                    color: step.done || step.current ? sideBar.accent : "transparent"
                    border.width: step.done || step.current ? 0 : 2
                    border.color: "#9aa7b8"
                    Text {
                        anchors.centerIn: parent
                        text: step.done ? "✓" : (index + 1)
                        color: step.done || step.current ? "white" : "#5f6368"
                        font.pixelSize: step.done ? 12 : 11
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    anchors.left: dot.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: display
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: step.current ? Font.DemiBold : Font.Normal
                    color: step.current ? Branding.styleString(Branding.SidebarTextCurrent)
                                        : (step.done ? "#1b1b1b" : "#5f6368")
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
