import QtQuick
import ".."

// Bloque del Centro de control: Modo juego. El círculo lo enciende o apaga; el resto abre su
// vista (qué pausa y qué hace).
Item {
    id: b
    property var sis; property var tema; property int ancho: 1; property int alto: 1
    signal abrir(string vista)
    Pildora {
        anchors.fill: parent
        tema: b.tema
        icono: "applications-games-symbolic"
        titulo: "Modo juego"
        // (activo: cuántas cosas quedaron en pausa, para que se sepa por qué algo no anda)
        readonly property int enPausa: (b.sis.juego.pausado || []).filter(function (k) { return k !== "comprimir" }).length
        detalle: b.sis.modoJuego ? "Activado · " + (enPausa > 0 ? enPausa + (enPausa === 1 ? " cosa" : " cosas") + " en pausa · " : "")
                                   + b.sis.juego.libre + " MB libres"
                                 : "Más rendimiento · " + b.sis.juego.libre + " MB libres"
        encendido: b.sis.modoJuego
        onAlternar: b.sis.alternarJuego()
        onAbrir: b.abrir("juego")
    }
}
