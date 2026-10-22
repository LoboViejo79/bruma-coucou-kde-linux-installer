import QtQuick
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W

// Un botón redondo del Centro de control (encendido = del color de énfasis). Con `nombre`
// muestra debajo qué es (en los bloques anchos).
Item {
    id: r
    property var tema
    property string icono
    property bool encendido: false
    property bool activo: true
    property string nombre: ""
    property real tam: 54
    signal clic()
    signal clicDerecho()
    width: tam; height: tam + (nombre !== "" ? 18 : 0)
    opacity: activo ? 1 : 0.4

    Rectangle {
        id: bola
        width: r.tam; height: r.tam; radius: r.tam / 2
        color: r.encendido ? r.tema.acento : (m.containsMouse ? r.tema.vidrioFuerte : r.tema.vidrio)
        scale: m.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: r.tam * 0.42; height: width
            source: r.icono
            color: r.encendido ? r.tema.sobreAcento : r.tema.texto
            isMask: true
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            enabled: r.activo
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => mouse.button === Qt.RightButton ? r.clicDerecho() : r.clic()
        }
    }
    W.Texto {
        visible: r.nombre !== ""
        anchors.horizontalCenter: bola.horizontalCenter
        y: r.tam + 4
        width: r.tam + 24
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: r.nombre
        color: r.tema.texto2
        font.pixelSize: 10
    }
}
