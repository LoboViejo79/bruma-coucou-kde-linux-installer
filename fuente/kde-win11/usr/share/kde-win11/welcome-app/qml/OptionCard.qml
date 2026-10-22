import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fila de opción de la instalación de Windows 11: icono, título, descripción y a la derecha
// un interruptor, una casilla, un botón o una flecha (según "kind").
Rectangle {
    id: root
    property string glyph: "info"
    property string icon: ""            // icono del tema en lugar del glifo
    property string title
    property string description
    property string kind: "switch"      // switch | check | button | link
    property string buttonText: "Ejecutar"
    property bool checked: false
    property string badge: ""           // p. ej. "Instalado"
    signal toggled(bool on)
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(68, row.implicitHeight + 24)
    radius: 6
    color: area.containsMouse && kind !== "switch" ? win.cardHover : win.cardBg
    border.color: kind === "check" && checked ? win.accent : win.cardBorder
    border.width: 1
    Behavior on color { ColorAnimation { duration: 100 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.kind === "switch" ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (root.kind === "check" || root.kind === "switch") root.toggled(!root.checked)
            else root.clicked()
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 16

        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            FluentIcon { anchors.fill: parent; visible: root.icon === ""; name: root.glyph; size: 22 }
            Image {
                anchors.fill: parent
                visible: root.icon !== ""
                source: root.icon ? "image://icon/" + root.icon : ""
                sourceSize: Qt.size(48, 48)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                spacing: 8
                Label { text: root.title; color: win.text; font.pixelSize: 14 }
                Rectangle {
                    visible: root.badge !== ""
                    radius: 4
                    color: Qt.alpha(win.accent, 0.18)
                    implicitWidth: badgeText.implicitWidth + 12
                    implicitHeight: 18
                    Label { id: badgeText; anchors.centerIn: parent; text: root.badge; color: win.accentText; font.pixelSize: 11 }
                }
            }
            Label {
                visible: text !== ""
                Layout.fillWidth: true
                text: root.description
                color: win.subtext
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
        Switch {
            visible: root.kind === "switch"
            checked: root.checked
            text: checked ? "Activado" : "Desactivado"
            LayoutMirroring.enabled: true
            onToggled: root.toggled(checked)
        }
        CheckBox {
            visible: root.kind === "check"
            checked: root.checked
            onToggled: root.toggled(checked)
        }
        Button {
            visible: root.kind === "button"
            text: root.buttonText
            onClicked: root.clicked()
        }
        FluentIcon {
            visible: root.kind === "link"
            name: "open"
            size: 16
            color: win.subtext
        }
    }
}
