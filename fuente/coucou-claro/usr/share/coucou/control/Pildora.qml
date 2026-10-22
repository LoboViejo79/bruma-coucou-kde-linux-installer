import QtQuick
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W

// La píldora de Wi-Fi, Bluetooth…: el círculo enciende o apaga; el resto abre su vista.
// Se acomoda al lugar que tiene:
//   alta (más de 100 px de alto): el círculo arriba y el texto abajo, como una tarjeta
//   angosta (menos de 150 px de ancho): solo el círculo, al medio
//   baja: círculo a la izquierda y el texto al lado (con flecha si es ancha)
// El círculo no pasa de 64 px ni el texto de su tamaño: más grande se vería vacío, no enorme.
Rectangle {
    id: p
    property var tema
    property string icono
    property string titulo
    property string detalle
    property bool encendido: false
    property bool activo: true
    readonly property bool alta: height > 100 && width >= 104
    readonly property bool angosta: !alta && width < 150
    property bool flecha: !alta && width > 300          // ancha: una flecha que dice "hay más"
    signal alternar()
    signal abrir()
    radius: Math.min(height / 2, 30)
    color: tm.containsMouse ? tema.vidrioFuerte : tema.vidrio
    Behavior on color { ColorAnimation { duration: 120 } }

    readonly property real lado: Math.min(64, p.angosta ? Math.min(width, height) - 14 : (p.alta ? Math.min(height * 0.42, width * 0.36) : height - 14))
    Rectangle {
        id: circulo
        objectName: "heroIcono"                 // viaja al encabezado de la vista (ver main.qml)
        readonly property color colorIcono: p.encendido ? p.tema.sobreAcento : p.tema.texto
        x: p.angosta ? (p.width - width) / 2 : (p.alta ? 16 : (p.height - height) / 2)
        y: p.alta ? 16 : (p.height - height) / 2
        width: p.lado; height: width; radius: width / 2
        color: p.encendido ? p.tema.acento : p.tema.vidrioFuerte
        opacity: p.activo ? 1 : 0.4
        scale: cm.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 100 } }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.46; height: width
            source: p.icono; isMask: true
            color: circulo.colorIcono
        }
        MouseArea { id: cm; anchors.fill: parent; enabled: p.activo; cursorShape: Qt.PointingHandCursor; onClicked: p.alternar() }
    }
    Column {
        visible: !p.angosta
        x: p.alta ? 18 : circulo.x + circulo.width + 10
        y: p.alta ? p.height - height - 14 : (p.height - height) / 2
        width: (p.alta ? p.width - 36 : fl.x - x - 6)
        spacing: 1
        W.Texto { objectName: "heroTitulo"; width: parent.width; text: p.titulo; color: p.tema.texto
                  font.pixelSize: p.alta ? 17 : 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
        W.Texto { width: parent.width; visible: text !== ""; text: p.detalle; color: p.tema.texto2; font.pixelSize: 12
                  elide: Text.ElideRight; maximumLineCount: p.alta && p.height > 150 ? 2 : 1; wrapMode: Text.Wrap }
    }
    Kirigami.Icon {
        id: fl
        x: p.width - (p.flecha ? width + 18 : 4)
        anchors.verticalCenter: parent.verticalCenter
        width: p.flecha ? 16 : 0; height: 16
        visible: p.flecha
        source: "go-next-symbolic"; isMask: true; color: p.tema.texto2
    }
    MouseArea { id: tm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.abrir() }
}
