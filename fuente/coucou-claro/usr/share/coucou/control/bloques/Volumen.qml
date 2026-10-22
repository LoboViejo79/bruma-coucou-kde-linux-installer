import QtQuick
import ".."

// Bloque del Centro de control: el volumen. Se acomoda a su lugar como el del brillo; si entran,
// al lado van silenciar y "más" (la vista de Sonido). El icono del deslizador también abre Sonido.
Item {
    id: b
    property var sis; property var tema; property int ancho: 3; property int alto: 1
    signal abrir(string vista)
    Deslizadores {
        anchors.fill: parent
        tema: b.tema
        titulo: "Volumen"
        icono: b.sis.mudo || b.sis.volumen === 0 ? "audio-volume-muted-symbolic" : (b.sis.volumen < 0.34 ? "audio-volume-low-symbolic" : (b.sis.volumen < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"))
        valor: b.sis.volumen
        apagado: b.sis.mudo
        onMover: v => b.sis.ponerVolumen(v)
        onTocarIcono: b.abrir("sonido")
        botones: [{ icono: b.sis.mudo ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic", encendido: b.sis.mudo, clic: function () { b.sis.silenciar() } },
                  { icono: "go-next-symbolic", chico: true, clic: function () { b.abrir("sonido") } }]
    }
}
