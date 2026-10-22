import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.brightnesscontrolplugin as Brillo
import org.kde.plasma.private.batterymonitor as Bateria
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.dbus as DBus

// Coucou, Centro de control: el estado del equipo y lo que se puede hacer, en un solo lugar.
// Lo usan todos los bloques y las vistas (como `sis`).
QtObject {
    id: s

    // ── Red ──────────────────────────────────────────────────────────────────
    readonly property var conexiones: PlasmaNM.EnabledConnections {}
    readonly property var red: PlasmaNM.Handler {}
    readonly property var estadoRed: PlasmaNM.NetworkStatus {}
    readonly property bool wifi: conexiones.wirelessEnabled
    readonly property bool hayWifi: conexiones.wirelessHwEnabled
    readonly property bool avion: PlasmaNM.Configuration.airplaneModeEnabled
    // La red Wi-Fi conectada (de "Wi-Fi: Conectado a MiRed"; las de cable no cuentan)
    readonly property string redWifi: {
        var l = (estadoRed.activeConnections || "").split("\n")
        for (var i = 0; i < l.length; i++)
            if (/wi-?fi|inal[aá]mbric|wireless|wlan/i.test(l[i].split(":")[0]) && l[i].indexOf(":") > 0)
                return l[i].slice(l[i].indexOf(":") + 1).replace(/^\s*(Conectado a|Connected to)\s*/i, "").trim()
        return ""
    }
    readonly property bool cable: /ethernet|cablead|wired/i.test(estadoRed.activeConnections || "")
    function ponerWifi(si) { red.enableWireless(si) }
    function ponerAvion(si) {
        red.enableAirplaneMode(si)
        PlasmaNM.Configuration.airplaneModeEnabled = si
        BluezQt.Manager.bluetoothBlocked = si
    }

    // ── Bluetooth ────────────────────────────────────────────────────────────
    readonly property bool hayBt: BluezQt.Manager.adapters.length > 0
    readonly property bool bt: BluezQt.Manager.bluetoothOperational && !BluezQt.Manager.bluetoothBlocked
    readonly property var btConectados: BluezQt.Manager.connectedDevices || []
    readonly property string btNombre: btConectados.length === 1 ? btConectados[0].name
                                     : (btConectados.length > 1 ? btConectados.length + " dispositivos" : "")
    function ponerBt(si) { BluezQt.Manager.bluetoothBlocked = !si }

    // ── Sonido ───────────────────────────────────────────────────────────────
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property var source: Vol.PreferredDevice.source
    readonly property real volumen: sink ? sink.volume / 65536 : 0
    readonly property bool mudo: sink ? sink.muted : false
    readonly property bool micMudo: source ? source.muted : true
    function ponerVolumen(v) {
        if (!sink) return
        sink.volume = Math.round(Math.max(0, Math.min(1.5, v)) * 65536)
        if (sink.muted && v > 0) sink.muted = false
    }
    function silenciar() { if (sink) sink.muted = !sink.muted }
    function silenciarMic() { if (source) source.muted = !source.muted }

    // ── Brillo y luz nocturna ────────────────────────────────────────────────
    readonly property var brillo: Brillo.ScreenBrightnessControl { isSilent: true }
    readonly property var pantallas: Instantiator {
        model: s.brillo.displays
        delegate: QtObject {
            required property string displayName
            required property int brightness
            required property int maxBrightness
            required property bool isInternal
        }
    }
    readonly property var pantalla: pantallas.count > 0 ? pantallas.objectAt(0) : null
    readonly property bool hayBrillo: brillo.isBrightnessAvailable && pantalla !== null
    readonly property real nivelBrillo: pantalla && pantalla.maxBrightness > 0 ? pantalla.brightness / pantalla.maxBrightness : 0
    function ponerBrillo(v) {
        if (!pantalla) return
        brillo.setBrightness(pantalla.displayName, Math.round(Math.max(0.01, Math.min(1, v)) * pantalla.maxBrightness))
    }
    readonly property var nocturna: Brillo.NightLightInhibitor     // (es único: se usa, no se crea)
    readonly property var kwinLuz: DBus.Properties {
        busType: DBus.BusType.Session
        service: "org.kde.KWin"; path: "/org/kde/KWin/NightLight"; iface: "org.kde.KWin.NightLight"
    }
    readonly property bool luzNocturna: !!kwinLuz.properties["enabled"] && !nocturna.inhibited
    function alternarLuzNocturna() {
        if (!kwinLuz.properties["enabled"]) { abrir("systemsettings", ["kcm_nightlight"]); return }
        nocturna.toggleInhibition()
    }

    // ── No molestar ──────────────────────────────────────────────────────────
    readonly property var avisos: NotificationManager.Settings {}
    property real ahora: Date.now()
    readonly property bool noMolestar: {
        var d = avisos.notificationsInhibitedUntil
        return (!!d && !isNaN(d.getTime()) && d.getTime() > ahora) || avisos.notificationsInhibitedByApplication
    }
    function alternarNoMolestar() {
        if (noMolestar) {
            avisos.notificationsInhibitedUntil = undefined
            avisos.revokeApplicationInhibitions()
        } else {
            var d = new Date(); d.setFullYear(d.getFullYear() + 1)
            avisos.notificationsInhibitedUntil = d
        }
        avisos.save()
        ahora = Date.now()
    }

    // ── Energía y batería ────────────────────────────────────────────────────
    readonly property var perfiles: Bateria.PowerProfilesControl {}
    readonly property var nombresPerfil: ({ "power-saver": "Ahorro de energía", "balanced": "Equilibrado", "performance": "Rendimiento" })
    readonly property string perfil: perfiles.activeProfile || ""
    function siguientePerfil() {
        var l = perfiles.profiles || []
        if (!l.length) return
        perfiles.setProfile(l[(l.indexOf(perfil) + 1) % l.length])
    }
    readonly property var energia: P5Support.DataSource { engine: "powermanagement"; connectedSources: ["Battery", "AC Adapter"] }
    readonly property bool hayBateria: energia.data["Battery"] ? energia.data["Battery"]["Has Battery"] === true : false
    readonly property int bateria: hayBateria ? energia.data["Battery"]["Percent"] : 0
    readonly property bool cargando: energia.data["AC Adapter"] ? energia.data["AC Adapter"]["Plugged in"] === true : false

    // ── Música ───────────────────────────────────────────────────────────────
    readonly property var mpris: Mpris.Mpris2Model {}
    readonly property var player: mpris.currentPlayer
    readonly property bool hayMusica: player !== null && player !== undefined
    readonly property bool sonando: hayMusica && player.playbackStatus === Mpris.PlaybackStatus.Playing

    // ── Modo juego (/usr/lib/coucou/modo-juego) ──────────────────────────────
    // Pausa lo de fondo que no hace falta, limpia y comprime la memoria y pone todo al máximo (la
    // barra y el escritorio siguen a la vista); se elige en su vista (opciones). Se lee al abrir el
    // panel y cada 30 s. "pausado" y "aviso": lo que dejó de andar mientras está activo.
    property var juego: ({ activo: false, opciones: {}, libre: 0, liberado: 0, pausado: [], aviso: "" })
    readonly property bool modoJuego: !!juego.activo
    readonly property var lectorJuego: P5Support.DataSource {
        engine: "executable"
        onNewData: (sourceName, data) => {
            try { s.juego = JSON.parse(data["stdout"]) } catch (e) {}
            disconnectSource(sourceName)
        }
    }
    function leerJuego() { lectorJuego.connectSource("/usr/lib/coucou/modo-juego estado") }
    // (el estado cambia enseguida en el panel; el script lo confirma al terminar)
    function alternarJuego() {
        var si = !modoJuego
        var j = JSON.parse(JSON.stringify(juego)); j.activo = si; juego = j
        comando("/usr/lib/coucou/modo-juego " + (si ? "activar" : "desactivar"))
        releerJuego.restart()
    }
    readonly property var releerJuego: Timer { interval: 4000; onTriggered: s.leerJuego() }
    function opcionJuego(clave, si) {
        var j = JSON.parse(JSON.stringify(juego)); j.opciones[clave] = si; juego = j
        comando("/usr/lib/coucou/modo-juego opcion " + citar(clave) + " " + (si ? 1 : 0))
    }

    // ── Abrir programas y comandos ───────────────────────────────────────────
    readonly property var ejecutor: P5Support.DataSource {
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }
    // (sin lo del panel: QT_WAYLAND_SHELL_INTEGRATION=layer-shell lo pone flotando sobre todo, y
    // heredado, Configuración y las demás apps se abrían a pantalla completa y sin poder minimizarse)
    readonly property string limpio: "unset QT_WAYLAND_SHELL_INTEGRATION QML_XHR_ALLOW_FILE_WRITE QML_XHR_ALLOW_FILE_READ; "
    function comando(c) { ejecutor.connectSource(limpio + c) }
    function citar(a) { return "'" + String(a).replace(/'/g, "'\\''") + "'" }
    function abrir(programa, args) { comando([programa].concat(args || []).map(citar).join(" ") + " &") }
    function bloquear() { comando("loginctl lock-session") }
    function apagar() {
        DBus.SessionBus.asyncCall({ service: "org.kde.LogoutPrompt", path: "/LogoutPrompt", iface: "org.kde.LogoutPrompt", member: "promptAll" })
    }
    function proyectar() {
        DBus.SessionBus.asyncCall({ service: "org.kde.kscreen.osdService", path: "/org/kde/kscreen/osdService",
                                    iface: "org.kde.kscreen.osdService", member: "showActionSelector" })
    }

    readonly property var reloj: Timer { interval: 30000; repeat: true; running: true; triggeredOnStart: true
                                   onTriggered: { s.ahora = Date.now(); s.leerJuego() } }
}
