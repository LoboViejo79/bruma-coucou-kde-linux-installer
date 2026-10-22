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
        icono: b.sis.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
        titulo: "Wi-Fi"
        detalle: !b.sis.wifi ? "Apagado" : (b.sis.redWifi || (b.sis.cable ? "Usas cable" : "Sin conectar"))
        encendido: b.sis.wifi && !b.sis.avion
        activo: b.sis.hayWifi && !b.sis.avion
        onAlternar: b.sis.ponerWifi(!b.sis.wifi)
        onAbrir: b.abrir("wifi")
    }
}
