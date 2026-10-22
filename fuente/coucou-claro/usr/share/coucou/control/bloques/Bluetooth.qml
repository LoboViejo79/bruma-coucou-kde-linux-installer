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
        icono: b.sis.bt ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
        titulo: "Bluetooth"
        detalle: !b.sis.hayBt ? "No hay" : (!b.sis.bt ? "Apagado" : (b.sis.btNombre || "Encendido"))
        encendido: b.sis.bt
        activo: b.sis.hayBt
        onAlternar: b.sis.ponerBt(!b.sis.bt)
        onAbrir: b.abrir("bluetooth")
    }
}
