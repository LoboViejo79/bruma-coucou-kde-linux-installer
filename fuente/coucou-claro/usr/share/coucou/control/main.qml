import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.coucou.widgets as W
import "bloques"
import "vistas"

// Coucou: Centro de control. Un panel flotante (arriba a la derecha, o a la izquierda) hecho de
// bloques: música, Wi-Fi, Bluetooth, botones, brillo, volumen, energía… Lo abre /usr/bin/coucou-control
// (Meta+C o el menú); se cierra con Escape o con un clic afuera.
//
// Editar (el lápiz): cada bloque se quita con (−), se arrastra para cambiar el orden y se agranda o
// achica desde la manija de su esquina (medio ancho o entero; más alto o más bajo); "Agregar un
// control" vuelve a poner los quitados. Todo queda en ~/.config/coucou/control.conf.
// Wi-Fi, Bluetooth, Sonido y Energía abren su vista dentro del mismo panel.
Window {
    id: win
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    title: "Centro de control"

    LayerShell.Window.scope: "coucou-control"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    // Desde el botón de la barra (Wi-Fi / volumen / batería): "barra=abajo margen=72 derecha=220"
    // lo apoya sobre la barra, alineado con ese botón. Si no, arriba, del lado elegido.
    function arg(nombre) {
        var a = Qt.application.arguments
        for (var i = 0; i < a.length; i++) if (String(a[i]).indexOf(nombre + "=") === 0) return String(a[i]).slice(nombre.length + 1)
        return ""
    }
    readonly property string barra: arg("barra")                 // "", "abajo" o "arriba"
    readonly property bool desdeAbajo: barra === "abajo"
    readonly property int margenBarra: Math.max(8, parseInt(arg("margen")) || 8)
    readonly property int margenDerecha: Math.max(8, parseInt(arg("derecha")) || 8)
    // Desde la barra se viste como sus paneles: sus colores (fondo1/fondo2: el degradé, borde) y una
    // flechita que apunta al botón (flecha: a cuántos px del borde derecho), en "pico" px de más
    readonly property bool comoBarra: barra !== "" && arg("fondo1") !== ""
    readonly property color barraFondo1: arg("fondo1") || "#EB15284F"
    readonly property color barraFondo2: arg("fondo2") || barraFondo1
    readonly property color barraBorde: arg("borde") || "#C64A90C8"
    readonly property int flecha: parseInt(arg("flecha")) || 40
    readonly property int pico: barra !== "" ? 9 : 0
    LayerShell.Window.anchors: (desdeAbajo ? LayerShell.Window.AnchorBottom : LayerShell.Window.AnchorTop)
                               | (barra === "" && ajustes.lado === "izquierda" ? LayerShell.Window.AnchorLeft : LayerShell.Window.AnchorRight)
    LayerShell.Window.margins.top: barra === "arriba" ? margenBarra : 8
    LayerShell.Window.margins.bottom: desdeAbajo ? margenBarra : 8
    LayerShell.Window.margins.right: barra !== "" ? margenDerecha : 8
    LayerShell.Window.margins.left: 8
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.activateOnShow: true

    // Horizontal: una grilla de columnas (4, 6 u 8 según el ancho elegido) y filas de alto fijo.
    // Cada bloque ocupa las columnas y filas que se le den (entre su mínimo y su máximo).
    readonly property var columnasPorAncho: ({ "estrecho": 4, "normal": 6, "ancho": 8 })
    readonly property int columnas: columnasPorAncho[ajustes.anchoPanel] || 6
    readonly property real celda: 128                       // ancho de una columna
    readonly property real fila: 72                         // alto de una fila
    readonly property real separacion: 12
    width: Math.min(Screen.width - 16, columnas * celda + (columnas - 1) * separacion + 32 + (editando ? 24 : 0))
    // El alto cambia con una animación (de una vista a otra, al editar…): la tarjeta se estira o se
    // encoge suave; la ventana crece enseguida y se achica cuando la tarjeta terminó
    height: altoVentana + pico
    property real contenidoAlto: 600
    readonly property real altoObjetivo: Math.min(Screen.height - 8 - (barra !== "" ? margenBarra : 8), Math.max(320, contenidoAlto + 32))
    property real altoVentana: altoObjetivo
    property real altoTarjeta: altoObjetivo
    property bool animarAlto: false
    Behavior on altoTarjeta { enabled: win.animarAlto; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    onAltoObjetivoChanged: {
        altoTarjeta = altoObjetivo
        if (altoObjetivo >= altoVentana) { achicar.stop(); altoVentana = altoObjetivo }
        else achicar.restart()
    }
    Timer { id: achicar; interval: 320; onTriggered: win.altoVentana = win.altoObjetivo }
    Timer { running: true; interval: 400; onTriggered: win.animarAlto = true }

    Settings {
        id: ajustes
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/coucou/control.conf"
        category: "Panel"
        property string bloques: ""                 // (el panel vertical de antes; ya no se usa)
        property string grilla: ""
        property string anchoPanel: "normal"
        property string lado: "derecha"
        property string estilo: "coucou"
    }

    readonly property var config: ajustes      // (para la vista de ajustes, que tiene una propiedad con ese nombre)
    Sistema { id: sis }

    // ── Colores ──────────────────────────────────────────────────────────────
    readonly property var p: W.Paletas.resolver(ajustes.estilo, null, Kirigami.Theme.highlightColor, Kirigami.Theme.backgroundColor)
    QtObject {
        id: colores                         // (no "tema": los bloques tienen una propiedad con ese nombre)
        readonly property bool oscuro: !win.p.claro
        readonly property color texto: win.p.texto
        readonly property color texto2: Qt.alpha(win.p.texto, 0.62)
        readonly property color vidrio: win.p.claro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.09)
        readonly property color vidrioFuerte: win.p.claro ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.17)
        readonly property color acento: Kirigami.Theme.highlightColor
        readonly property color sobreAcento: W.Paletas.luz(Kirigami.Theme.highlightColor) > 0.6 ? "#1D1B33" : "#FFFFFF"
        readonly property color relleno: win.p.claro ? Kirigami.Theme.highlightColor : Qt.rgba(1, 1, 1, 0.82)
        readonly property color sobreRelleno: win.p.claro ? "#FFFFFF" : "#2B2A33"
    }

    // ── Bloques ──────────────────────────────────────────────────────────────
    // tipo → nombre, icono, componente, de fábrica (columnas × filas), y el mínimo y el máximo de
    // columnas y de filas: más chico no entra lo que muestra; más grande, se ve vacío
    readonly property var tipos: ({
        musica:    { nombre: "Música", icono: "media-playback-start", comp: cMusica, an: 3, al: 2, minAn: 2, maxAn: 6, minAl: 1, maxAl: 4 },
        wifi:      { nombre: "Wi-Fi", icono: "network-wireless", comp: cWifi, an: 2, al: 1, minAn: 1, maxAn: 4, minAl: 1, maxAl: 2 },
        bluetooth: { nombre: "Bluetooth", icono: "network-bluetooth", comp: cBluetooth, an: 2, al: 1, minAn: 1, maxAn: 4, minAl: 1, maxAl: 2 },
        botones:   { nombre: "Botones", icono: "view-grid", comp: cBotones, an: 3, al: 2, minAn: 1, maxAn: 6, minAl: 1, maxAl: 3 },
        brillo:    { nombre: "Brillo", icono: "brightness-high", comp: cBrillo, an: 3, al: 1, minAn: 1, maxAn: 6, minAl: 1, maxAl: 4 },
        volumen:   { nombre: "Volumen", icono: "audio-volume-high", comp: cVolumen, an: 3, al: 1, minAn: 1, maxAn: 6, minAl: 1, maxAl: 4 },
        energia:   { nombre: "Energía", icono: "battery-good", comp: cEnergia, an: 2, al: 1, minAn: 1, maxAn: 4, minAl: 1, maxAl: 2 },
        proyectar: { nombre: "Proyectar", icono: "video-display", comp: cProyectar, an: 2, al: 1, minAn: 1, maxAn: 4, minAl: 1, maxAl: 2 },
        telefono:  { nombre: "Teléfono", icono: "smartphone", comp: cTelefono, an: 2, al: 1, minAn: 1, maxAn: 4, minAl: 1, maxAl: 2 },
        juego:     { nombre: "Modo juego", icono: "applications-games", comp: cJuego, an: 6, al: 1, minAn: 1, maxAn: 6, minAl: 1, maxAl: 2 }
    })
    readonly property var deFabrica: [
        { tipo: "musica", ancho: 3, alto: 2 }, { tipo: "botones", ancho: 3, alto: 2 },
        { tipo: "wifi", ancho: 2, alto: 1 }, { tipo: "bluetooth", ancho: 2, alto: 1 }, { tipo: "energia", ancho: 2, alto: 1 },
        { tipo: "brillo", ancho: 3, alto: 1 }, { tipo: "volumen", ancho: 3, alto: 1 }, { tipo: "juego", ancho: 6, alto: 1 }
    ]
    // Un tamaño dentro de los límites del tipo (y de las columnas del panel)
    function limitarAn(tipo, n) { var t = tipos[tipo]; return Math.max(t.minAn, Math.min(t.maxAn, columnas, Math.round(n))) }
    function limitarAl(tipo, n) { var t = tipos[tipo]; return Math.max(t.minAl, Math.min(t.maxAl, Math.round(n))) }
    Component { id: cMusica; Musica {} }
    Component { id: cWifi; Wifi {} }
    Component { id: cBluetooth; Bluetooth {} }
    Component { id: cBotones; Botones {} }
    Component { id: cBrillo; Brillo {} }
    Component { id: cVolumen; Volumen {} }
    Component { id: cEnergia; Energia {} }
    Component { id: cProyectar; Proyectar {} }
    Component { id: cTelefono; Telefono {} }
    Component { id: cJuego; Juego {} }

    ListModel { id: modelo }
    function cargar(lista) {
        modelo.clear()
        for (var i = 0; i < lista.length; i++)
            if (tipos[lista[i].tipo]) modelo.append({ tipo: lista[i].tipo, ancho: lista[i].ancho, alto: lista[i].alto })
        acomodar()
    }
    function guardar() {
        var l = []
        for (var i = 0; i < modelo.count; i++) { var m = modelo.get(i); l.push({ tipo: m.tipo, ancho: m.ancho, alto: m.alto }) }
        ajustes.grilla = JSON.stringify(l)
    }
    Component.onCompleted: {
        var l = deFabrica
        // (la grilla horizontal se guarda aparte: lo guardado del panel vertical de antes no sirve)
        try { if (ajustes.grilla !== "") l = JSON.parse(ajustes.grilla) } catch (e) {}
        cargar(l)
        var args = Qt.application.arguments
        if (args.indexOf("editar") >= 0) editando = true
        // "coucou-control wifi" (o bluetooth, sonido, energia): abre directo en esa vista
        for (var j = 0; j < args.length; j++)
            if (["wifi", "bluetooth", "sonido", "energia", "juego", "agregar", "ajustes"].indexOf(args[j]) >= 0) { var v = args[j]; Qt.callLater(function () { win.abrirVista(v) }) }
    }

    // Dónde va cada bloque: en orden, en el primer lugar de la grilla donde entra (de arriba abajo,
    // de izquierda a derecha). Fuera de la edición, un bloque que tiene lugar libre a su derecha se
    // estira hasta llenarlo (sin pasar su máximo), para que no queden huecos.
    readonly property real anchoUtil: columnas * celda + (columnas - 1) * separacion
    property var posiciones: []
    function acomodar() {
        var o = editando ? 12 : 0                           // editando, corrido para que se vea el (−)
        var ocupado = [], puestos = [], filas = 0
        function libre(f, c) { return !(ocupado[f] && ocupado[f][c] !== undefined) }
        function entra(f, c, an, al) {
            if (c + an > columnas) return false
            for (var y = f; y < f + al; y++) for (var x = c; x < c + an; x++) if (!libre(y, x)) return false
            return true
        }
        function ocupar(f, c, an, al, i) {
            for (var y = f; y < f + al; y++) { if (!ocupado[y]) ocupado[y] = []; for (var x = c; x < c + an; x++) ocupado[y][x] = i }
            filas = Math.max(filas, f + al)
        }
        for (var i = 0; i < modelo.count; i++) {
            var m = modelo.get(i), an = limitarAn(m.tipo, m.ancho), al = limitarAl(m.tipo, m.alto)
            var listo = false
            for (var f = 0; !listo; f++)
                for (var c = 0; c + an <= columnas && !listo; c++)
                    if (entra(f, c, an, al)) { ocupar(f, c, an, al, i); puestos.push({ f: f, c: c, an: an, al: al }); listo = true }
        }
        if (!editando)
            for (var k = 0; k < puestos.length; k++) {
                var q = puestos[k], max = Math.min(tipos[modelo.get(k).tipo].maxAn, columnas)
                while (q.an < max && q.c + q.an < columnas) {
                    var vacio = true
                    for (var y = q.f; y < q.f + q.al; y++) if (!libre(y, q.c + q.an)) vacio = false
                    if (!vacio) break
                    for (y = q.f; y < q.f + q.al; y++) ocupado[y][q.c + q.an] = k
                    q.an++
                }
            }
        var r = []
        for (var j = 0; j < puestos.length; j++) {
            var p = puestos[j]
            r.push({ x: o + p.c * (celda + separacion), y: o + p.f * (fila + separacion),
                     w: p.an * celda + (p.an - 1) * separacion, h: p.al * fila + (p.al - 1) * separacion, an: p.an, al: p.al })
        }
        posiciones = r
        altoBloques = Math.max(0, filas * (fila + separacion) - separacion)
    }
    onEditandoChanged: acomodar()
    property real altoBloques: 0
    Connections {
        target: modelo
        function onCountChanged() { win.acomodar() }
        function onDataChanged() { win.acomodar() }
        function onRowsMoved() { win.acomodar() }
    }
    onColumnasChanged: acomodar()

    // ── Edición ──────────────────────────────────────────────────────────────
    property bool editando: false
    property int arrastrando: -1
    function terminarEdicion() { editando = false; guardar() }
    // La manija: el tamaño sigue al ratón, de a una columna o una fila
    function ponerTamano(i, an, al) {
        var m = modelo.get(i)
        an = limitarAn(m.tipo, an); al = limitarAl(m.tipo, al)
        if (an !== m.ancho) modelo.setProperty(i, "ancho", an)
        if (al !== m.alto) modelo.setProperty(i, "alto", al)
    }
    // Clic en la manija (sin arrastrar): uno más de ancho; llegado al máximo, vuelve al mínimo y
    // suma una fila (y al llegar a todo, vuelve al más chico)
    function siguienteTamano(i) {
        var m = modelo.get(i), t = tipos[m.tipo]
        var maxAn = Math.min(t.maxAn, columnas), an = m.ancho, al = m.alto
        if (an < maxAn) an++
        else { an = t.minAn; al = al < t.maxAl ? al + 1 : t.minAl }
        ponerTamano(i, an, al)
    }
    function agregar(tipo) {
        var t = tipos[tipo]
        modelo.append({ tipo: tipo, ancho: t.an, alto: t.al })
        guardar()
    }
    function presentes() { var l = []; for (var i = 0; i < modelo.count; i++) l.push(modelo.get(i).tipo); return l }

    // ── Vistas ───────────────────────────────────────────────────────────────
    // Las vistas se abren "desde" lo que se tocó (como las View Transitions de la web): un recuadro
    // crece desde el bloque hasta llenar el panel mientras la vista aparece, y al volver se encoge
    // hasta el mismo bloque. `origen` es ese rectángulo (en coordenadas de la pila).
    property var origen: null
    property var origenes: []
    function abrirDesde(item, v) {
        if (item && v !== "cerrar") {
            var r = item.mapToItem(pila, 0, 0, item.width, item.height)
            origen = { x: r.x, y: r.y, w: r.width, h: r.height, item: item }
        }
        abrirVista(v)
    }
    function volver() {
        if (pila.depth <= 1 || pila.busy) return
        origen = origenes.length ? origenes[origenes.length - 1] : null
        origenes = origenes.slice(0, -1)
        if (origen) morfo.encoger(origen)
        var vista = pila.currentItem, inicioPg = pila.get(0)
        pila.pop()                                          // (primero: así la página del bloque ya se ve)
        if (origen && origen.item) heroe.volar(vista, vista, origen.item, inicioPg, false)
    }
    // Cerrar con un fundido corto
    function cerrar() { if (!saliendo.running) saliendo.start() }
    ParallelAnimation {
        id: saliendo
        NumberAnimation { target: fondo; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: fondo; property: "scale"; to: 0.96; duration: 140; easing.type: Easing.InCubic }
        onFinished: { win.anotarCierre(); Qt.quit() }
    }
    // Deja anotado cuándo se cerró: lo lee coucou-control, así el clic en el botón de la barra que lo
    // cerró (le quitó el foco) no lo vuelve a abrir enseguida
    function anotarCierre() {
        var x = new XMLHttpRequest()
        x.open("PUT", StandardPaths.writableLocation(StandardPaths.RuntimeLocation) + "/coucou-control.cerrado", false)
        try { x.send(String(Date.now())) } catch (e) {}
    }
    function abrirVista(v) {
        if (v === "cerrar") { cerrar(); return }
        if (pila.busy) return
        var c = { wifi: vWifi, bluetooth: vBluetooth, sonido: vSonido, energia: vEnergia, juego: vJuego, agregar: vAgregar, ajustes: vAjustes }[v]
        if (!c) return
        if (!origen) origen = { x: pila.width / 2 - 60, y: 0, w: 120, h: 52 }
        origenes = origenes.concat([origen])
        var desde = origen.item
        pila.push(c, { sis: sis, tema: colores })
        if (desde) heroe.volar(desde, pila, pila.currentItem, pila.currentItem, true)
        morfo.crecer(origen)                                // (después: ya se sabe el alto de la vista)
    }
    Component { id: vWifi; VistaWifi { onVolver: win.volver() } }
    Component { id: vBluetooth; VistaBluetooth { onVolver: win.volver() } }
    Component { id: vSonido; VistaSonido { onVolver: win.volver() } }
    Component { id: vEnergia; VistaEnergia { onVolver: win.volver() } }
    Component { id: vJuego; VistaJuego { onVolver: win.volver() } }
    Component {
        id: vAgregar
        VistaAgregar {
            tipos: win.tipos; presentes: win.presentes()
            onVolver: win.volver()
            onElegir: tipo => { win.agregar(tipo); win.volver() }
        }
    }
    Component {
        id: vAjustes
        VistaAjustes {
            ajustes: win.config
            onVolver: win.volver()
            onRestablecer: { win.cargar(win.deFabrica); win.guardar(); win.volver() }
        }
    }

    // ── La ventana ───────────────────────────────────────────────────────────
    onActiveChanged: if (!active && !editando && visible) cierre.restart()
    Timer { id: cierre; interval: 150; onTriggered: if (!win.active && !win.editando) win.cerrar() }
    Shortcut { sequence: "Escape"; onActivated: { if (pila.depth > 1) win.volver(); else if (win.editando) win.terminarEdicion(); else win.cerrar() } }

    // La flechita que apunta al botón de la barra (como la de sus paneles): un cuadrito girado del
    // que se ve solo la punta
    Item {
        visible: win.comoBarra
        x: fondo.width - win.flecha - width / 2
        y: win.desdeAbajo ? fondo.y + fondo.height - 1 : fondo.y - height + 1
        width: 20; height: win.pico
        clip: true
        opacity: fondo.opacity
        Rectangle {
            width: 14; height: 14; radius: 3
            x: (parent.width - width) / 2
            y: win.desdeAbajo ? -width / 2 - 1 : parent.height - width / 2 + 1
            rotation: 45
            color: win.desdeAbajo ? win.barraFondo2 : win.barraFondo1
            border.width: 1
            border.color: win.barraBorde
        }
        // (tapa el borde del cuadrito que queda adentro del panel)
        Rectangle {
            width: 20; height: 1
            y: win.desdeAbajo ? 0 : parent.height - 1
            color: win.desdeAbajo ? win.barraFondo2 : win.barraFondo1
        }
    }

    W.Tarjeta {
        id: fondo
        width: parent.width
        height: win.altoTarjeta
        // Pegado a la barra de abajo: la tarjeta crece hacia arriba y sale desde el botón
        y: win.desdeAbajo ? win.height - win.pico - height : win.pico
        transformOrigin: win.desdeAbajo ? Item.BottomRight : (win.barra === "arriba" ? Item.TopRight : Item.Center)
        estilo: ajustes.estilo
        imagen: sis.sonando && sis.player.artUrl ? sis.player.artUrl : ""
        desenfoque: 1
        oscurecer: 0.62
        radio: win.comoBarra ? 22 : 30
        grano: !win.comoBarra
        sombra: false                       // la ventana la recortaría (se vería un borde)
        opacity: 0
        scale: win.barra !== "" ? 0.9 : 0.96
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Desde la barra: el fondo de sus paneles (degradé de su tema, borde fino y un brillo arriba)
        Rectangle {
            visible: win.comoBarra
            anchors.fill: parent
            radius: 22
            gradient: Gradient {
                GradientStop { position: 0; color: win.barraFondo1 }
                GradientStop { position: 1; color: win.barraFondo2 }
            }
            border.width: 1
            border.color: win.barraBorde
            Rectangle { x: 18; y: 1; width: parent.width - 36; height: 1; color: Qt.rgba(1, 1, 1, 0.16) }
        }

        // El recuadro que crece desde el bloque (o se encoge hacia él), detrás de las vistas: es como
        // la tarjeta de la vista que se agranda
        Rectangle {
            id: morfo
            x: pila.x; y: pila.y; width: 0; height: 0
            radius: 30
            color: colores.vidrio
            opacity: 0
            visible: opacity > 0
            property real fx: 0; property real fy: 0; property real fw: 0; property real fh: 0
            function crecer(o) {
                anim.stop(); fx = o.x; fy = o.y; fw = o.w; fh = o.h; anim.adentro = false; anim.start()
            }
            function encoger(o) {
                anim.stop(); fx = o.x; fy = o.y; fw = o.w; fh = o.h; anim.adentro = true; anim.start()
            }
            ParallelAnimation {
                id: anim
                property bool adentro: false
                readonly property int ms: adentro ? 280 : 380
                readonly property int curva: adentro ? Easing.InOutCubic : Easing.OutCubic
                NumberAnimation { target: morfo; property: "x"; from: anim.adentro ? pila.x - 16 : pila.x + morfo.fx; to: anim.adentro ? pila.x + morfo.fx : pila.x - 16; duration: anim.ms; easing.type: anim.curva }
                NumberAnimation { target: morfo; property: "y"; from: anim.adentro ? pila.y - 16 : pila.y + morfo.fy; to: anim.adentro ? pila.y + morfo.fy : pila.y - 16; duration: anim.ms; easing.type: anim.curva }
                NumberAnimation { target: morfo; property: "width"; from: anim.adentro ? fondo.width : morfo.fw; to: anim.adentro ? morfo.fw : fondo.width; duration: anim.ms; easing.type: anim.curva }
                NumberAnimation { target: morfo; property: "height"; from: anim.adentro ? fondo.height : morfo.fh; to: anim.adentro ? morfo.fh : win.altoObjetivo; duration: anim.ms; easing.type: anim.curva }
                NumberAnimation { target: morfo; property: "radius"; from: anim.adentro ? 30 : 24; to: anim.adentro ? 24 : 30; duration: anim.ms }
                SequentialAnimation {
                    NumberAnimation { target: morfo; property: "opacity"; from: 0; to: 1; duration: 60 }
                    PauseAnimation { duration: anim.ms - 200 }
                    NumberAnimation { target: morfo; property: "opacity"; to: 0; duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
        StackView {
            id: pila
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            initialItem: inicio
            // La vista nueva sale del bloque tocado: empieza chica sobre él y se agranda hasta su lugar;
            // al volver, hace lo contrario. La página de los bloques se aleja un poco detrás.
            readonly property real s0: 0.55
            readonly property real dx0: win.origen ? (1 - s0) * (win.origen.x + win.origen.w / 2 - width / 2) : 0
            readonly property real dy0: win.origen ? (1 - s0) * (win.origen.y + win.origen.h / 2 - height / 2) : 0
            pushEnter: Transition { ParallelAnimation {
                NumberAnimation { property: "scale"; from: pila.s0; to: 1; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: pila.dx0; to: 0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: pila.dy0; to: 0; duration: 380; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PauseAnimation { duration: 70 }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 230; easing.type: Easing.InOutQuad } } } }
            pushExit: Transition { ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.94; duration: 300; easing.type: Easing.OutCubic } } }
            popEnter: Transition { ParallelAnimation {
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PauseAnimation { duration: 70 }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 230; easing.type: Easing.OutCubic } }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 320; easing.type: Easing.OutQuint } } }
            popExit: Transition { ParallelAnimation {
                NumberAnimation { property: "scale"; to: pila.s0; duration: 280; easing.type: Easing.InOutCubic }
                NumberAnimation { property: "x"; to: pila.dx0; duration: 280; easing.type: Easing.InOutCubic }
                NumberAnimation { property: "y"; to: pila.dy0; duration: 280; easing.type: Easing.InOutCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutQuad } } }
            // Una vista (Wi-Fi, Sonido…) usa el alto de la página de los bloques, entre 380 y 520 px
            // (el panel es apaisado: no se estira hacia arriba de golpe)
            onCurrentItemChanged: {
                if (!currentItem || !currentItem.altoDeseado) return
                win.contenidoAlto = depth > 1 ? Math.max(380, Math.min(520, Math.max(currentItem.altoDeseado * 0.8, get(0).altoDeseado)))
                                              : currentItem.altoDeseado
            }
        }

        // ── Elementos compartidos ("héroes") ──
        // Lo que está en el bloque y también en la vista (el círculo con el ícono y el título, marcados
        // con objectName "heroIcono" y "heroTitulo") viaja de un lugar al otro: cambia de posición,
        // tamaño y color en vez de desaparecer y aparecer. Mientras viaja, los de verdad se ocultan.
        Item {
            id: heroe
            x: pila.x; y: pila.y; width: pila.width; height: pila.height
            z: 5
            property real t: 0
            property bool volando: false
            property var ic: null           // el ícono: a = de dónde sale, b = adónde llega
            property var ti: null           // el título
            property var ocultos: []
            function mezclar(a, b) { return a + (b - a) * t }
            function mezclarColor(a, b) { return Qt.rgba(mezclar(a.r, b.r), mezclar(a.g, b.g), mezclar(a.b, b.b), mezclar(a.a, b.a)) }
            // (los colores se copian: si fueran los del elemento mismo, se perderían al cerrarse su vista)
            function copiarColor(c) { return { r: c.r, g: c.g, b: c.b, a: c.a } }
            function buscar(item, nombre) {
                if (!item || !item.visible) return null
                if (item.objectName === nombre) return item
                for (var i = 0; i < item.children.length; i++) {
                    var r = buscar(item.children[i], nombre)
                    if (r) return r
                }
                return null
            }
            // desde/hacia: dónde buscar cada uno; marcoDesde/marcoHacia: respecto de qué se miden
            // (el de llegada, en el lugar donde va a quedar cuando termine su propia animación)
            function volar(desde, marcoDesde, hacia, marcoHacia, ida) {
                terminar()
                var r = [], nuevoIc = null, nuevoTi = null
                var a = buscar(desde, "heroIcono"), b = buscar(hacia, "heroIcono")
                if (a && b) {
                    var ra = a.mapToItem(marcoDesde, 0, 0, a.width, a.height), rb = b.mapToItem(marcoHacia, 0, 0, b.width, b.height)
                    nuevoIc = { a: { x: ra.x, y: ra.y, w: ra.width, c: copiarColor(a.color), ci: copiarColor(a.colorIcono) },
                                b: { x: rb.x, y: rb.y, w: rb.width, c: copiarColor(b.color), ci: copiarColor(b.colorIcono) },
                                icono: b.children[0] && b.children[0].source ? b.children[0].source : "" }
                    r.push(a, b)
                }
                a = buscar(desde, "heroTitulo"); b = buscar(hacia, "heroTitulo")
                if (a && b) {
                    var ta = a.mapToItem(marcoDesde, 0, 0), tb = b.mapToItem(marcoHacia, 0, 0)
                    // (centrados en su alto: así un texto chico y uno grande se alinean al medio)
                    nuevoTi = { a: { x: ta.x, y: ta.y + (a.height - a.font.pixelSize * 1.3) / 2, p: a.font.pixelSize, w: a.font.weight, c: copiarColor(a.color), txt: a.text },
                                b: { x: tb.x, y: tb.y + (b.height - b.font.pixelSize * 1.3) / 2, p: b.font.pixelSize, w: b.font.weight, c: copiarColor(b.color), txt: b.text } }
                    r.push(a, b)
                }
                if (!r.length) return
                for (var i = 0; i < r.length; i++) r[i].visible = false
                ocultos = r; ic = nuevoIc; ti = nuevoTi; t = 0; volando = true
                vuelo.duration = ida ? 380 : 280
                vuelo.easing.type = ida ? Easing.OutCubic : Easing.InOutCubic
                vuelo.start()
            }
            function terminar() {
                vuelo.stop()
                for (var i = 0; i < ocultos.length; i++) if (ocultos[i]) ocultos[i].visible = true
                ocultos = []; volando = false
            }
            NumberAnimation { id: vuelo; target: heroe; property: "t"; from: 0; to: 1; onFinished: heroe.terminar() }

            Rectangle {
                visible: heroe.volando && heroe.ic !== null
                readonly property var d: heroe.ic || { a: { x: 0, y: 0, w: 0, c: { r: 0, g: 0, b: 0, a: 0 }, ci: { r: 0, g: 0, b: 0, a: 0 } }, b: { x: 0, y: 0, w: 0, c: { r: 0, g: 0, b: 0, a: 0 }, ci: { r: 0, g: 0, b: 0, a: 0 } }, icono: "" }
                x: heroe.mezclar(d.a.x, d.b.x); y: heroe.mezclar(d.a.y, d.b.y)
                width: heroe.mezclar(d.a.w, d.b.w); height: width; radius: width / 2
                color: heroe.mezclarColor(d.a.c, d.b.c)
                Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.46; height: width; source: parent.d.icono; isMask: true; color: heroe.mezclarColor(parent.d.a.ci, parent.d.b.ci) }
            }
            Item {
                visible: heroe.volando && heroe.ti !== null
                readonly property var d: heroe.ti || { a: { x: 0, y: 0, p: 12, w: 400, c: { r: 0, g: 0, b: 0, a: 0 }, txt: "" }, b: { x: 0, y: 0, p: 12, w: 400, c: { r: 0, g: 0, b: 0, a: 0 }, txt: "" } }
                readonly property bool igual: d.a.txt === d.b.txt
                x: heroe.mezclar(d.a.x, d.b.x); y: heroe.mezclar(d.a.y, d.b.y)
                // Los dos textos crecen juntos (miden lo mismo en todo momento): el de salida se va y
                // el de llegada aparece; si dicen lo mismo, se ve uno solo que cambia de tamaño
                W.Texto {
                    transformOrigin: Item.TopLeft
                    text: parent.d.a.txt; font.pixelSize: parent.d.a.p; font.weight: parent.d.a.w; color: heroe.mezclarColor(parent.d.a.c, parent.d.b.c)
                    scale: heroe.mezclar(1, parent.d.b.p / parent.d.a.p)
                    opacity: parent.igual ? (heroe.t < 0.5 ? 1 : 2 - 2 * heroe.t) : Math.max(0, 1 - 1.6 * heroe.t)
                }
                W.Texto {
                    transformOrigin: Item.TopLeft
                    text: parent.d.b.txt; font.pixelSize: parent.d.b.p; font.weight: parent.d.b.w; color: heroe.mezclarColor(parent.d.a.c, parent.d.b.c)
                    scale: heroe.mezclar(parent.d.a.p / parent.d.b.p, 1)
                    opacity: parent.igual ? (heroe.t < 0.5 ? 2 * heroe.t : 1) : Math.max(0, 1.6 * heroe.t - 0.6)
                }
            }
        }
    }

    // La página principal: arriba el estado y los botones (o los de la edición), y los bloques
    Component {
        id: inicio
        Item {
            id: pg
            readonly property real altoDeseado: cabecera.height + 12 + win.altoBloques + (win.editando ? 120 : 0)
            onAltoDeseadoChanged: if (pila.currentItem === pg) win.contenidoAlto = altoDeseado
            Component.onCompleted: win.contenidoAlto = altoDeseado

            Item {
                id: cabecera
                width: parent.width; height: 52
                // Normal: estado y botones
                Row {
                    visible: !win.editando
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Kirigami.Icon { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; isMask: true; color: colores.texto
                                    source: sis.cable && !sis.redWifi ? "network-wired-symbolic" : (sis.wifi ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic") }
                    Kirigami.Icon { visible: sis.bt; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter; isMask: true; color: colores.texto; source: "network-bluetooth-symbolic" }
                    Rectangle {
                        visible: sis.hayBateria
                        anchors.verticalCenter: parent.verticalCenter
                        width: bat.implicitWidth + 16; height: 22; radius: 11
                        color: sis.bateria <= 15 && !sis.cargando ? "#E5484D" : colores.vidrioFuerte
                        W.Texto { id: bat; anchors.centerIn: parent; text: (sis.cargando ? "⚡" : "") + sis.bateria; color: colores.texto; font.pixelSize: 12; font.weight: Font.DemiBold }
                    }
                }
                Row {
                    visible: !win.editando
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Redondo { tam: 40; tema: colores; icono: "document-edit-symbolic"; onClic: win.editando = true }
                    Redondo { tam: 40; tema: colores; icono: "system-shutdown-symbolic"; onClic: { sis.apagar(); win.cerrar() } }
                    Redondo { tam: 40; tema: colores; icono: "configure-symbolic"; onClic: { sis.abrir("win11-settings"); win.cerrar() } }
                }
                // Editando: ajustes del panel y "Listo"
                Rectangle {
                    visible: win.editando
                    anchors.verticalCenter: parent.verticalCenter
                    width: aj.implicitWidth + 44; height: 38; radius: 19
                    color: ajm.containsMouse ? colores.vidrioFuerte : colores.vidrio
                    Kirigami.Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: "configure-symbolic"; isMask: true; color: colores.texto }
                    W.Texto { id: aj; objectName: "heroTitulo"; x: 36; anchors.verticalCenter: parent.verticalCenter; text: "Ajustes del panel"; color: colores.texto; font.pixelSize: 14; font.weight: Font.Medium }
                    MouseArea { id: ajm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.abrirDesde(parent, "ajustes") }
                }
                Rectangle {
                    visible: win.editando
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: listo.implicitWidth + 32; height: 38; radius: 19
                    color: colores.acento
                    W.Texto { id: listo; anchors.centerIn: parent; text: "Listo"; color: colores.sobreAcento; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.terminarEdicion() }
                }
            }
            W.Texto {
                visible: win.editando
                anchors { top: cabecera.bottom; horizontalCenter: parent.horizontalCenter }
                text: "Arrastra un bloque para cambiar el orden. Arrastra la manija de su esquina para hacerlo más grande o más chico."
                color: colores.texto2; font.pixelSize: 12
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            }

            Flickable {
                id: lista
                anchors { left: parent.left; right: parent.right; top: cabecera.bottom; topMargin: win.editando ? 40 : 12; bottom: parent.bottom }
                contentHeight: win.altoBloques + (win.editando ? 96 : 0)
                clip: true
                interactive: win.arrastrando < 0 && contentHeight > height
                Behavior on anchors.topMargin { NumberAnimation { duration: 180 } }

                Repeater {
                    model: modelo
                    delegate: Item {
                        id: bloque
                        required property int index
                        required property string tipo
                        required property int ancho
                        required property int alto
                        readonly property var pos: win.posiciones[index] || { x: 0, y: 0, w: 0, h: 0, an: 1, al: 1 }
                        readonly property bool moviendo: win.arrastrando === index
                        readonly property var t: win.tipos[tipo]
                        readonly property bool redimensionable: Math.min(t.maxAn, win.columnas) > t.minAn || t.maxAl > t.minAl
                        property real dx: 0
                        property real dy: 0
                        x: moviendo ? dx : pos.x
                        y: moviendo ? dy : pos.y
                        width: pos.w; height: pos.h
                        z: moviendo ? 10 : 0
                        scale: moviendo ? 1.03 : 1
                        Behavior on x { enabled: !bloque.moviendo; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on y { enabled: !bloque.moviendo; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: bloque.t.comp
                            onLoaded: {
                                item.sis = sis; item.tema = colores
                                item.ancho = Qt.binding(function () { return bloque.pos.an || bloque.ancho })
                                item.alto = Qt.binding(function () { return bloque.pos.al || bloque.alto })
                                item.abrir.connect(function (v) { win.abrirDesde(bloque, v) })
                            }
                            enabled: !win.editando
                            opacity: win.editando ? 0.92 : 1
                        }

                        // ── Lo de editar ──
                        Rectangle {
                            visible: win.editando
                            anchors.fill: parent; anchors.margins: -4
                            radius: Math.min(34, height / 2 + 4)
                            color: "transparent"
                            border.width: 2; border.color: Qt.alpha(colores.texto, 0.35)
                        }
                        MouseArea {
                            visible: win.editando
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property point inicio
                            onPressed: mouse => {
                                inicio = Qt.point(mouse.x, mouse.y)
                                bloque.dx = bloque.pos.x; bloque.dy = bloque.pos.y
                                win.arrastrando = bloque.index
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                var p = mapToItem(lista.contentItem, mouse.x, mouse.y)
                                bloque.dx = p.x - inicio.x; bloque.dy = p.y - inicio.y
                                // ¿Sobre qué bloque está? Ahí va
                                for (var i = 0; i < win.posiciones.length; i++) {
                                    var r = win.posiciones[i]
                                    if (i !== bloque.index && p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h) {
                                        modelo.move(bloque.index, i, 1)
                                        win.arrastrando = i
                                        break
                                    }
                                }
                            }
                            onReleased: win.arrastrando = -1
                            onCanceled: win.arrastrando = -1
                        }
                        // Quitar
                        Rectangle {
                            visible: win.editando
                            x: -10; y: -10
                            width: 26; height: 26; radius: 13
                            color: "#E5484D"
                            border.width: 2; border.color: "#FFFFFF"
                            Rectangle { anchors.centerIn: parent; width: 11; height: 2.5; radius: 1; color: "#FFFFFF" }
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: modelo.remove(bloque.index) }
                        }
                        // Mientras se cambia el tamaño: cuánto ocupa (columnas × filas)
                        Rectangle {
                            visible: win.editando && manija.pressed
                            anchors.centerIn: parent
                            width: medida.implicitWidth + 24; height: 32; radius: 16
                            color: colores.acento
                            W.Texto { id: medida; anchors.centerIn: parent; text: bloque.ancho + " × " + bloque.alto; color: colores.sobreAcento; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                        // La manija del tamaño: arrastrarla agranda o achica de a una columna (a los
                        // lados) o una fila (arriba/abajo), siguiendo al ratón; un clic, el siguiente
                        Item {
                            visible: win.editando && bloque.redimensionable
                            x: parent.width - 30; y: parent.height - 30
                            width: 40; height: 40
                            Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var g = getContext("2d"); g.reset()
                                    g.strokeStyle = "#FFFFFF"; g.lineWidth = 4; g.lineCap = "round"
                                    g.beginPath(); g.arc(4, 4, 22, 0.15, Math.PI / 2 - 0.15); g.stroke()
                                }
                            }
                            MouseArea {
                                id: manija
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.SizeFDiagCursor
                                preventStealing: true
                                property point ini
                                property int an0
                                property int al0
                                property bool movio: false
                                onPressed: mouse => {
                                    ini = mapToItem(lista.contentItem, mouse.x, mouse.y)
                                    an0 = bloque.pos.an; al0 = bloque.pos.al; movio = false
                                }
                                onPositionChanged: mouse => {
                                    if (!pressed) return
                                    var p = mapToItem(lista.contentItem, mouse.x, mouse.y)
                                    var dx = p.x - ini.x, dy = p.y - ini.y
                                    if (Math.abs(dx) > 8 || Math.abs(dy) > 8) movio = true
                                    if (!movio) return
                                    win.ponerTamano(bloque.index, an0 + Math.round(dx / (win.celda + win.separacion)),
                                                    al0 + Math.round(dy / (win.fila + win.separacion)))
                                }
                                onReleased: if (!movio) win.siguienteTamano(bloque.index)
                            }
                        }
                    }
                }
                // Agregar un control
                Rectangle {
                    visible: win.editando
                    y: win.altoBloques + 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ag.implicitWidth + 50; height: 42; radius: 21
                    color: agm.containsMouse ? colores.vidrioFuerte : colores.vidrio
                    Kirigami.Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; source: "list-add-symbolic"; isMask: true; color: colores.texto }
                    W.Texto { id: ag; objectName: "heroTitulo"; x: 40; anchors.verticalCenter: parent.verticalCenter; text: "Agregar un control"; color: colores.texto; font.pixelSize: 14 }
                    MouseArea { id: agm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.abrirDesde(parent, "agregar") }
                }
            }
        }
    }
}
