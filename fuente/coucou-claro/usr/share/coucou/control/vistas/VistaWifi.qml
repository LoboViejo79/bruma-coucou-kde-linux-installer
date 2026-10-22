import QtQuick
import QtQuick.Controls
import org.kde.plasma.networkmanagement as PlasmaNM
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: Wi-Fi. Las redes cercanas por su señal: la conectada arriba; un clic
// en una guardada conecta, en una nueva pide la contraseña ahí mismo (si tiene).
Item {
    id: v
    property var sis; property var tema
    signal volver()
    readonly property real altoDeseado: 560
    property string pidiendo: ""          // la red a la que se le está escribiendo la contraseña

    PlasmaNM.NetworkModel { id: redes }
    PlasmaNM.AppletProxyModel { id: ordenadas; sourceModel: redes }
    Timer { interval: 8000; repeat: true; running: v.sis.wifi; triggeredOnStart: true; onTriggered: v.sis.red.requestScan() }

    Encabezado {
        id: enc
        width: parent.width
        icono: v.sis.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"; tema: v.tema; titulo: "Wi-Fi"
        conInterruptor: true; encendido: v.sis.wifi
        onVolver: v.volver()
        onAlternar: v.sis.ponerWifi(!v.sis.wifi)
    }
    W.Texto {
        visible: !v.sis.wifi
        anchors { top: enc.bottom; topMargin: 30; horizontalCenter: parent.horizontalCenter }
        text: "El Wi-Fi está apagado"; color: v.tema.texto2; font.pixelSize: 14
    }
    ListView {
        visible: v.sis.wifi
        anchors { top: enc.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        spacing: 8
        model: ordenadas
        delegate: Fila {
            id: fila
            required property var model
            readonly property bool esWifi: model.Type === 14
            readonly property bool conectada: model.ConnectionState === 2
            readonly property bool conectando: model.ConnectionState === 1
            readonly property bool guardada: model.Uuid !== ""
            readonly property bool segura: model.SecurityType > 0
            visible: esWifi
            height: esWifi ? implicitHeight : -8     // (las de cable no van: -8 compensa el espacio entre filas)
            width: ListView.view.width
            tema: v.tema
            icono: model.Signal > 75 ? "network-wireless-signal-excellent-symbolic"
                 : model.Signal > 50 ? "network-wireless-signal-good-symbolic"
                 : model.Signal > 25 ? "network-wireless-signal-ok-symbolic" : "network-wireless-signal-weak-symbolic"
            titulo: model.ItemUniqueName + (segura ? "  🔒" : "")
            detalle: conectada ? "Conectada" : (conectando ? "Conectando…" : (guardada ? "Guardada" : (segura ? "Con contraseña" : "Abierta")))
            marcada: conectada
            accion: conectada ? "Desconectar" : (v.pidiendo === model.ItemUniqueName ? "" : "Conectar")
            onAccionar: {
                if (conectada) v.sis.red.deactivateConnection(model.ConnectionPath, model.DevicePath)
                else if (guardada) v.sis.red.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath)
                else if (segura) v.pidiendo = model.ItemUniqueName
                else v.sis.red.addAndActivateConnection(model.DevicePath, model.SpecificPath)
            }
            // La contraseña de una red nueva
            Row {
                visible: v.pidiendo === fila.model.ItemUniqueName
                spacing: 6
                topPadding: 6
                TextField {
                    id: clave
                    width: fila.width - 150
                    echoMode: TextInput.Password
                    placeholderText: "Contraseña"
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: conectar.clicked()
                }
                Button {
                    id: conectar
                    text: "Conectar"
                    onClicked: { v.sis.red.addAndActivateConnection(fila.model.DevicePath, fila.model.SpecificPath, clave.text); v.pidiendo = "" }
                }
            }
        }
    }
}
