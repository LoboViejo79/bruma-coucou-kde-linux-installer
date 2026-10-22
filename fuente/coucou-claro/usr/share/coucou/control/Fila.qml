import QtQuick
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W

// Una fila de lista (una red, un dispositivo, una salida de sonido…)
Rectangle {
    id: f
    property var tema
    property string icono
    property string titulo
    property string detalle
    property bool marcada: false          // la conectada / la elegida
    property string accion: ""            // texto del botón de la derecha ("Conectar"…)
    default property alias debajo: extra.data
    signal clic()
    signal accionar()
    width: parent ? parent.width : 300
    implicitHeight: Math.max(58, col.implicitHeight + 20)
    height: implicitHeight
    radius: 18
    color: f.marcada ? Qt.alpha(f.tema.acento, 0.32) : (fm.containsMouse ? f.tema.vidrioFuerte : f.tema.vidrio)
    border.width: f.marcada ? 1.5 : 0
    border.color: f.tema.acento
    Behavior on color { ColorAnimation { duration: 120 } }
    Kirigami.Icon {
        id: ic
        x: 14; y: 16
        width: 26; height: 26
        source: f.icono; isMask: true
        color: f.tema.texto
    }
    Column {
        id: col
        anchors { left: ic.right; leftMargin: 12; right: boton.left; rightMargin: 8; top: parent.top; topMargin: 10 }
        spacing: 2
        W.Texto { width: parent.width; text: f.titulo; color: f.tema.texto; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideRight }
        W.Texto { width: parent.width; visible: text !== ""; text: f.detalle; color: f.tema.texto2; font.pixelSize: 11; elide: Text.ElideRight }
        Column { id: extra; width: parent.width }        // (lo que va debajo; lo oculto no ocupa lugar)
    }
    Rectangle {
        id: boton
        visible: f.accion !== ""
        anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 13 }
        width: visible ? ac.implicitWidth + 22 : 0; height: 32; radius: 16
        color: bm.containsMouse ? Qt.lighter(f.tema.acento, 1.15) : f.tema.acento
        W.Texto { id: ac; anchors.centerIn: parent; text: f.accion; color: f.tema.sobreAcento; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: f.accionar() }
    }
    MouseArea { id: fm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: f.clic() }
}
