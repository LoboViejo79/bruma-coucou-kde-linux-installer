import QtQuick
import ".."

// Bloque del Centro de control: los botones redondos, los que entren en su lugar (ver abajo).
// Clic: encender/apagar o hacer; clic derecho: sus ajustes (cuando tienen).
Item {
    id: b
    property var sis; property var tema; property int ancho: 2; property int alto: 2
    signal abrir(string vista)
    property var botones: ["juego", "bloquear", "avion", "nocturna", "nomolestar", "captura", "microfono", "tema", "energia"]

    readonly property var catalogo: ({
        juego:      { icono: "applications-games-symbolic", nombre: "Modo juego", en: b.sis.modoJuego,
                      hacer: function () { b.sis.alternarJuego() }, ajustes: function () { b.abrir("juego") } },
        bloquear:   { icono: "system-lock-screen-symbolic", nombre: "Bloquear", en: false,
                      hacer: function () { b.abrir("cerrar"); b.sis.bloquear() } },
        avion:      { icono: "network-flightmode-on-symbolic", nombre: "Modo avión", en: b.sis.avion,
                      hacer: function () { b.sis.ponerAvion(!b.sis.avion) } },
        nocturna:   { icono: "weather-clear-night-symbolic", nombre: "Luz nocturna", en: b.sis.luzNocturna,
                      hacer: function () { b.sis.alternarLuzNocturna() },
                      ajustes: function () { b.abrir("cerrar"); b.sis.abrir("systemsettings", ["kcm_nightlight"]) } },
        nomolestar: { icono: "notifications-disabled-symbolic", nombre: "No molestar", en: b.sis.noMolestar,
                      hacer: function () { b.sis.alternarNoMolestar() },
                      ajustes: function () { b.abrir("cerrar"); b.sis.abrir("systemsettings", ["kcm_notifications"]) } },
        captura:    { icono: "camera-photo-symbolic", nombre: "Captura", en: false,
                      hacer: function () { b.abrir("cerrar"); b.sis.comando("sleep 0.4; spectacle -r") } },
        microfono:  { icono: b.sis.micMudo ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic",
                      nombre: b.sis.micMudo ? "Mic. apagado" : "Micrófono", en: !b.sis.micMudo,
                      hacer: function () { b.sis.silenciarMic() } },
        tema:       { icono: "lighttable-symbolic", nombre: b.tema.oscuro ? "Modo oscuro" : "Modo claro", en: b.tema.oscuro,
                      hacer: function () { b.sis.comando("/usr/lib/coucou/coucou-colors apply --mode " + (b.tema.oscuro ? "light" : "dark")) } },
        energia:    { icono: b.sis.perfil === "power-saver" ? "power-profile-power-saver-symbolic"
                           : (b.sis.perfil === "performance" ? "power-profile-performance-symbolic" : "power-profile-balanced-symbolic"),
                      nombre: b.sis.nombresPerfil[b.sis.perfil] || "Energía", en: b.sis.perfil !== "balanced" && b.sis.perfil !== "",
                      hacer: function () { b.sis.siguientePerfil() }, ajustes: function () { b.abrir("energia") } }
    })

    // Cuántos entran: cada botón pide al menos 40 px (más su nombre debajo) y no pasa de 64; con
    // lugar de sobra quedan más separados, no más grandes. Se muestran en el orden de `botones`.
    readonly property int maxCol: Math.max(1, Math.floor((width - 16) / 76))
    readonly property int maxFil: Math.max(1, Math.floor((height - 12) / 70))
    readonly property int filas: Math.min(maxFil, Math.ceil(lista.length / Math.min(maxCol, lista.length)))
    readonly property int columnas: Math.min(maxCol, Math.ceil(lista.length / filas))
    readonly property var lista: botones.filter(function (x) { return catalogo[x] })
    readonly property var visibles: lista.slice(0, columnas * filas)
    readonly property real tam: Math.max(36, Math.min((width - 16) / columnas - 22, (height - 12) / filas - 26, 64))

    Rectangle { anchors.fill: parent; radius: Math.min(30, height / 2); color: b.tema.vidrio; opacity: 0.6 }
    Grid {
        anchors.centerIn: parent
        columns: b.columnas
        columnSpacing: Math.min(40, (b.width - 16 - b.columnas * (b.tam + 22)) / Math.max(1, b.columnas - 1) + 22)
        rowSpacing: Math.min(24, Math.max(4, (b.height - 12 - b.filas * (b.tam + 18)) / Math.max(1, b.filas)))
        Repeater {
            model: b.visibles
            Redondo {
                required property string modelData
                readonly property var c: b.catalogo[modelData]
                tema: b.tema
                tam: b.tam
                icono: c.icono
                nombre: c.nombre
                encendido: c.en
                onClic: c.hacer()
                onClicDerecho: if (c.ajustes) c.ajustes()
            }
        }
    }
}
