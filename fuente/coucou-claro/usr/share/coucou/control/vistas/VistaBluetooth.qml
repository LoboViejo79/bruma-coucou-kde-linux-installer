import QtQuick
import org.kde.bluezqt as BluezQt
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: Bluetooth. Tus dispositivos (conectar / desconectar) y, buscando,
// los que están cerca para vincularlos.
Item {
    id: v
    property var sis; property var tema
    signal volver()
    readonly property real altoDeseado: 560
    readonly property var adaptador: BluezQt.Manager.usableAdapter
    readonly property bool buscando: adaptador ? adaptador.discovering : false
    Component.onDestruction: if (buscando) adaptador.stopDiscovery()

    Encabezado {
        id: enc
        width: parent.width
        icono: "network-bluetooth-symbolic"; tema: v.tema; titulo: "Bluetooth"
        conInterruptor: v.sis.hayBt; encendido: v.sis.bt
        onVolver: v.volver()
        onAlternar: v.sis.ponerBt(!v.sis.bt)
    }
    W.Texto {
        visible: !v.sis.bt
        anchors { top: enc.bottom; topMargin: 30; horizontalCenter: parent.horizontalCenter }
        text: v.sis.hayBt ? "El Bluetooth está apagado" : "Este equipo no tiene Bluetooth"; color: v.tema.texto2; font.pixelSize: 14
    }
    ListView {
        id: lista
        visible: v.sis.bt
        anchors { top: enc.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: buscar.top; bottomMargin: 10 }
        clip: true
        spacing: 8
        // Primero los vinculados, después los nuevos (al buscar)
        model: (BluezQt.Manager.devices || []).slice().sort(function (a, b) {
            return (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name) })
        delegate: Fila {
            required property var modelData
            readonly property var d: modelData
            width: ListView.view.width
            tema: v.tema
            icono: (d.icon || "bluetooth") + "-symbolic"
            titulo: d.name || d.address
            detalle: d.connected ? ("Conectado" + (d.battery ? " · batería " + d.battery.percentage + "%" : "")) : (d.paired ? "Vinculado" : "Nuevo")
            marcada: d.connected
            accion: d.connected ? "Desconectar" : (d.paired ? "Conectar" : "Vincular")
            onAccionar: {
                if (d.connected) d.disconnectFromDevice()
                else if (d.paired) d.connectToDevice()
                else { d.trusted = true; d.pair() }
            }
        }
    }
    Rectangle {
        id: buscar
        visible: v.sis.bt
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: bt.implicitWidth + 36; height: 40; radius: 20
        color: v.buscando ? v.tema.acento : (bm.containsMouse ? v.tema.vidrioFuerte : v.tema.vidrio)
        W.Texto { id: bt; anchors.centerIn: parent; text: v.buscando ? "Buscando… (tocar para parar)" : "Buscar dispositivos"
                  color: v.buscando ? v.tema.sobreAcento : v.tema.texto; font.pixelSize: 13 }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (v.adaptador) { if (v.buscando) v.adaptador.stopDiscovery(); else v.adaptador.startDiscovery() } }
    }
}
