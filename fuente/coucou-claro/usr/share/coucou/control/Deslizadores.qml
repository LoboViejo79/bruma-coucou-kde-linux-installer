import QtQuick
import org.coucou.widgets as W

// Lo común de los bloques de brillo y volumen: el deslizador y sus botones, acomodados al lugar.
//   alto y angosto (más alto que ancho): deslizador vertical, sin botones
//   hasta 100 px de alto: deslizador acostado y los botones al lado, los que entren
//   más alto: el nombre y el porcentaje arriba; abajo el deslizador (de 72 px a lo sumo) y los botones
Item {
    id: g
    property var tema
    property string titulo
    property string icono
    property real valor
    property bool apagado
    property var botones: []                    // [{ icono, encendido, chico, clic(), derecho() }]
    signal mover(real v)
    signal tocarIcono()
    readonly property bool vertical: height > width * 1.15
    readonly property bool conTitulo: !vertical && height > 100
    readonly property real grosor: vertical ? Math.min(width, 96) : Math.min(conTitulo ? height - 40 : height, 72)
    // Los botones que entran al lado (cada uno del alto del deslizador), dejando al menos 2.5 veces el
    // grosor para el deslizador
    readonly property int cuantos: vertical ? 0 : Math.max(0, Math.min(botones.length, Math.floor((width - grosor * 2.5) / (grosor + 8))))

    Row {
        visible: g.conTitulo
        x: 6; y: 4
        spacing: 8
        W.Texto { text: g.titulo; color: g.tema.texto; font.pixelSize: 15; font.weight: Font.DemiBold }
        W.Texto { text: Math.round(g.valor * 100) + " %"; color: g.tema.texto2; font.pixelSize: 15 }
    }
    Deslizador {
        tema: g.tema
        vertical: g.vertical
        x: g.vertical ? (g.width - width) / 2 : 0
        y: g.vertical ? 0 : (g.conTitulo ? g.height - height : (g.height - height) / 2)
        width: g.vertical ? g.grosor : g.width - (g.cuantos > 0 ? fila.width + 12 : 0)
        height: g.vertical ? g.height : g.grosor
        icono: g.icono
        valor: g.valor
        apagado: g.apagado
        onMover: v => g.mover(v)
        onTocarIcono: g.tocarIcono()
    }
    Row {
        id: fila
        visible: g.cuantos > 0
        anchors.right: parent.right
        y: g.conTitulo ? g.height - g.grosor : (g.height - g.grosor) / 2
        height: g.grosor
        spacing: 8
        Repeater {
            model: g.cuantos
            Redondo {
                required property int index
                readonly property var bt: g.botones[index]
                anchors.verticalCenter: parent.verticalCenter
                tam: bt.chico ? g.grosor * 0.62 : g.grosor
                tema: g.tema
                icono: bt.icono
                encendido: !!bt.encendido
                onClic: bt.clic()
                onClicDerecho: if (bt.derecho) bt.derecho()
            }
        }
    }
}
