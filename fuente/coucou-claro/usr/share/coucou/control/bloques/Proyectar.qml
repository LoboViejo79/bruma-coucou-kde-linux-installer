import QtQuick
import ".."

// Bloque del Centro de control. Recibe sis (el estado del equipo), tema (los colores) y su
// tamaño (columnas y filas que ocupa en la grilla; se dibuja según su ancho y alto reales);
// abrir(vista) muestra su vista.
Item {
    id: b
    property var sis; property var tema; property int ancho: 1; property int alto: 1
    signal abrir(string vista)
    Pildora {
        anchors.fill: parent
        tema: b.tema
        icono: "video-display-symbolic"
        titulo: "Proyectar"
        detalle: "Otra pantalla"
        onAlternar: { b.abrir("cerrar"); b.sis.proyectar() }
        onAbrir: { b.abrir("cerrar"); b.sis.proyectar() }
    }
}
