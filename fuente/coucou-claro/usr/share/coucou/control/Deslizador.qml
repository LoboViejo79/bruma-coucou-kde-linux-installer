import QtQuick
import org.kde.kirigami as Kirigami

// Un deslizador grande (brillo, volumen): la parte llena es el valor; el icono va adentro.
// Arrastrar, hacer clic o la rueda del ratón cambian el valor (0..maximo).
// vertical: se llena de abajo hacia arriba (para los bloques altos y angostos).
Rectangle {
    id: d
    property var tema
    property real valor: 0
    property real maximo: 1
    property string icono
    property bool apagado: false
    property bool vertical: false
    signal mover(real v)
    signal tocarIcono()
    readonly property real grosor: vertical ? width : height
    readonly property real largo: vertical ? height : width
    readonly property real fraccion: Math.max(0, Math.min(1, valor / maximo))
    radius: grosor / 2
    color: tema.vidrio
    clip: true

    Rectangle {
        readonly property real lleno: Math.max(d.grosor, d.largo * d.fraccion)
        x: 0; y: d.vertical ? d.height - height : 0
        width: d.vertical ? d.width : lleno
        height: d.vertical ? lleno : d.height
        radius: d.radius
        color: d.apagado ? d.tema.vidrioFuerte : d.tema.relleno
        Behavior on width { enabled: !arrastre.pressed && !d.vertical; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: !arrastre.pressed && d.vertical; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    Kirigami.Icon {
        x: d.vertical ? (d.width - width) / 2 : d.grosor / 2 - width / 2
        y: d.vertical ? d.height - d.grosor / 2 - height / 2 : (d.height - height) / 2
        width: Math.min(28, d.grosor * 0.36); height: width
        source: d.icono; isMask: true
        color: d.apagado ? d.tema.texto2 : d.tema.sobreRelleno
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: d.tocarIcono() }
    }
    MouseArea {
        id: arrastre
        anchors.fill: parent
        anchors.leftMargin: d.vertical ? 0 : d.grosor * 0.8
        anchors.bottomMargin: d.vertical ? d.grosor * 0.8 : 0
        cursorShape: Qt.PointingHandCursor
        function poner(m) {
            var f = d.vertical ? (d.height - m.y - anchors.bottomMargin) / d.height
                               : (m.x + anchors.leftMargin) / d.width
            d.mover(Math.max(0, Math.min(1, f)) * d.maximo)
        }
        onPressed: mouse => poner(mouse)
        onPositionChanged: mouse => { if (pressed) poner(mouse) }
        onWheel: wheel => d.mover(Math.max(0, Math.min(d.maximo, d.valor + (wheel.angleDelta.y > 0 ? 0.05 : -0.05) * d.maximo)))
    }
}
