import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.coucou.widgets as C

// Coucou: Conexiones. Wi-Fi, Bluetooth y modo avión con un clic; el cuarto botón abre los ajustes
// de red. Encendido = del color de énfasis.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    PlasmaNM.EnabledConnections { id: conexiones }
    PlasmaNM.Handler { id: red }
    PlasmaNM.NetworkStatus { id: estado }
    readonly property bool wifi: conexiones.wirelessEnabled
    readonly property bool avion: PlasmaNM.Configuration.airplaneModeEnabled
    readonly property bool bt: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    readonly property bool hayBt: BluezQt.Manager.adapters.length > 0
    readonly property int btConectados: BluezQt.Manager.connectedDevices ? BluezQt.Manager.connectedDevices.length : 0

    // La red Wi-Fi a la que está conectada (de "Wi-Fi: Conectado a MiRed"; las de cable no cuentan)
    readonly property string redWifi: {
        var l = (estado.activeConnections || "").split("\n")
        for (var i = 0; i < l.length; i++)
            if (/wi-?fi|inal[aá]mbric|wireless|wlan/i.test(l[i].split(":")[0]) && l[i].indexOf(":") > 0)
                return l[i].slice(l[i].indexOf(":") + 1).replace(/^\s*(Conectado a|Connected to)\s*/i, "").trim()
        return ""
    }
    function ponerAvion(si) {
        red.enableAirplaneMode(si)
        PlasmaNM.Configuration.airplaneModeEnabled = si
        BluezQt.Manager.bluetoothBlocked = si
    }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#26262B", abajo: "#121215", acento: "#3B82F6", manchas: ["#3A3A44", "#1C1C22"], texto: "#FFFFFF" })

        component Boton: Rectangle {
            id: b
            property string icono
            property string titulo
            property string detalle
            property bool encendido
            property bool activo: true
            signal clic()
            width: 67; height: 67; radius: 18
            color: encendido ? t.colorAcento : (m.containsMouse ? Qt.lighter(t.colorVidrio, 1.4) : t.colorVidrio)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
            opacity: activo ? 1 : 0.45
            scale: m.pressed ? 0.95 : 1
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on scale { NumberAnimation { duration: 100 } }
            C.Vidrio {
                k: e.k
                x: 9; y: 9; width: 22; height: 22; radius: 11
                relleno: "transparent"; border.width: 0
                icono: b.icono; tamIcono: 18
                tinta: b.encendido ? "#FFFFFF" : t.colorTexto
                activo: false; opacity: 1
            }
            C.Texto {
                x: 10; y: 36; width: parent.width - 16
                text: b.titulo
                color: b.encendido ? "#FFFFFF" : t.colorTexto
                font.pixelSize: 11; font.weight: Font.DemiBold
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 7
            }
            C.Texto {
                x: 10; y: 49; width: parent.width - 16
                text: b.detalle; elide: Text.ElideRight
                color: b.encendido ? Qt.rgba(1, 1, 1, 0.8) : t.colorTexto2
                font.pixelSize: 9
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 7
            }
            MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; enabled: b.activo; cursorShape: Qt.PointingHandCursor; onClicked: b.clic() }
        }

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170
            Grid {
                anchors.centerIn: parent
                columns: 2; spacing: 10
                Boton {
                    icono: root.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic"
                    titulo: "Wi-Fi"
                    detalle: !root.wifi ? "Apagado" : (root.redWifi || "Encendido")
                    encendido: root.wifi && !root.avion
                    activo: !root.avion
                    onClic: red.enableWireless(!root.wifi)
                }
                Boton {
                    icono: root.bt ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
                    titulo: "Bluetooth"
                    detalle: !root.hayBt ? "No hay" : (!root.bt ? "Apagado" : (root.btConectados > 0 ? root.btConectados + " conectado" + (root.btConectados > 1 ? "s" : "") : "Encendido"))
                    encendido: root.bt
                    activo: root.hayBt
                    onClic: BluezQt.Manager.bluetoothBlocked = root.bt
                }
                Boton {
                    icono: "network-flightmode-on-symbolic"
                    titulo: "Modo avión"
                    detalle: root.avion ? "Encendido" : "Apagado"
                    encendido: root.avion
                    onClic: root.ponerAvion(!root.avion)
                }
                Boton {
                    icono: "configure-symbolic"
                    titulo: "Ajustes"
                    detalle: "Red y Bluetooth"
                    onClic: Qt.openUrlExternally("systemsettings://kcm_networkmanagement")
                }
            }
        }
    }
}
