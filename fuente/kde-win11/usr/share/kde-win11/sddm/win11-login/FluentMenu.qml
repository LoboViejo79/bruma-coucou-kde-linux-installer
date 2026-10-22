// Menú emergente oscuro y redondeado (estilo WinUI 3)
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Popup {
    id: menu
    property real s: 1
    default property alias items: col.data
    padding: 4 * s
    width: Math.max(180 * s, col.implicitWidth + padding * 2)
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }

    background: Item {
        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 8 * menu.s
            color: "#2c2c2c"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.09)
        }
        MultiEffect {
            source: panel
            anchors.fill: panel
            z: -1
            shadowEnabled: true
            shadowOpacity: 0.45
            shadowBlur: 1.0
            shadowVerticalOffset: 8
            autoPaddingEnabled: true
        }
    }
    contentItem: Column {
        id: col
        property var popupRef: menu
        property real s: menu.s
        spacing: 2 * menu.s
    }
}
