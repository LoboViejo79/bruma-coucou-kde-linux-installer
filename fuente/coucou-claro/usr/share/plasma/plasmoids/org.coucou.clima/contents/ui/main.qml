import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.coucou.widgets as C

// Coucou: Clima pixel. La temperatura de ahora y la máxima de los próximos tres días, sobre un
// paisaje de pixeles que cambia con el tiempo y la hora (atardecer, nublado, lluvia, nieve, noche).
// Los datos son de Open-Meteo (gratis, sin cuenta); el lugar, la ciudad de la configuración o,
// si está vacía, el que se deduce de la conexión. Se actualiza cada 30 minutos.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property var actual: null          // { temp, codigo, dia }
    property var dias: []              // [{ nombre, max, codigo }]
    property string error: ""
    readonly property bool f: Plasmoid.configuration.fahrenheit

    function pedir(url, listo) {
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            if (x.status === 200) { try { listo(JSON.parse(x.responseText)); return } catch (e) {} }
            root.error = "Sin conexión"
        }
        x.open("GET", url); x.send()
    }
    // 1. El lugar: la ciudad elegida (se busca una vez), o el de la conexión
    function actualizar() {
        var c = Plasmoid.configuration
        if (c.ciudad.trim() !== "" && c.nombreLugar !== c.ciudad.trim()) {
            pedir("https://geocoding-api.open-meteo.com/v1/search?count=1&language=es&name=" + encodeURIComponent(c.ciudad.trim()), function (d) {
                if (!d.results || !d.results.length) { root.error = "No encontré esa ciudad"; return }
                c.latitud = d.results[0].latitude; c.longitud = d.results[0].longitude; c.nombreLugar = c.ciudad.trim()
                clima()
            })
        } else if (c.ciudad.trim() === "" && (c.latitud > 90 || c.nombreLugar !== "")) {
            pedir("http://ip-api.com/json/?fields=status,lat,lon,city", function (d) {
                if (d.status !== "success") { root.error = "Sin ubicación"; return }
                c.latitud = d.lat; c.longitud = d.lon; c.nombreLugar = ""
                clima()
            })
        } else clima()
    }
    // 2. El clima de ese lugar
    function clima() {
        var c = Plasmoid.configuration
        pedir("https://api.open-meteo.com/v1/forecast?latitude=" + c.latitud + "&longitude=" + c.longitud +
              "&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,weather_code&timezone=auto&forecast_days=4" +
              (root.f ? "&temperature_unit=fahrenheit" : ""), function (d) {
            root.error = ""
            root.actual = { temp: Math.round(d.current.temperature_2m), codigo: d.current.weather_code, dia: d.current.is_day === 1 }
            var l = []
            var nombres = ["DOM", "LUN", "MAR", "MIE", "JUE", "VIE", "SAB"]
            for (var i = 1; i < 4 && i < d.daily.time.length; i++) {
                var fecha = new Date(d.daily.time[i] + "T12:00:00")
                l.push({ nombre: nombres[fecha.getDay()], max: Math.round(d.daily.temperature_2m_max[i]), codigo: d.daily.weather_code[i] })
            }
            root.dias = l
        })
    }
    Timer { interval: 30 * 60 * 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.actualizar() }
    Connections {
        target: Plasmoid.configuration
        function onCiudadChanged() { root.actualizar() }
        function onFahrenheitChanged() { root.clima() }
    }

    // Códigos de Open-Meteo → palabra y tipo de paisaje
    function tipo(c) {
        if (c === 0 || c === 1) return "sol"
        if (c === 2 || c === 3) return "nubes"
        if (c === 45 || c === 48) return "niebla"
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "lluvia"
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "nieve"
        if (c >= 95) return "tormenta"
        return "nubes"
    }
    function palabra(c) {
        return ({ sol: c === 0 ? "Despejado" : "Soleado", nubes: c === 2 ? "Algo nublado" : "Nublado", niebla: "Niebla",
                  lluvia: "Lluvia", nieve: "Nieve", tormenta: "Tormenta" })[tipo(c)]
    }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: "original"            // el paisaje es el fondo
        original: ({ arriba: "#3A2412", abajo: "#2A1A0C", acento: "#FFFFFF", manchas: [], texto: "#FFFFFF" })
        grano: false

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            // El paisaje: cielo en franjas, sol o luna, montañas, agua con reflejos (y lluvia o nieve)
            C.Lienzo {
                id: paisaje
                k: e.k
                width: 170; height: 170
                readonly property string clase: root.actual ? root.tipo(root.actual.codigo) : "sol"
                readonly property bool noche: root.actual ? !root.actual.dia : false
                onClaseChanged: repintar()
                onNocheChanged: repintar()
                onDibujar: g => {
                    var b = 3.4                                   // tamaño del "pixel" del paisaje
                    function px(x, y, c) { g.fillStyle = c; g.fillRect(Math.floor(x / b) * b, Math.floor(y / b) * b, b + 0.5, b + 0.5) }
                    var cielos = {
                        sol: ["#5B3417", "#6E4020", "#8A5229", "#A66636", "#B97A45"],
                        nubes: ["#3D3F45", "#4A4D54", "#585B63", "#666A72", "#73777F"],
                        niebla: ["#6B6E73", "#7A7D82", "#888B90", "#96999E", "#A3A6AB"],
                        lluvia: ["#22303D", "#2A3A49", "#334556", "#3D5163", "#475C6F"],
                        nieve: ["#7C8796", "#8B96A4", "#9AA4B1", "#A9B2BE", "#B8C0CB"],
                        tormenta: ["#1C1F2A", "#232736", "#2B3042", "#33394E", "#3B425A"]
                    }
                    var cielo = noche ? ["#0B1026", "#111838", "#17204A", "#1E295C", "#25326E"] : cielos[clase]
                    for (var i = 0; i < 5; i++) { g.fillStyle = cielo[i]; g.fillRect(0, i * 22, 170, 23) }
                    // Sol o luna (detrás de las montañas): solo con el cielo despejado
                    if (clase === "sol") {
                        var cx = 110, cy = 92, r = 26
                        for (var y = cy - r; y < cy + r; y += b)
                            for (var x = cx - r; x < cx + r; x += b)
                                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) < r * r) px(x, y, noche ? "#D9DDE8" : "#D98E52")
                    }
                    if (noche && clase === "sol") for (var s = 0; s < 22; s++) px((s * 53) % 170, (s * 29) % 90, "#E8ECF8")
                    // Montañas: dos capas
                    function sierra(base, alto, paso, color, fase) {
                        for (var x = 0; x < 170; x += b) {
                            var h = alto * (0.5 + 0.5 * Math.sin((x + fase) / paso)) * (0.7 + 0.3 * Math.sin((x + fase) / (paso * 0.37)))
                            for (var y = base - h; y < base + 2; y += b) px(x, y, color)
                        }
                    }
                    var oscuro = noche ? 0.45 : (clase === "sol" ? 1 : 0.75)
                    sierra(118, 26, 22, Qt.darker("#5D6B3A", 1 / oscuro + 0.3), 10)
                    sierra(122, 16, 13, Qt.darker("#3E4A26", 1 / oscuro + 0.3), 40)
                    // Agua y reflejos
                    g.fillStyle = noche ? "#0F1730" : Qt.darker(cielo[3], 1.25); g.fillRect(0, 120, 170, 50)
                    for (var r2 = 0; r2 < 14; r2++) px(20 + (r2 * 37) % 130, 126 + (r2 * 13) % 40, Qt.alpha(noche ? "#D9DDE8" : cielo[4], 0.55))
                    // Lluvia o nieve
                    if (clase === "lluvia" || clase === "tormenta")
                        for (var d = 0; d < 16; d++) { var lx = 90 + (d * 47) % 80, ly = (d * 31) % 115; px(lx, ly, Qt.alpha("#9FB4CC", 0.7)); px(lx - b, ly + b, Qt.alpha("#9FB4CC", 0.7)) }
                    if (clase === "nieve") for (var n = 0; n < 20; n++) px(85 + (n * 41) % 85, (n * 23) % 115, Qt.alpha("#FFFFFF", 0.85))
                    // Un velo abajo, para que se lean los días
                    var vel = g.createLinearGradient(0, 100, 0, 170)
                    vel.addColorStop(0, "rgba(0,0,0,0)"); vel.addColorStop(1, "rgba(0,0,0,0.45)")
                    g.fillStyle = vel; g.fillRect(0, 100, 170, 70)
                }
            }

            C.PixelTexto {
                k: e.k; x: 16; y: 16; px: 5.2
                text: root.actual ? root.actual.temp + "°" : (root.error !== "" ? "--°" : "..")
                color: "#FFFFFF"
            }
            Row {
                x: 16; y: 62; spacing: 6
                C.PixelTexto {
                    k: e.k; px: 1.9
                    text: root.error !== "" ? root.error : (root.actual ? root.palabra(root.actual.codigo) : "Cargando")
                    color: "#FFFFFF"
                }
            }
            C.PixelTexto {
                visible: Plasmoid.configuration.nombreLugar !== ""
                k: e.k; x: 16; y: 78; px: 1.3
                text: Plasmoid.configuration.nombreLugar
                color: Qt.rgba(1, 1, 1, 0.7)
            }
            Row {
                x: 16; y: 124; spacing: 18
                Repeater {
                    model: root.dias
                    Column {
                        required property var modelData
                        spacing: 5
                        C.PixelTexto { k: e.k; px: 1.6; text: modelData.nombre; color: Qt.rgba(1, 1, 1, 0.75) }
                        C.PixelTexto { k: e.k; px: 2.1; text: modelData.max + "°"; color: "#FFFFFF" }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; onDoubleClicked: root.actualizar() }
    }
}
