import QtQuick
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W

// El encabezado de una vista (Wi-Fi, Bluetooth…): flecha para volver, título y, a la derecha,
// un interruptor opcional y otros botones.
Item {
    id: e
    property var tema
    property string titulo
    property string icono                       // (opcional) el ícono del bloque, en un círculo
    property bool iconoEncendido: conInterruptor ? encendido : true
    property bool conInterruptor: false
    property bool encendido: false
    default property alias extras: fila.data
    signal volver()
    signal alternar()
    height: 52
    Rectangle {
        id: atras
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: 38; height: 38; radius: 19
        // (el círculo del ícono va pegado a la flecha)
        color: am.containsMouse ? e.tema.vidrioFuerte : e.tema.vidrio
        Kirigami.Icon { anchors.centerIn: parent; width: 18; height: 18; source: "go-previous-symbolic"; isMask: true; color: e.tema.texto }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: e.volver() }
    }
    Rectangle {
        id: circulo
        objectName: "heroIcono"                 // aquí llega el del bloque (ver main.qml)
        readonly property color colorIcono: e.iconoEncendido ? e.tema.sobreAcento : e.tema.texto
        visible: e.icono !== ""
        anchors { left: atras.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
        width: visible ? 40 : 0; height: 40; radius: 20
        color: e.iconoEncendido ? e.tema.acento : e.tema.vidrioFuerte
        Behavior on color { ColorAnimation { duration: 160 } }
        Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.46; height: width; source: e.icono; isMask: true; color: circulo.colorIcono }
    }
    W.Texto {
        objectName: "heroTitulo"
        anchors { left: circulo.right; leftMargin: circulo.visible ? 10 : 0; right: fila.left; verticalCenter: parent.verticalCenter }
        text: e.titulo; color: e.tema.texto; font.pixelSize: 20; font.weight: Font.Bold; elide: Text.ElideRight
    }
    Row {
        id: fila
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8
        // Interruptor (el de la vista: Wi-Fi sí/no…)
        Rectangle {
            visible: e.conInterruptor
            width: 48; height: 28; radius: 14
            color: e.encendido ? e.tema.acento : e.tema.vidrioFuerte
            Behavior on color { ColorAnimation { duration: 150 } }
            Rectangle {
                width: 22; height: 22; radius: 11; y: 3
                x: e.encendido ? parent.width - width - 3 : 3
                color: "#FFFFFF"
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: e.alternar() }
        }
    }
}
