import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sistema: cabecera con el equipo como en Windows 11 (fondo, nombre, "Cambiar nombre",
// accesos a la derecha) y la lista de ajustes.
LinksPage {
    id: root

    header: [
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 24
            spacing: 16

            // Miniatura del escritorio
            Item {
                Layout.preferredWidth: 120; Layout.preferredHeight: 68
                Rectangle { anchors.fill: parent; radius: 4; color: "#000000" }
                Image {
                    anchors.fill: parent
                    source: backend.wallpaper
                    sourceSize.width: 240
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle { anchors.fill: parent; radius: 4; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.08) }
            }

            ColumnLayout {
                spacing: 1
                Label { text: backend.hostname; font.pixelSize: 18; font.weight: Font.DemiBold; color: win.text }
                Label {
                    text: [backend.sysInfo.vendor, backend.sysInfo.model].filter(function (s) { return s && s !== "To Be Filled By O.E.M." }).join(" ") || backend.sysInfo.os
                    color: win.text; font.pixelSize: 13; opacity: 0.9
                }
                Label {
                    text: "Cambiar nombre"
                    color: win.accent
                    font.pixelSize: 13
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: renameDialog.open() }
                }
            }

            Item { Layout.fillWidth: true }

            // Accesos rápidos (como "Microsoft 365" y "Windows Update")
            component QuickLink: MouseArea {
                id: ql
                property string title
                property string subtitle
                property url iconSource
                property string glyph
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                implicitWidth: qlRow.implicitWidth + 16
                implicitHeight: qlRow.implicitHeight + 12
                Rectangle { anchors.fill: parent; radius: 4; color: ql.containsMouse ? win.navHover : "transparent" }
                RowLayout {
                    id: qlRow
                    anchors.centerIn: parent
                    spacing: 12
                    Image {
                        source: ql.iconSource
                        sourceSize: Qt.size(48, 48)
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        spacing: 1
                        Label { text: ql.title; color: win.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Label { text: ql.subtitle; color: win.subtext; font.pixelSize: 12; Layout.maximumWidth: 170; wrapMode: Text.Wrap }
                    }
                }
            }
            QuickLink {
                title: win.brand("Microsoft Store")
                subtitle: "Aplicaciones y juegos"
                iconSource: "image://icon/win11-store"
                onClicked: backend.launch("win11-store")
            }
            QuickLink {
                title: win.brand("Windows Update")
                subtitle: backend.lastUpdateCheck ? "Última comprobación: hoy a las " + backend.lastUpdateCheck : "Buscar actualizaciones"
                iconSource: "image://icon/system-software-update"
                onClicked: win.openCategory("update")
            }
        }
    ]

    Dialog {
        id: renameDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        width: 460
        title: "Cambiar el nombre del equipo"
        property string pendingError: ""
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { nameField.text = backend.hostname; nameField.selectAll(); nameField.forceActiveFocus(); errorLabel.text = pendingError; pendingError = "" }
        onAccepted: backend.renameHost(nameField.text.trim())
        Component.onCompleted: standardButton(Dialog.Ok).text = "Siguiente"
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Nombre actual: " + backend.hostname + "\nPuedes usar letras, números y guiones."
                color: win.subtext
            }
            TextField { id: nameField; Layout.fillWidth: true; onAccepted: renameDialog.accept() }
            Label { id: errorLabel; Layout.fillWidth: true; wrapMode: Text.Wrap; color: "#FF99A4"; visible: text !== "" }
        }
    }
    Connections {
        target: backend
        function onHostRenamed(ok, message) { if (!ok) { renameDialog.pendingError = message; renameDialog.open() } }
    }
}
