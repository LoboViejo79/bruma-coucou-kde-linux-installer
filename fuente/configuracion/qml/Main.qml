import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "Pages.js" as P

// Configuración de Windows 11: ventana sin marco con barra de título propia
// (← Configuración · buscador centrado · botones de ventana), panel de navegación y contenido.
ApplicationWindow {
    id: win
    width: 1280
    height: 820
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "Configuración"
    flags: Qt.Window | Qt.FramelessWindowHint

    // Paleta de Configuración de Windows 11 (fondo Mica aproximado), o la de
    // Coucou (vidrio violeta, Inter, esquinas redondas) con el tema Coucou Code
    property bool coucou: backend.currentLookAndFeel() === "org.coucou.code"
    Timer { interval: 1500; repeat: true; running: true; onTriggered: win.coucou = backend.currentLookAndFeel() === "org.coucou.code" }
    // Coucou también tiene su versión clara (lavanda y blanco), como Windows
    readonly property bool cLight: coucou && backend.mode === "light"
    readonly property bool dark: coucou ? !cLight : backend.mode === "dark"
    property color accent: backend.uiAccent()
    readonly property color bg: coucou ? (cLight ? "#F4F2FF" : "#110F29") : dark ? "#202020" : "#F3F3F3"
    readonly property color cardBg: coucou ? (cLight ? "#FFFFFF" : "#1E1B44") : dark ? "#2B2B2B" : "#FBFBFB"
    readonly property color cardHover: coucou ? (cLight ? "#F1EEFE" : "#272357") : dark ? "#323232" : "#F6F6F6"
    readonly property color cardBorder: coucou ? (cLight ? "#E2DDF8" : "#2E2A66") : dark ? "#1D1D1D" : "#E5E5E5"
    readonly property color navHover: coucou ? (cLight ? "#EEEBFC" : "#1E1B44") : dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color navSelected: coucou ? (cLight ? "#E6E1FB" : "#272357") : dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color text: coucou ? (cLight ? "#1D1B33" : "#FFFFFF") : dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: coucou ? (cLight ? "#5F5A8A" : "#B9B5E0") : dark ? "#C5C5C5" : "#5F5F5F"
    // Piezas del diseño de Coucou (barra lateral flotante, panel de vidrio, botones redondos)
    readonly property color cGrad0: cLight ? "#F7F5FF" : "#1B1844"
    readonly property color cGrad1: cLight ? "#E7E2FB" : "#0B0A20"
    readonly property color cSide: cLight ? "#D9FFFFFF" : "#B31E1B44"
    readonly property color cSideBorder: cLight ? "#E0DAF7" : "#332E6A"
    readonly property color cRaised: cLight ? "#F1EEFE" : "#221F4E"
    readonly property color cRaisedHover: cLight ? "#E8E4FB" : "#2A2660"
    readonly property color cInput: cLight ? "#F1EEFE" : "#1A1840"
    readonly property color cInputFocus: cLight ? "#FFFFFF" : "#2E2A66"
    readonly property color cRowHover: cLight ? "#123C32A0" : "#1AFFFFFF"
    readonly property color cBtn: cLight ? "#EEEBFC" : "#1E1B44"
    readonly property color cBtnHover: cLight ? "#E2DDF8" : "#2E2A66"
    readonly property color cPanel: cLight ? "#B3FFFFFF" : "#80110F29"
    readonly property color cPanelBorder: cLight ? "#E0DAF7" : "#24FFFFFF"
    readonly property int cardRadius: coucou ? 14 : 4
    readonly property string fontFamily: coucou ? "Inter" : "Selawik"
    readonly property bool maximized: visibility === Window.Maximized

    font.family: fontFamily
    font.pixelSize: 14
    // Con Coucou y la transparencia activada: ventana de vidrio (KWin desenfoca lo de atrás)
    readonly property bool glass: coucou && backend.transparency
    onGlassChanged: backend.setGlass(win, glass)
    color: glass ? "transparent" : bg
    background: Rectangle {
        color: win.glass ? "transparent" : win.bg
        radius: win.glass && !win.maximized ? 12 : 0
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: win.coucou
            gradient: Gradient {
                GradientStop { position: 0; color: win.glass ? Qt.alpha(win.cGrad0, win.cLight ? 0.72 : 0.78) : win.cGrad0 }
                GradientStop { position: 1; color: win.glass ? Qt.alpha(win.cGrad1, win.cLight ? 0.8 : 0.86) : win.cGrad1 }
            }
        }
    }

    Connections {
        target: backend
        function onThemeChanged() { win.accent = backend.uiAccent() }
    }

    // ── Coucou Code: todo con la interfaz de Coucou ───────────────────────
    readonly property string coucouId: "org.coucou.code"
    readonly property string coucouAccent: "#6574F6"
    function applyCoucouCode(mode) {
        if (coucou) return
        backend.rememberTheme()
        backend.applyLookAndFeel(coucouId)
        backend.setCoucouTheme(mode === "light" ? "light" : "dark", coucouAccent, true)
        backend.launch("coucou-launch", ["--taskbar", "coucou"])
        backend.launch("/usr/lib/coucou/lockscreen-sync", ["on"])
        const wall = String(backend.wallpaper)
        for (const key of ["Image", "PreviewImage"])
            backend.kconfigWrite("kscreenlockerrc", ["Greeter", "Wallpaper", "org.kde.image", "General"], key, wall)
        backend.launch("/usr/lib/coucou/admin", ["/usr/lib/coucou/login-theme", "coucou-login", wall])
        coucou = true
    }
    // Modo, énfasis y transparencia: con Coucou Code los aplica el motor de Coucou (un solo
    // cambio con fundido, sin el script de Windows que repintaba todo dos veces)
    function setAppearance(mode, accent, transparency) {
        if (coucou) backend.setCoucouTheme(mode, accent, transparency)
        else backend.setTheme(mode, accent, transparency)
    }
    // Al salir: vuelven la pantalla de bloqueo, el inicio de sesión y el color de antes
    function leaveCoucouCode() {
        if (!coucou) return
        backend.launch("/usr/lib/coucou/lockscreen-sync", ["off"])
        backend.launch("/usr/lib/coucou/coucou-colors", ["off"])
        backend.launch("/usr/lib/coucou/admin", ["/usr/lib/coucou/login-theme", "default"])
        const before = backend.rememberedTheme()
        if (before.accent) backend.setTheme(before.mode, before.accent, before.transparency)
        coucou = false
    }

    // Con Coucou no se habla de Windows: los nombres de marca se muestran con su equivalente.
    // (Solo al mostrar: las rutas internas, p. ej. win11-settings "update", siguen igual.)
    readonly property var coucouNames: ({ "Windows Update": "Actualizaciones", "Microsoft Store": "Tienda" })
    // Nombres sin marcas en todos los diseños (también el de Windows 11)
    function brand(t) { return coucouNames[t] ? coucouNames[t] : t }

    // La biblioteca de páginas oculta lo que este equipo no tiene (batería, táctil, módem...)
    readonly property bool hardwareReady: P.setHardware(function (w) { return backend.hasHardware(w) })

    // Navegación: categoría + pila de subpáginas
    property string currentId: startPage && P.byId(startPage.split("/")[0]) ? startPage.split("/")[0] : "home"
    property var crumbs: []          // [{page, title, list}]
    property string search: ""
    // La página actual puede quedarse el "atrás" (p. ej. subpáginas de un módulo de KDE)
    property var backHook: null
    // La tarjeta que se tocó (su título viaja al de la página que abre; ver content)
    property var heroTocado: null
    onHeroTocadoChanged: if (heroTocado) olvidarTocado.restart()
    Timer { id: olvidarTocado; interval: 600; onTriggered: win.heroTocado = null }   // (si no abrió nada)

    function openCategory(id) { currentId = id; crumbs = []; search = ""; searchField.text = "" }
    function openSub(page, title, list) { crumbs = crumbs.concat([{ page: page, title: title, list: list }]) }
    function back() {
        if (backHook && backHook()) return
        if (search !== "") { searchField.text = ""; return }
        if (crumbs.length) crumbs = crumbs.slice(0, crumbs.length - 1)
        else if (currentId !== "home") currentId = "home"
    }
    function popTo(depth) { crumbs = crumbs.slice(0, depth) }   // 0 = volver a la categoría
    readonly property var pathParts: [{ title: brand(P.byId(currentId).title) }].concat(crumbs.map(function (c) { return { title: brand(c.title) } }))
    readonly property bool canGoBack: crumbs.length > 0 || search !== "" || currentId !== "home"

    function activate(item) {
        if (search !== "") { search = ""; searchField.text = "" }
        if (item.page && item.items) openSub(item.page, item.title, item)
        else if (item.items) openSub("list", item.title, item)
        else if (item.page) openSub(item.page, item.title)
        else if (item.kcm && backend.canEmbed(item.kcm)) openSub("kcm", item.title, item)
        else if (item.kcm) backend.openKcm(item.kcm)
        else if (item.action === "editpanel") backend.editPanel()
        else if (item.action) backend.launch(item.action)
    }
    // Abre un elemento por su ruta de títulos dentro de una categoría: openPath("system", ["Sonido"])
    function openPath(catId, titles) {
        openCategory(catId)
        var list = P.byId(catId).items
        for (var i = 0; i < titles.length && list; ++i) {
            var it = list.filter(function (x) { return x.title === titles[i] })[0]
            if (!it) break
            activate(it)
            list = it.items
        }
    }

    // Ruta directa: win11-settings "system/Acerca de", "colors", "kcm:kcm_mouse"…
    function navigate(page) {
        if (!page) return
        var parts = page.split("/")
        if (parts.length > 1 && P.byId(parts[0])) openPath(parts[0], parts.slice(1))
        else if (P.byId(page)) { crumbs = []; currentId = page }
        else if (page === "colors") { crumbs = []; currentId = "personalization"; openSub("colors", "Colores") }
        else if (page === "installed") { crumbs = []; currentId = "apps"; openSub("installed", "Aplicaciones instaladas") }
        else if (page.indexOf("kcm:") === 0) { var k = page.slice(4); openSub("kcm", k, { kcm: k, title: k }) }
    }
    Component.onCompleted: {
        backend.setGlass(win, glass)
        navigate(startPage)
    }
    // Abierta otra vez desde otro lado: esta misma ventana, al frente, en esa página
    Connections {
        target: backend
        function onOpenRequested(page) {
            win.navigate(page)
            backend.raise(win)
        }
    }

    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; onActivated: win.back() }
    Shortcut { sequence: "Ctrl+F"; onActivated: win.coucou ? coucouSearch.forceActiveFocus() : searchField.forceActiveFocus() }
    Shortcut { sequence: "Escape"; enabled: win.search !== ""; onActivated: searchField.text = "" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !win.coucou

        // ---------- Barra de título ----------
        Item {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            // Arrastrar para mover; doble clic para maximizar
            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler {
                onDoubleTapped: win.maximized ? win.showNormal() : win.showMaximized()
            }

            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                ToolButton {
                    flat: true
                    enabled: win.canGoBack
                    opacity: enabled ? 1 : 0.35
                    onClicked: win.back()
                    implicitWidth: 40; implicitHeight: 32
                    contentItem: Item { FluentIcon { anchors.centerIn: parent; name: "back"; size: 16; stroke: 1.4 } }
                }
                Label { text: "Configuración"; font.pixelSize: 12; color: win.text }
            }

            TextField {
                id: searchField
                anchors.centerIn: parent
                width: Math.min(520, parent.width - 380)
                height: 34
                placeholderText: "Buscar una configuración"
                leftPadding: 38
                onTextChanged: win.search = text
                FluentIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 15
                    stroke: 1.6
                    color: win.text
                }
            }

            CaptionButtons {
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---------- Panel de navegación ----------
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.maximumWidth: 320
                Layout.fillHeight: true
                Layout.leftMargin: 8
                spacing: 2

                // Tarjeta del usuario (abre "Tu información")
                Rectangle {
                    Layout.fillWidth: true
                    Layout.rightMargin: 12
                    Layout.bottomMargin: 18
                    implicitHeight: 84
                    radius: 6
                    color: userArea.containsMouse ? win.navHover : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 14
                        Rectangle {
                            width: 64; height: 64; radius: 32
                            color: backend.sysInfo.avatar ? "transparent" : (win.dark ? "#3A3A3A" : "#D8D8D8")
                            Image {
                                anchors.fill: parent
                                source: backend.sysInfo.avatar ? "image://avatar/" + encodeURIComponent(backend.sysInfo.avatar) : ""
                                visible: backend.sysInfo.avatar !== ""
                                sourceSize: Qt.size(128, 128)
                            }
                            FluentIcon {
                                anchors.centerIn: parent
                                visible: backend.sysInfo.avatar === ""
                                name: "user"
                                size: 34
                                color: win.subtext
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: (backend.sysInfo.fullName || "").toUpperCase()
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                color: win.text
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "Cuenta local · " + backend.sysInfo.user
                                font.pixelSize: 12
                                color: win.text
                                opacity: 0.85
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        id: userArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.openPath("accounts", ["Tu información"])
                    }
                }

                ListView {
                    id: nav
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.rightMargin: 12
                    clip: true
                    spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: P.pages
                    delegate: NavItem {
                        width: nav.width
                        title: modelData.title
                        iconName: modelData.icon
                        selected: win.search === "" && win.currentId === modelData.id
                        onClicked: win.openCategory(modelData.id)
                    }
                    footer: Item {
                        width: nav.width; height: 56
                        NavItem {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            title: "Más opciones (KDE)"
                            iconName: "preferences-system"
                            onClicked: backend.launch("systemsettings")
                        }
                    }
                }
            }

            // ---------- Contenido ----------
            Item {
                id: winSlot
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Configuración se actualizó mientras estaba abierta: un clic y abre la nueva versión
                // (si no, seguía mostrando lo de antes, sin los botones nuevos)
                Rectangle {
                    id: updatedBanner
                    property bool on: false
                    z: 50
                    visible: on
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: updRow.implicitWidth + 28
                    height: 46
                    radius: 23
                    color: win.accent
                    Timer {
                        interval: 4000; repeat: true; running: !updatedBanner.on
                        onTriggered: updatedBanner.on = backend.outdated()
                    }
                    RowLayout {
                        id: updRow
                        anchors.centerIn: parent
                        spacing: 12
                        Label { text: "Configuración se actualizó"; color: "#FFFFFF"; font.weight: Font.DemiBold }
                        Button {
                            text: "Reiniciar"
                            onClicked: {
                                var path = [win.currentId].concat(win.crumbs.map(function (c) { return c.title })).join("/")
                                backend.restartSelf(path)
                            }
                        }
                    }
                }

                // El contenido, con transición entre páginas (como las View Transitions de la web): la
                // página nueva entra mientras la anterior se va, las dos a la vez. Hacia adentro (abrir
                // una sub-página) entra desde la derecha y la anterior se corre a la izquierda; hacia
                // atrás, al revés; otra categoría o la búsqueda, sube con un fundido. Hay dos capas que
                // se turnan: cada una guarda la categoría y sub-página que muestra, así la que se va no
                // cambia mientras se va.
                Item {
                    id: content
                    // Una sola zona de contenido: pasa al diseño de Coucou cuando está activo
                    parent: win.coucou ? coucouSlot : winSlot
                    anchors.fill: parent
                    anchors.topMargin: 6
                    clip: true
                    property var category: P.byId(win.currentId)
                    property var sub: win.crumbs.length ? win.crumbs[win.crumbs.length - 1] : null
                    readonly property string clave: win.search !== "" ? "?buscar"
                        : win.currentId + "/" + win.crumbs.map(function (c) { return c.title }).join("/")
                    readonly property int profundidad: win.search !== "" ? -1 : win.crumbs.length
                    property int profundidadAntes: 0
                    property var activa: null
                    function pagina() {
                        if (win.search !== "") return searchPage
                        if (sub) {
                            if (sub.page === "list") return linksPage
                            if (sub.page === "colors") return colorsPage
                            if (sub.page === "taskbar") return taskbarPage
                            if (sub.page === "themes") return themesPage
                            if (sub.page === "icons") return iconsPage
                            if (sub.page === "widgets") return widgetsPage
                            if (sub.page === "installed") return appsPage
                            if (sub.page === "clipboard") return clipboardPage
                            if (sub.page === "kcm") return kcmPage
                        }
                        switch (category.type) {
                        case "home": return homePage
                        case "system": return systemPage
                        case "personalization": return personalizationPage
                        case "update": return updatePage
                        case "coucou": return coucouPage
                        default: return linksPage
                        }
                    }
                    property string claveCargada: "\u0000"
                    function cambiar() {
                        if (clave === claveCargada) return
                        claveCargada = clave
                        var vieja = activa, nueva = activa === capaA ? capaB : capaA
                        var dir = profundidad < 0 || profundidadAntes < 0 ? 0 : (profundidad > profundidadAntes ? 1 : (profundidad < profundidadAntes ? -1 : 0))
                        profundidadAntes = profundidad
                        nueva.salir.stop(); nueva.z = 1
                        nueva.category = category; nueva.sub = sub; nueva.dir = dir
                        nueva.sourceComponent = pagina()
                        activa = nueva
                        if (vieja && vieja.item) { vieja.z = 0; vieja.dir = dir; vieja.salir.restart() }
                        // Elemento compartido: entrando, el título de la tarjeta tocada viaja al título
                        // de la página; volviendo, el título de la página vuelve a su tarjeta
                        heroe.terminar()
                        if (dir > 0 && win.heroTocado) heroe.preparar(win.heroTocado, nueva, "", true)
                        else if (dir < 0 && vieja && vieja.item) heroe.preparar(heroe.buscar(vieja.item, "heroDestino", ""), nueva, tituloAntes, false)
                        win.heroTocado = null
                        tituloAntes = win.crumbs.length ? win.crumbs[win.crumbs.length - 1].title : ""
                    }
                    property string tituloAntes: ""

                    // ── El título que viaja ──
                    Item {
                        id: heroe
                        // En la capa de arriba de la ventana: así nada de las páginas lo tapa
                        parent: Overlay.overlay
                        anchors.fill: parent
                        z: 1000
                        property real t: 0
                        property bool volando: false
                        property var a: null            // de dónde sale: {x, y, p (tamaño), w (peso), c, txt}
                        property var b: null            // adónde llega
                        property var ocultos: []
                        property var pendiente: null    // esperando un cuadro, a que la página nueva se acomode
                        // El destino se sigue en vivo (si su página termina de acomodarse mientras vuela,
                        // el título igual llega justo a su lugar)
                        property var destino: null
                        property var marco: null
                        function aDestino() {
                            t                                   // (se recalcula en cada cuadro del vuelo)
                            // (medido en el contenido, sin el corrimiento de la página mientras entra)
                            try {
                                if (!destino || !marco) return null
                                var p = destino.mapToItem(heroe, 0, 0)
                                return { x: p.x - marco.x, y: p.y - marco.y }
                            } catch (e) { return null }
                        }
                        function mezclar(x, y) { return x + (y - x) * t }
                        function mezclarColor(x, y) { return Qt.rgba(mezclar(x.r, y.r), mezclar(x.g, y.g), mezclar(x.b, y.b), mezclar(x.a, y.a)) }
                        function buscar(item, nombre, texto) {
                            if (!item) return null
                            if (item.objectName === nombre && (texto === "" || item.text === texto || item.text === win.brand(texto))) return item
                            for (var i = 0; i < item.children.length; i++) {
                                var r = buscar(item.children[i], nombre, texto)
                                if (r) return r
                            }
                            return null
                        }
                        // (el color se copia: si fuera el del texto mismo, se perdería al cerrarse su página)
                        function copiarColor(c) { return { r: c.r, g: c.g, b: c.b, a: c.a } }
                        function datos(l, pos) { return { x: pos.x, y: pos.y, p: l.font.pixelSize, w: l.font.weight, c: copiarColor(l.color), txt: l.text } }
                        function preparar(desde, capa, texto, ida) {
                            if (!desde || !capa.item) return
                            try { desde.mapToItem(heroe, 0, 0) } catch (e) { return }
                            a = datos(desde, desde.mapToItem(heroe, 0, 0)); b = a
                            desde.opacity = 0; ocultos = [desde]
                            t = 0; volando = true                 // (ya se ve en su lugar de salida)
                            pendiente = { capa: capa, texto: texto, ida: ida }
                        }
                        Connections {
                            target: win
                            enabled: heroe.pendiente !== null
                            function onFrameSwapped() { Qt.callLater(heroe.despegar) }
                        }
                        function despegar() {
                            var pe = pendiente; pendiente = null
                            if (!pe || !volando) return
                            var d = pe.ida ? buscar(pe.capa.item, "heroDestino", "") : buscar(pe.capa.item, "heroTitulo", pe.texto)
                            if (!d) { terminar(); return }
                            // Medido en la página nueva: donde va a quedar cuando termine de entrar
                            destino = d; marco = pe.capa.item
                            b = datos(d, aDestino())
                            d.opacity = 0; ocultos = ocultos.concat([d])
                            vuelo.duration = pe.ida ? 400 : 340
                            vuelo.start()
                        }
                        function terminar() {
                            vuelo.stop(); pendiente = null
                            for (var i = 0; i < ocultos.length; i++) if (ocultos[i]) ocultos[i].opacity = 1
                            ocultos = []; volando = false; destino = null; marco = null
                        }
                        NumberAnimation { id: vuelo; target: heroe; property: "t"; from: 0; to: 1; easing.type: Easing.OutCubic; onFinished: heroe.terminar() }
                        Item {
                            visible: heroe.volando && heroe.a !== null
                            readonly property var da: heroe.a || { x: 0, y: 0, p: 14, w: 400, c: { r: 0, g: 0, b: 0, a: 0 }, txt: "" }
                            readonly property var db: heroe.b || da
                            readonly property bool igual: da.txt === db.txt
                            readonly property var vivo: heroe.aDestino()
                            x: heroe.mezclar(da.x, vivo ? vivo.x : db.x); y: heroe.mezclar(da.y, vivo ? vivo.y : db.y)
                            // Dos textos que miden lo mismo en todo momento: el de salida se va, el de
                            // llegada aparece (si dicen lo mismo, se ve uno solo que crece o se achica)
                            Label {
                                transformOrigin: Item.TopLeft
                                text: parent.da.txt; font.pixelSize: parent.da.p; font.weight: parent.da.w
                                color: heroe.mezclarColor(parent.da.c, parent.db.c)
                                scale: heroe.mezclar(1, parent.db.p / parent.da.p)
                                opacity: parent.igual ? (heroe.t < 0.5 ? 1 : 2 - 2 * heroe.t) : Math.max(0, 1 - 1.6 * heroe.t)
                            }
                            Label {
                                transformOrigin: Item.TopLeft
                                text: parent.db.txt; font.pixelSize: parent.db.p; font.weight: parent.db.w
                                color: heroe.mezclarColor(parent.da.c, parent.db.c)
                                scale: heroe.mezclar(parent.da.p / parent.db.p, 1)
                                opacity: parent.igual ? (heroe.t < 0.5 ? 2 * heroe.t : 1) : Math.max(0, 1.6 * heroe.t - 0.6)
                            }
                        }
                    }
                    onClaveChanged: Qt.callLater(cambiar)        // (una vez, aunque cambien varias cosas juntas)
                    Component.onCompleted: cambiar()

                    component Capa: Loader {
                        id: capa
                        anchors.fill: parent
                        property var category
                        property var sub
                        property int dir: 0
                        readonly property bool actual: content.activa === capa
                        enabled: actual
                        onLoaded: {
                            item.opacity = 0
                            item.x = dir > 0 ? 48 : (dir < 0 ? -48 : 0)
                            item.y = dir === 0 ? 24 : 0
                            item.scale = 1
                            entrar.restart()
                        }
                        property alias salir: salirAnim
                        ParallelAnimation {
                            id: entrar
                            SequentialAnimation {           // (espera a que la anterior casi se fue: sin textos encimados)
                                PauseAnimation { duration: 70 }
                                NumberAnimation { target: capa.item; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            }
                            NumberAnimation { target: capa.item; property: "x"; to: 0; duration: 340; easing.type: Easing.OutQuint }
                            NumberAnimation { target: capa.item; property: "y"; to: 0; duration: 300; easing.type: Easing.OutCubic }
                        }
                        SequentialAnimation {
                            id: salirAnim
                            ScriptAction { script: entrar.stop() }
                            ParallelAnimation {
                                NumberAnimation { target: capa.item; property: "opacity"; to: 0; duration: 110; easing.type: Easing.OutQuad }
                                NumberAnimation { target: capa.item; property: "x"; to: capa.dir > 0 ? -36 : (capa.dir < 0 ? 36 : 0); duration: 260; easing.type: Easing.OutCubic }
                                NumberAnimation { target: capa.item; property: "scale"; to: capa.dir === 0 ? 0.985 : 1; duration: 200 }
                            }
                            ScriptAction { script: if (!capa.actual) capa.sourceComponent = undefined }
                        }
                    }
                    Capa { id: capaA }
                    Capa { id: capaB }
                }
            }
        }
    }

    // Borde fino de la ventana y bordes para redimensionar
    Rectangle {
        anchors.fill: parent
        visible: !win.maximized
        color: "transparent"
        border.color: win.dark ? "#3A3A3A" : "#CFCFCF"
        z: 999
    }
    ResizeEdges {}

    // ════════ Diseño de Coucou (con el tema Coucou Code) ════════
    readonly property var catGlyphs: ({ home: "home", coucou: "sparkle", system: "display", devices: "bluetooth", network: "wifi",
        personalization: "palette", apps: "apps", accounts: "user", time: "clock", gaming: "gamepad", accessibility: "access",
        privacy: "shield", update: "update" })
    readonly property var catTints: ({ home: "#3B82F6", coucou: "#6574F6", system: "#0EA5E9", devices: "#2563EB", network: "#10B981",
        personalization: "#EC4899", apps: "#F97316", accounts: "#8B5CF6", time: "#EAB308", gaming: "#22C55E", accessibility: "#06B6D4",
        privacy: "#64748B", update: "#14B8A6" })

    Item {
        anchors.fill: parent
        visible: win.coucou

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // ── Barra lateral flotante ──────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 286
                Layout.fillHeight: true
                radius: 24
                color: win.cSide
                border.color: win.cSideBorder

                DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Tú
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 68
                        radius: 18
                        color: meArea.containsMouse ? win.cRaisedHover : win.cRaised
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 22
                                color: win.cLight ? "#E6E1FB" : "#33FFFFFF"; clip: true
                                Image {
                                    id: meFace
                                    anchors.fill: parent
                                    source: backend.faceUrl()
                                    sourceSize: Qt.size(88, 88)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    layer.enabled: true
                                    layer.effect: OpacityMask { maskSource: Rectangle { width: meFace.width; height: meFace.height; radius: width / 2 } }
                                }
                                Image {
                                    anchors.centerIn: parent; visible: meFace.status !== Image.Ready
                                    source: "image://icon/coucou"; sourceSize: Qt.size(30, 30)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Label { Layout.fillWidth: true; text: backend.displayName(); color: win.text; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Label { Layout.fillWidth: true; text: "Coucou Code · " + backend.hostname; color: win.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                            }
                        }
                        MouseArea { id: meArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.openPath("accounts", ["Tu información"]) }
                    }

                    // Buscador en píldora
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 19
                        color: coucouSearch.activeFocus ? win.cInputFocus : win.cInput
                        border.color: coucouSearch.activeFocus ? win.accent : "transparent"
                        FluentIcon { anchors.left: parent.left; anchors.leftMargin: 13; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; color: win.subtext }
                        TextField {
                            id: coucouSearch
                            anchors { fill: parent; leftMargin: 34; rightMargin: 10 }
                            background: Item {}
                            color: win.text
                            placeholderText: "Buscar"
                            placeholderTextColor: win.subtext
                            font.pixelSize: 13
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: searchField.text = text
                            Connections { target: win; function onSearchChanged() { if (win.search === "") coucouSearch.text = "" } }
                        }
                    }

                    ListView {
                        id: coucouNav
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: P.pages
                        delegate: Rectangle {
                            id: navRow
                            required property var modelData
                            readonly property bool selected: win.search === "" && win.currentId === modelData.id
                            width: coucouNav.width
                            height: 42
                            radius: 12
                            color: selected ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28) : (navMouse.containsMouse ? win.cRowHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 10; spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8
                                    color: win.catTints[navRow.modelData.id] || win.accent
                                    FluentIcon { anchors.centerIn: parent; name: win.catGlyphs[navRow.modelData.id] || "advanced"; size: 15; color: "#FFFFFF"; stroke: 1.7 }
                                }
                                Label { Layout.fillWidth: true; text: win.brand(navRow.modelData.title); color: win.text; font.pixelSize: 14; font.weight: navRow.selected ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                            }
                            MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.openCategory(navRow.modelData.id) }
                        }
                        footer: Item {
                            width: coucouNav.width; height: 52
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 42; radius: 12
                                color: kdeMouse.containsMouse ? win.cRowHover : "transparent"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 8; spacing: 12
                                    Rectangle { Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 8; color: "#475569"
                                        FluentIcon { anchors.centerIn: parent; name: "wrench"; size: 15; color: "#FFFFFF"; stroke: 1.7 } }
                                    Label { Layout.fillWidth: true; text: "Más opciones (KDE)"; color: win.text; font.pixelSize: 14 }
                                }
                                MouseArea { id: kdeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: backend.launch("systemsettings") }
                            }
                        }
                    }
                }
            }

            // ── Contenido ────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }
                    TapHandler { onDoubleTapped: win.maximized ? win.showNormal() : win.showMaximized() }
                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
                            color: backMouse.containsMouse && win.canGoBack ? win.cBtnHover : win.cBtn
                            opacity: win.canGoBack ? 1 : 0.35
                            FluentIcon { anchors.centerIn: parent; name: "back"; size: 15; color: win.text; stroke: 1.6 }
                            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; enabled: win.canGoBack; onClicked: win.back() }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: win.search !== "" ? "Buscar" : win.pathParts.map(function (p) { return p.title }).join("  ›  ")
                            color: win.text; font.pixelSize: 15; font.weight: Font.Medium; elide: Text.ElideRight
                        }
                        Repeater {
                            model: [{ g: "min", a: "min" }, { g: win.maximized ? "restore" : "max", a: "max" }, { g: "close", a: "close" }]
                            Rectangle {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 15
                                color: capMouse.containsMouse ? (modelData.a === "close" ? "#E5484D" : win.cBtnHover) : win.cBtn
                                FluentIcon { anchors.centerIn: parent; name: modelData.g; size: 12; color: capMouse.containsMouse && modelData.a === "close" ? "#FFFFFF" : win.text; stroke: 1.3 }
                                MouseArea {
                                    id: capMouse; anchors.fill: parent; hoverEnabled: true
                                    onClicked: modelData.a === "min" ? win.showMinimized() : modelData.a === "max" ? (win.maximized ? win.showNormal() : win.showMaximized()) : win.close()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24
                    color: win.cPanel
                    border.color: win.cPanelBorder
                    clip: true
                    Item { id: coucouSlot; anchors.fill: parent; anchors.margins: 10 }
                }
            }
        }
    }

    Component { id: linksPage; LinksPage { category: parent && parent.sub && parent.sub.list ? parent.sub.list : (parent ? parent.category : null) } }
    Component { id: homePage; HomePage {} }
    Component { id: systemPage; SystemPage { category: parent ? parent.category : null } }
    Component { id: personalizationPage; PersonalizationPage { category: parent ? parent.category : null } }
    Component { id: colorsPage; ColorsPage {} }
    Component { id: coucouPage; CoucouPage {} }
    Component { id: taskbarPage; TaskbarPage {} }
    Component { id: themesPage; ThemesPage { items: parent && parent.sub && parent.sub.list ? parent.sub.list.items : [] } }
    Component { id: appsPage; AppsPage {} }
    Component { id: iconsPage; IconsPage {} }
    Component { id: widgetsPage; WidgetsPage {} }
    Component { id: clipboardPage; ClipboardPage {} }
    Component { id: kcmPage; KcmPage { kcm: parent && parent.sub && parent.sub.list ? parent.sub.list.kcm : "" } }
    Component { id: updatePage; UpdatePage {} }
    Component { id: searchPage; SearchPage { query: win.search } }
}
