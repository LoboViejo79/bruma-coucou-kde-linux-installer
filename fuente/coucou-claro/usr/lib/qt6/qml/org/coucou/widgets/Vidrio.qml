import QtQuick
import org.kde.kirigami as Kirigami

// Coucou: un botón de vidrio (el de los controles de música, el de "Spin"…). Con icono o texto.
Rectangle {
    id: b
    property string icono: ""
    property string texto: ""
    property color tinta: "#FFFFFF"
    property color relleno: Qt.rgba(1, 1, 1, 0.09)
    property real tamIcono: Math.min(width, height) * 0.38
    property real tamTexto: Math.min(width, height) * 0.36
    property bool activo: true
    property real k: 1                  // el de Escala: el icono se dibuja al tamaño real (nítido)
    signal clic()

    radius: Math.min(width, height) * 0.3
    color: m.pressed ? Qt.lighter(relleno, 1.6) : (m.containsMouse ? Qt.lighter(relleno, 1.3) : relleno)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    opacity: activo ? 1 : 0.4
    scale: m.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        anchors.centerIn: parent
        spacing: b.tamTexto * 0.35
        Item {
            visible: b.icono !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: b.tamIcono; height: width
            Kirigami.Icon {
                width: b.tamIcono * b.k; height: width
                scale: 1 / b.k
                transformOrigin: Item.TopLeft
                source: b.icono
                color: b.tinta
                isMask: true
            }
        }
        Text {
            visible: b.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: b.texto
            color: b.tinta
            font.pixelSize: b.tamTexto
            font.weight: Font.DemiBold
            font.family: "Inter"
            renderType: Text.QtRendering
        }
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; enabled: b.activo; cursorShape: Qt.PointingHandCursor; onClicked: b.clic() }
}
