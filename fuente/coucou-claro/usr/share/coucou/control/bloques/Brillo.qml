import QtQuick
import org.coucou.widgets as W
import ".."

// Bloque del Centro de control: el brillo. Se acomoda a su lugar (columnas × filas de la grilla):
//   alto y angosto: deslizador vertical
//   bajo: el deslizador y, si entra, el botón de la luz nocturna al lado
//   alto y ancho: "Brillo  80 %" arriba y el deslizador (hasta 72 px de grueso) abajo
Item {
    id: b
    property var sis; property var tema; property int ancho: 3; property int alto: 1
    signal abrir(string vista)
    Deslizadores {
        anchors.fill: parent
        tema: b.tema
        titulo: "Brillo"
        icono: "brightness-high-symbolic"
        valor: b.sis.nivelBrillo
        apagado: !b.sis.hayBrillo
        onMover: v => b.sis.ponerBrillo(v)
        botones: [{ icono: "redshift-status-on", encendido: b.sis.luzNocturna, clic: function () { b.sis.alternarLuzNocturna() },
                    derecho: function () { b.abrir("cerrar"); b.sis.abrir("systemsettings", ["kcm_nightlight"]) } }]
    }
}
