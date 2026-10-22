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
        icono: b.sis.perfil === "power-saver" ? "power-profile-power-saver-symbolic"
             : (b.sis.perfil === "performance" ? "power-profile-performance-symbolic" : "power-profile-balanced-symbolic")
        titulo: b.sis.hayBateria ? "Batería " + b.sis.bateria + "%" + (b.sis.cargando ? " ⚡" : "") : "Energía"
        detalle: b.sis.nombresPerfil[b.sis.perfil] || "Perfil de energía"
        encendido: b.sis.perfil === "performance" || b.sis.perfil === "power-saver"
        onAlternar: b.sis.siguientePerfil()
        onAbrir: b.abrir("energia")
    }
}
