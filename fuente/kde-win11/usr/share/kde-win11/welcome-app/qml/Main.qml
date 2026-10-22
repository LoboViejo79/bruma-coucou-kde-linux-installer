import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Bienvenido": CachyOS Hello con la forma de la instalación de Windows 11 (OOBE).
// Fondo degradado, tarjeta central con título e ilustración a la izquierda, opciones a la derecha
// y Atrás / Omitir / Siguiente.
ApplicationWindow {
    id: win
    width: 1280
    height: 820
    minimumWidth: 860
    minimumHeight: 600
    visible: true
    visibility: Window.Maximized
    title: "Bienvenido"
    flags: Qt.Window | Qt.FramelessWindowHint

    readonly property bool dark: backend.mode === "dark"
    readonly property color accent: backend.accent
    readonly property color accentText: dark ? Qt.lighter(accent, 1.6) : Qt.darker(accent, 1.05)
    readonly property color cardBg: dark ? "#2B2B2B" : "#FBFBFB"
    readonly property color cardHover: dark ? "#323232" : "#F5F5F5"
    readonly property color cardBorder: dark ? "#3A3A3A" : "#E5E5E5"
    readonly property color surface: dark ? "#202020" : "#F3F3F3"
    readonly property color text: dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: dark ? "#C5C5C5" : "#5F5F5F"

    font.family: "Selawik"
    font.pixelSize: 14
    color: dark ? "#0B1628" : "#D6E4F5"

    // ---------- Pasos ----------
    readonly property var steps: [
        { id: "welcome", title: "Te damos la bienvenida a CachyOS", image: "org.cachyos.hello",
          subtitle: "Vamos a dejar todo listo en unos pocos pasos." },
        { id: "theme", title: "Elige tu modo", glyph: "palette",
          subtitle: "Cambia los colores que aparecen en el escritorio y en las aplicaciones." },
        { id: "tweaks", title: "Optimiza el rendimiento de tu PC", glyph: "gauge",
          subtitle: "CachyOS incluye servicios que hacen el equipo más rápido y estable." },
        { id: "apps", title: "Personalicemos tu experiencia", glyph: "sparkle",
          subtitle: "Elige cómo piensas usar el dispositivo y te prepararemos lo necesario." },
        { id: "maintenance", title: "Mantén tu PC en buen estado", glyph: "wrench",
          subtitle: "Herramientas para actualizar, limpiar y reparar el sistema." },
        { id: "help", title: "Ayuda y comunidad", glyph: "people",
          subtitle: "Documentación, foros y redes del proyecto CachyOS." },
        { id: "done", title: "Todo listo", glyph: "check",
          subtitle: "Puedes volver a abrir Bienvenido cuando quieras desde el menú Inicio." }
    ]
    property int step: Math.max(0, steps.findIndex(function (s) { return s.id === startPage }))
    readonly property var cur: steps[step]

    // Lo que el usuario quiere (se aplica al salir de "Personalicemos tu experiencia")
    property var wants: ({})
    function want(key, on) { var w = Object.assign({}, wants); w[key] = on; wants = w }
    Component.onCompleted: wants = Object.assign({}, backend.state)

    function go(i) {
        slideFrom = i > step ? 60 : -60
        step = i
        slideIn.restart()
    }
    function next() {
        if (cur.id === "apps") applyChoices()
        else if (step < steps.length - 1) go(step + 1)
        else Qt.quit()
    }

    property var pendingUser: []
    function applyChoices() {
        var st = backend.state, acts = [], user = []
        var services = { ananicy: "ananicy-cpp.service", oomd: "systemd-oomd.service", bluetooth: "bluetooth.service" }
        for (var k in services)
            if (!!wants[k] !== !!st[k]) acts.push((wants[k] ? "enable:" : "disable:") + services[k])
        if (!!wants.psd !== !!st.psd) {
            if (wants.psd) acts.push("psd")
            user.push(["psd.service", !!wants.psd])
        }
        if (st.hasUpdates && !!wants.updates !== !!st.updates) user.push(["arch-update.timer", !!wants.updates])
        if (wants.gaming && !st.gaming) acts.push("gaming")
        if (wants.winboat && !st.winboat) acts.push("winboat:" + backend.userName)
        pendingUser = user
        if (acts.length) progress.start("Aplicando tus preferencias", acts, true)
        else finishChoices()
    }
    function finishChoices() {
        for (var i = 0; i < pendingUser.length; ++i) backend.setUserService(pendingUser[i][0], pendingUser[i][1])
        pendingUser = []
        wants = Object.assign({}, backend.state)
        go(step + 1)
    }

    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; enabled: step > 0 && !progress.visible; onActivated: go(step - 1) }

    // ---------- Fondo ----------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: win.dark ? "#0A1424" : "#C9DCF2" }
            GradientStop { position: 0.55; color: win.dark ? "#10294A" : "#E7EFF9" }
            GradientStop { position: 1.0; color: win.dark ? "#0B1B33" : "#D3E2F5" }
        }
    }
    // Arrastrar la ventana desde el fondo
    MouseArea {
        anchors.fill: parent
        onPressed: win.startSystemMove()
        onDoubleClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
    }

    CaptionButtons { anchors.top: parent.top; anchors.right: parent.right; z: 10 }

    // ---------- Tarjeta ----------
    // Sombra
    Repeater {
        model: 4
        Rectangle {
            x: card.x - index * 2; y: card.y - index * 2 + 6
            width: card.width + index * 4; height: card.height + index * 4
            radius: card.radius + index * 2
            color: Qt.rgba(0, 0, 0, win.dark ? 0.10 : 0.035)
        }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1120)
        height: Math.min(parent.height - 100, 700)
        radius: 8
        color: win.surface
        border.color: win.cardBorder
        border.width: 1

        // Atrás (arriba a la izquierda, como en Windows)
        ToolButton {
            id: backButton
            visible: win.step > 0 && win.cur.id !== "done"
            x: 16; y: 16
            width: 36; height: 32
            flat: true
            contentItem: FluentIcon { name: "back"; size: 16; color: win.text }
            onClicked: win.go(win.step - 1)
            ToolTip.visible: hovered
            ToolTip.text: "Atrás"
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Columna izquierda: título e ilustración
            Item {
                Layout.preferredWidth: card.width * 0.42
                Layout.fillHeight: true

                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: 52; anchors.rightMargin: 32; anchors.topMargin: 64
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        text: win.cur.id === "done" ? "Todo listo, " + backend.userName : win.cur.title
                        color: win.text
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.1
                    }
                    Label {
                        Layout.fillWidth: true
                        text: win.cur.subtitle
                        color: win.subtext
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }
                }
                Illustration {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 60
                    width: Math.min(parent.width * 0.68, parent.height * 0.48, 300)
                    height: width
                    glyph: win.cur.glyph || ""
                    image: win.cur.image || ""
                }
            }

            // Columna derecha: contenido y botones
            Item {
                id: right
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollView {
                    id: scroller
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: buttons.top }
                    anchors.leftMargin: 24; anchors.rightMargin: 24; anchors.topMargin: 64; anchors.bottomMargin: 16
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    Item {
                        width: scroller.availableWidth
                        implicitHeight: pages.implicitHeight
                        transform: Translate { id: slide; x: 0 }
                        opacity: 1
                        id: pageHost

                        StackLayout {
                            id: pages
                            width: parent.width - 28
                            currentIndex: win.step
                            implicitHeight: children[currentIndex] ? children[currentIndex].implicitHeight : 0

                            WelcomeStep {}
                            ThemeStep {}
                            TweaksStep {}
                            AppsStep {}
                            MaintenanceStep {}
                            HelpStep {}
                            DoneStep {}
                        }
                    }
                }

                RowLayout {
                    id: buttons
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 40; bottomMargin: 36 }
                    spacing: 8
                    Button {
                        visible: win.cur.id === "tweaks" || win.cur.id === "apps" || win.cur.id === "theme"
                        text: "Omitir"
                        Layout.preferredWidth: 120
                        onClicked: { win.wants = Object.assign({}, backend.state); win.go(win.step + 1) }
                    }
                    Button {
                        text: win.cur.id === "welcome" ? "Comenzar" : win.cur.id === "done" ? "Finalizar" : (win.cur.id === "apps" ? "Aceptar" : "Siguiente")
                        highlighted: true
                        Layout.preferredWidth: 120
                        onClicked: win.next()
                    }
                }
            }
        }
    }

    property real slideFrom: 60
    ParallelAnimation {
        id: slideIn
        NumberAnimation { target: slide; property: "x"; from: win.slideFrom; to: 0; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageHost; property: "opacity"; from: 0; to: 1; duration: 220 }
    }

    // Indicador de pasos bajo la tarjeta
    Row {
        anchors.top: card.bottom
        anchors.topMargin: 18
        anchors.horizontalCenter: card.horizontalCenter
        spacing: 8
        Repeater {
            model: win.steps.length
            Rectangle {
                width: index === win.step ? 18 : 6
                height: 6
                radius: 3
                color: index === win.step ? win.accent : Qt.alpha(win.text, 0.35)
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }

    ProgressScreen {
        id: progress
        anchors.fill: parent
        z: 100
        onClosed: function (ok) { if (win.cur.id === "apps") win.finishChoices() }
    }

    // ================= Contenido de cada paso =================

    component SectionLabel: Label {
        Layout.topMargin: 14
        color: win.text
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    component WelcomeStep: ColumnLayout {
        spacing: 8
        Label {
            Layout.fillWidth: true
            text: "Nosotros, los desarrolladores de CachyOS, esperamos que disfrutes usándolo tanto como nosotros creándolo. Te ayudaremos a:"
            wrapMode: Text.WordWrap
            color: win.text
            font.pixelSize: 15
            Layout.bottomMargin: 8
        }
        Repeater {
            model: [
                { g: "palette", t: "Elegir el aspecto", d: "Modo claro u oscuro y color de énfasis." },
                { g: "gauge", t: "Optimizar el rendimiento", d: "Servicios de CachyOS para un equipo más ágil." },
                { g: "gamepad", t: "Preparar juegos y apps de Windows", d: "Steam, Proton, Lutris, WinBoat..." },
                { g: "wrench", t: "Mantener el sistema", d: "Actualizar, limpiar y reparar." }
            ]
            RowLayout {
                spacing: 16
                Layout.fillWidth: true
                Layout.topMargin: 6
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 6
                    color: Qt.alpha(win.accent, 0.14)
                    FluentIcon { anchors.centerIn: parent; name: modelData.g; size: 20; color: win.accentText }
                }
                ColumnLayout {
                    spacing: 1
                    Label { text: modelData.t; color: win.text; font.pixelSize: 14 }
                    Label { text: modelData.d; color: win.subtext; font.pixelSize: 12 }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 18
            text: "Puedes cambiarlo todo más adelante en Configuración."
            color: win.subtext
            font.pixelSize: 12
        }
    }

    component ModeTile: Rectangle {
        id: tile
        property bool darkPreview
        property bool selected: (backend.mode === "dark") === darkPreview
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        radius: 8
        color: hover.containsMouse ? win.cardHover : win.cardBg
        border.width: selected ? 2 : 1
        border.color: selected ? win.accent : win.cardBorder
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.setTheme(tile.darkPreview ? "dark" : "light", backend.accent)
        }
        // Escritorio en miniatura
        Rectangle {
            id: mini
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: 124
            radius: 4
            gradient: Gradient {
                GradientStop { position: 0; color: tile.darkPreview ? "#1B2A44" : "#BFD6F2" }
                GradientStop { position: 1; color: tile.darkPreview ? "#0E1626" : "#E9F1FB" }
            }
            Rectangle {   // ventana
                x: 22; y: 16; width: parent.width * 0.55; height: 70; radius: 4
                color: tile.darkPreview ? "#2B2B2B" : "#FFFFFF"
                border.color: tile.darkPreview ? "#3A3A3A" : "#E0E0E0"
                Rectangle { x: 8; y: 10; width: parent.width * 0.5; height: 6; radius: 3; color: tile.darkPreview ? "#5A5A5A" : "#D0D0D0" }
                Rectangle { x: 8; y: 22; width: parent.width * 0.7; height: 6; radius: 3; color: tile.darkPreview ? "#444" : "#E5E5E5" }
                Rectangle { x: parent.width - 42; y: parent.height - 18; width: 34; height: 10; radius: 3; color: win.accent }
            }
            Rectangle {   // barra de tareas
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 16
                color: tile.darkPreview ? "#202020" : "#F3F3F3"
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: 5
                        Rectangle { width: 8; height: 8; radius: 2; color: index === 0 ? win.accent : (tile.darkPreview ? "#777" : "#AAA") }
                    }
                }
            }
        }
        RowLayout {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 14 }
            spacing: 8
            RadioButton { checked: tile.selected; onClicked: hover.clicked(null); padding: 0 }
            Label { text: tile.darkPreview ? "Oscuro" : "Claro"; color: win.text }
        }
    }

    component ThemeStep: ColumnLayout {
        spacing: 10
        Label { text: "Modo"; color: win.text; font.weight: Font.DemiBold }
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            ModeTile { darkPreview: false }
            ModeTile { darkPreview: true }
        }
        SectionLabel { text: "Color de énfasis" }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: ["#0078D4", "#0063B1", "#00B7C3", "#038387", "#10893E", "#498205", "#FFB900", "#F7630C",
                        "#DA3B01", "#E81123", "#E3008C", "#C239B3", "#8764B8", "#6B69D6", "#767676", "#7E735F"]
                Rectangle {
                    width: 40; height: 40; radius: 4
                    color: modelData
                    border.width: backend.accent.toUpperCase() === modelData ? 3 : 0
                    border.color: win.text
                    FluentIcon {
                        anchors.centerIn: parent
                        visible: backend.accent.toUpperCase() === modelData
                        name: "check"; size: 16; stroke: 2; color: "white"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setTheme(backend.mode, modelData)
                    }
                }
            }
        }
    }

    component TweaksStep: ColumnLayout {
        spacing: 4
        OptionCard {
            glyph: "cpu"
            title: "Ananicy-cpp"
            description: "Da prioridad automáticamente a las aplicaciones que estás usando para que todo vaya fluido."
            checked: !!win.wants.ananicy
            onToggled: function (on) { win.want("ananicy", on) }
        }
        OptionCard {
            glyph: "memory"
            title: "Protección contra falta de memoria"
            description: "systemd-oomd cierra a tiempo los procesos que se comen la RAM, antes de que el equipo se congele."
            checked: !!win.wants.oomd
            onToggled: function (on) { win.want("oomd", on) }
        }
        OptionCard {
            glyph: "globe"
            title: "Navegador más rápido"
            description: "profile-sync-daemon mantiene el perfil del navegador en memoria (menos escrituras en disco)."
            checked: !!win.wants.psd
            onToggled: function (on) { win.want("psd", on) }
        }
        OptionCard {
            glyph: "bluetooth"
            title: "Bluetooth"
            description: "Servicio para auriculares, mandos y otros dispositivos inalámbricos."
            checked: !!win.wants.bluetooth
            onToggled: function (on) { win.want("bluetooth", on) }
        }
        OptionCard {
            visible: !!backend.state.hasUpdates
            glyph: "update"
            title: "Avisos de actualizaciones"
            description: "Comprueba periódicamente si hay actualizaciones y te avisa en la bandeja del sistema."
            checked: !!win.wants.updates
            onToggled: function (on) { win.want("updates", on) }
        }
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "Los cambios se aplicarán al pulsar Aceptar en el siguiente paso. Se pedirá la contraseña de administrador."
            color: win.subtext
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    component AppsStep: ColumnLayout {
        spacing: 4
        Label {
            Layout.fillWidth: true
            text: "Selecciona todas las formas en que piensas usar el dispositivo."
            color: win.text
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 6
        }
        OptionCard {
            kind: "check"
            glyph: "gamepad"
            title: "Juegos"
            description: "Steam, Lutris, Heroic, Wine, Proton, Gamescope y MangoHud (cachyos-gaming-meta)."
            badge: backend.state.gaming ? "Instalado" : ""
            checked: !!win.wants.gaming
            onToggled: function (on) { if (!backend.state.gaming) win.want("gaming", on) }
        }
        OptionCard {
            kind: "check"
            glyph: "window"
            title: "Aplicaciones de Windows"
            description: "WinBoat ejecuta programas de Windows en su propia ventana (instala también Docker)."
            badge: backend.state.winboat ? "Instalado" : ""
            checked: !!win.wants.winboat
            onToggled: function (on) { if (!backend.state.winboat) win.want("winboat", on) }
        }
        SectionLabel { text: "Herramientas de CachyOS" }
        OptionCard {
            kind: "link"; glyph: "store"
            title: "Tienda"
            description: "Busca e instala aplicaciones."
            visible: backend.has("win11-store")
            onClicked: backend.launch("win11-store")
        }
        OptionCard {
            kind: "link"; glyph: "package"
            title: "Instalador de paquetes"
            description: "Todos los paquetes de los repositorios de CachyOS y Arch."
            visible: backend.has("cachyos-pi")
            onClicked: backend.launch("cachyos-pi")
        }
        OptionCard {
            kind: "link"; glyph: "cpu"
            title: "Administrador de kernels"
            description: "Instala otros kernels de CachyOS o compila uno a tu medida."
            visible: backend.has("cachyos-kernel-manager")
            onClicked: backend.launch("cachyos-kernel-manager")
        }
        OptionCard {
            kind: "link"; glyph: "thunder"
            title: "Planificadores sched-ext"
            description: "Elige el planificador de CPU: juegos, baja latencia, ahorro de energía..."
            visible: backend.has("scx-manager")
            onClicked: backend.launch("scx-manager")
        }
    }

    component MaintenanceStep: ColumnLayout {
        spacing: 4
        Repeater {
            model: [
                { g: "update", t: "Actualizar el sistema", d: "Descarga e instala todas las actualizaciones (pacman -Syu).", a: "update" },
                { g: "globe", t: "Elegir los servidores más rápidos", d: "Ordena los espejos de descarga según tu conexión.", a: "mirrors" },
                { g: "broom", t: "Liberar espacio", d: "Borra de la caché los paquetes que ya no están instalados.", a: "cleancache" },
                { g: "trash", t: "Quitar paquetes huérfanos", d: "Dependencias que ya ningún programa necesita.", a: "orphans" },
                { g: "lock", t: "Quitar el bloqueo de pacman", d: "Si una instalación se cortó y ahora dice que la base de datos está bloqueada.", a: "unlock" },
                { g: "key", t: "Restablecer las claves", d: "Arregla los errores de firmas o claves al instalar.", a: "keyrings" },
                { g: "package", t: "Reinstalar todos los paquetes", d: "Repara archivos dañados del sistema. Tarda bastante.", a: "reinstall" }
            ]
            OptionCard {
                kind: "button"
                glyph: modelData.g
                title: modelData.t
                description: modelData.d
                badge: modelData.a === "unlock" && backend.state.lock ? "Bloqueado" : ""
                onClicked: progress.start(modelData.t, [modelData.a], false)
            }
        }
    }

    component LinkTile: Rectangle {
        property string glyph
        property string label
        property string url
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 6
        color: ma.containsMouse ? win.cardHover : win.cardBg
        border.color: win.cardBorder
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            FluentIcon { name: parent.parent.glyph; size: 20; color: win.accentText }
            Label { Layout.fillWidth: true; text: parent.parent.label; color: win.text; elide: Text.ElideRight }
            FluentIcon { name: "open"; size: 14; color: win.subtext }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: backend.openUrl(parent.url)
        }
    }

    component HelpStep: ColumnLayout {
        spacing: 6
        Label { text: "Documentación"; color: win.text; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; columnSpacing: 6; rowSpacing: 6
            LinkTile { glyph: "book"; label: "Wiki de CachyOS"; url: "https://wiki.cachyos.org" }
            LinkTile { glyph: "news"; label: "Notas de la versión"; url: "https://blog.cachyos.org" }
            LinkTile { glyph: "package"; label: "Paquetes"; url: "https://packages.cachyos.org" }
            LinkTile { glyph: "code"; label: "Desarrollo (GitHub)"; url: "https://github.com/cachyos" }
        }
        SectionLabel { text: "Soporte y comunidad" }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; columnSpacing: 6; rowSpacing: 6
            LinkTile { glyph: "chat"; label: "Foro"; url: "https://discuss.cachyos.org" }
            LinkTile { glyph: "people"; label: "Discord"; url: "https://discord.gg/cachyos-862292009423470592" }
            LinkTile { glyph: "chat"; label: "Reddit"; url: "https://www.reddit.com/r/cachyos" }
            LinkTile { glyph: "heart"; label: "Donar"; url: "https://www.patreon.com/CachyOS" }
        }
    }

    component DoneStep: ColumnLayout {
        spacing: 10
        Label {
            Layout.fillWidth: true
            text: "Tu PC está preparado. Esperamos que disfrutes de CachyOS."
            color: win.text
            font.pixelSize: 15
            wrapMode: Text.WordWrap
        }
        OptionCard {
            Layout.topMargin: 12
            kind: "link"; glyph: "settings"; icon: "preferences-system"
            title: "Configuración"
            description: "Fondo, barra de tareas, pantalla, sonido y mucho más."
            onClicked: backend.launch(backend.has("win11-settings") ? "win11-settings" : "systemsettings")
        }
        OptionCard {
            kind: "switch"; glyph: "rocket"
            title: "Mostrar Bienvenido al iniciar sesión"
            description: "Abre esta guía cada vez que entres en tu cuenta."
            checked: backend.autostart
            onToggled: function (on) { backend.autostart = on }
        }
    }
}
