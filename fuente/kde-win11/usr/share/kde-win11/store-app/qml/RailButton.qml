import QtQuick
import QtQuick.Controls

// Botón de la barra lateral de la Store: icono encima del texto, píldora al seleccionar
Item {
    id: root
    property string text
    property string iconName
    property bool selected: false
    property int badge: 0
    signal clicked()

    width: 68
    height: 58

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 6
        color: root.selected || area.containsMouse ? win.navHover : "transparent"
        opacity: area.pressed ? 0.7 : 1
    }

    // Indicador de selección (barra de énfasis a la izquierda)
    Rectangle {
        width: 3
        height: root.selected ? 16 : 0
        radius: 2
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        color: win.accent
        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    FluentIcon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // Seleccionado: solo el icono, centrado (como la Store de Windows 11)
        anchors.topMargin: root.selected ? (root.height - 20) / 2 : 10
        Behavior on anchors.topMargin { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        size: 20
        name: root.iconName
        filled: root.selected
        color: root.selected ? win.accent : win.text
        scale: area.pressed ? 0.85 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }

        Rectangle {
            visible: root.badge > 0
            x: 13; y: -5
            height: 16
            width: Math.max(16, badgeText.implicitWidth + 8)
            radius: 8
            color: win.accent
            Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                color: "white"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: icon.bottom
        anchors.topMargin: 4
        text: root.text
        font.pixelSize: 11
        color: win.text
        opacity: root.selected ? 0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 120 } }
        font.weight: root.selected ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
