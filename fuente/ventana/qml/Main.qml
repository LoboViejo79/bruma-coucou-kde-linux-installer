import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CoucouCopias

// "Instalar Bruma Coucou": instala el diseño de Coucou, el de Windows 11 o los dos en un CachyOS ya
// instalado. Misma forma que Bienvenido (tarjeta central, título e ilustración a la izquierda,
// opciones a la derecha, Atrás / Siguiente) con los colores claros de Coucou.
ApplicationWindow {
    id: win
    width: 1180
    height: 760
    minimumWidth: 940
    minimumHeight: 640
    visible: true
    title: "Instalar Bruma Coucou"
    flags: Qt.Window | Qt.FramelessWindowHint

    // Paleta clara de Coucou (los componentes de Bienvenido la leen de aquí)
    readonly property bool coucou: true
    readonly property bool cLight: true
    readonly property bool dark: false
    readonly property color accent: "#6574F6"
    readonly property color accentText: "#4F5BD5"
    readonly property color cardBg: "#FFFFFF"
    readonly property color cardHover: "#F1EEFE"
    readonly property color cardBorder: "#E2DDF8"
    readonly property color surface: "#F2FFFFFF"
    readonly property color text: "#1D1B33"
    readonly property color subtext: "#5F5A8A"
    function r(n) { return Math.round(n * 2.2) }

    font.family: "Inter"
    font.pixelSize: 14
    color: "#EEEBFC"

    // ---------- Lo que se elige ----------
    property string diseno: "coucou"
    property string modo: "claro"
    property bool login: true
    property bool arranque: true
    property bool voz: true
    // Color de énfasis: el de cada diseño hasta que se elige otro
    property string acentoElegido: ""
    readonly property string acento: diseno === "cachyos" ? "" : acentoElegido !== "" ? acentoElegido
                                     : diseno === "coucou" ? "#6574F6" : "#0078D4"
    readonly property var colores: ["#6574F6", "#8B5CF6", "#EC4899", "#F43F5E", "#F97316", "#EAB308",
                                    "#22C55E", "#10B981", "#06B6D4", "#3B82F6", "#0078D4", "#767676"]
    // Aplicaciones y rendimiento elegidos (ids de instalar.sh)
    property var apps: ({ tienda: true })
    // Las que ya están instaladas: marcadas, con "Instalado", y no se vuelven a instalar
    readonly property var yaInstaladas: backend.installedApps().split(",").filter(function (x) { return x !== "" })
    property var rend: ({ ananicy: true, oomd: true })
    function alternar(lista, id) { var o = Object.assign({}, win[lista]); o[id] = !o[id]; win[lista] = o }
    function ids(o) { return Object.keys(o).filter(function (k) { return o[k] }).join(",") }
    function instalar() {
        fallo = false
        backend.install(diseno, modo, login && diseno !== "cachyos", arranque && diseno !== "cachyos", acento, ids(apps), ids(rend), voz)
    }

    // Solo el diseño de Coucou
    readonly property var disenos: ({
        coucou: { titulo: "Bruma Coucou", imagen: "estilo-coucou.png",
                  texto: "El diseño de Coucou: tema violeta y su barra de vidrio con Mochi, el buscador y los controles del sistema." }
    })

    // ---------- Pasos ----------
    readonly property var steps: [
        { id: "welcome", title: "Instala Bruma Coucou en este equipo", image: "file:" + backend.folder + "/imagenes/mochi.png",
          subtitle: "El diseño, los iconos, los ajustes y la pantalla de inicio de sesión, en unos pocos pasos." },
        { id: "modo", title: "Colores", glyph: "moon",
          subtitle: "Claro u oscuro, y el color de énfasis de botones, selección y la barra." },
        { id: "apps", title: "Aplicaciones", glyph: "apps",
          subtitle: "Elige las que quieras (o ninguna). Las demás se pueden instalar después desde la Tienda de aplicaciones." },
        { id: "rendimiento", title: "Rendimiento", glyph: "gauge",
          subtitle: "Servicios de CachyOS que hacen el equipo más rápido y estable." },
        { id: "extras", title: "Últimos detalles", glyph: "sparkle",
          subtitle: "Lo que se ve al encender el equipo y al entrar a tu cuenta." },
        { id: "listo", title: actualizando ? "Bruma Coucou se actualizó" : "Todo listo", glyph: "check",
          subtitle: actualizando ? "Ya tienes la versión nueva. Tu diseño, fondo y apps quedaron como estaban."
                                 : "Cierra sesión y vuelve a entrar para ver el diseño completo." },
        // Historial y copias de seguridad (desde "update" o "listo"; no es un paso de la instalación)
        { id: "copias", title: "Copias de seguridad", glyph: "history",
          subtitle: "Cuándo se instaló Bruma Coucou, cada actualización, y las copias para volver a como estaba la PC antes." },
        // Coucou ya está en el equipo: se actualiza, no se instala todo de nuevo
        { id: "update", title: "Bruma Coucou ya está instalado", image: "file:" + backend.folder + "/imagenes/mochi.png",
          subtitle: backend.newCount > 0 ? "Este instalador trae una versión más nueva. Se actualiza sin tocar tu diseño."
                                         : "Ya tienes todo lo que trae este instalador. No hace falta hacer nada." }
    ]
    // Actualizando (no instalando todo): cambia el final
    property bool actualizando: false
    readonly property int updateIndex: steps.length - 1
    readonly property int copiasIndex: steps.length - 2
    // Copias de seguridad: de qué pantalla se vino (para volver) y lo que dice copia.sh ver
    property int volverA: 0
    property string copiasTexto: ""
    function verCopias() { volverA = step; copiasTexto = "Leyendo el historial…"; Copias.ver(backend.folder); go(copiasIndex) }
    Connections { target: Copias; function onHistorial(texto) { win.copiasTexto = texto } }
    function atras() { go(cur.id === "copias" ? volverA : step - 1) }
    // (abierta directo en las copias: COUCOU_INSTALADOR_PASO=copias)
    Component.onCompleted: if (cur.id === "copias") { volverA = updateIndex; Copias.ver(backend.folder) }
    property int step: startPage !== "" ? Math.max(0, steps.findIndex(function (s) { return s.id === startPage }))
                                        : backend.alreadyInstalled ? updateIndex : 0
    readonly property var cur: steps[step]
    property bool fallo: false
    // Se cerró la ventana de la contraseña: no es un error, falta escribirla
    readonly property bool sinClave: backend.lastCode === 126

    function go(i) {
        slideFrom = i > step ? 60 : -60
        step = i
        slideIn.restart()
    }
    function next() {
        if (cur.id === "copias") go(volverA)
        else if (cur.id === "update") {
            if (backend.newCount > 0) { actualizando = true; fallo = false; backend.update() }
            else Qt.quit()
        }
        else if (cur.id === "extras") { actualizando = false; instalar() }
        else if (cur.id === "listo") Qt.quit()
        else go(step + 1)
    }
    Connections {
        target: backend
        function onFinished(ok) {
            // Al final ("listo"), no al último paso de la lista (es "update")
            if (ok) go(steps.findIndex(function (s) { return s.id === "listo" }))
            else fallo = true
        }
    }
    onClosing: function (close) { if (backend.running || Copias.ocupado) close.accepted = false }

    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; enabled: step > 0 && cur.id !== "listo" && !backend.running; onActivated: atras() }

    // ---------- Fondo lavanda ----------
    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#F7F5FF" }
            GradientStop { position: 0.55; color: "#ECE8FD" }
            GradientStop { position: 1.0; color: "#E2DCFA" }
        }
    }
    MouseArea {
        anchors.fill: parent
        onPressed: win.startSystemMove()
        onDoubleClicked: win.visibility === Window.Maximized ? win.showNormal() : win.showMaximized()
    }
    CaptionButtons { anchors.top: parent.top; anchors.right: parent.right; z: 10 }

    // ---------- Tarjeta ----------
    Repeater {
        model: 4
        Rectangle {
            x: card.x - index * 2; y: card.y - index * 2 + 6
            width: card.width + index * 4; height: card.height + index * 4
            radius: card.radius + index * 2
            color: Qt.rgba(0.2, 0.15, 0.5, 0.03)
        }
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1080)
        height: Math.min(parent.height - 100, 660)
        radius: win.r(8)
        color: win.surface
        border.color: win.cardBorder

        ToolButton {
            visible: win.step > 0 && win.cur.id !== "listo" && win.cur.id !== "update" && !backend.running
            x: 16; y: 16
            width: 36; height: 32
            flat: true
            contentItem: FluentIcon { name: "back"; size: 16; color: win.text }
            onClicked: win.atras()
            ToolTip.visible: hovered
            ToolTip.text: "Atrás"
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Izquierda: título e ilustración
            Item {
                Layout.preferredWidth: card.width * 0.4
                Layout.fillHeight: true
                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: 52; anchors.rightMargin: 28; anchors.topMargin: 64
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        text: win.cur.title
                        color: win.text
                        font.pixelSize: 30
                        font.weight: Font.Bold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.1
                    }
                    Label {
                        Layout.fillWidth: true
                        text: win.cur.subtitle
                        color: win.subtext
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                    }
                }
                Illustration {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 70
                    width: Math.min(parent.width * 0.7, parent.height * 0.46, 280)
                    height: width
                    glyph: win.cur.glyph || ""
                    image: win.cur.image || ""
                }
            }

            // Derecha: opciones y botones
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Item {
                    id: pageHost
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: buttons.top }
                    anchors.leftMargin: 24; anchors.rightMargin: 44; anchors.topMargin: 64; anchors.bottomMargin: 16
                    transform: Translate { id: slide; x: 0 }
                    StackLayout {
                        anchors.fill: parent
                        currentIndex: win.step
                        WelcomeStep {}
                        ModoStep {}
                        AppsStep {}
                        RendimientoStep {}
                        ExtrasStep {}
                        ListoStep {}
                        CopiasStep {}
                        UpdateStep {}
                    }
                }

                RowLayout {
                    id: buttons
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 44; bottomMargin: 36 }
                    spacing: 8
                    Button {
                        // (también en la bienvenida: después de desinstalar se ve el historial)
                        visible: (win.cur.id === "update" || win.cur.id === "listo" || win.cur.id === "welcome") && !backend.running
                        text: "Copias de seguridad"
                        icon.name: "document-revert"
                        Layout.preferredWidth: 190
                        onClicked: win.verCopias()
                    }
                    Button {
                        // Ya al día o sin querer actualizar ahora: salir sin tocar nada
                        visible: win.cur.id === "update" && backend.newCount > 0 && !backend.running
                        text: "Ahora no"
                        Layout.preferredWidth: 120
                        onClicked: Qt.quit()
                    }
                    Button {
                        // También al actualizar: cerrar sesión aplica todos los cambios de una vez
                        visible: win.cur.id === "listo"
                        text: "Cerrar sesión ahora"
                        Layout.preferredWidth: 180
                        highlighted: true
                        onClicked: backend.logout()
                    }
                    Button {
                        text: win.cur.id === "welcome" ? "Comenzar" : win.cur.id === "extras" ? "Instalar"
                            : win.cur.id === "update" ? (backend.newCount > 0 ? "Actualizar" : "Cerrar")
                            : win.cur.id === "listo" ? "Más tarde" : win.cur.id === "copias" ? "Volver" : "Siguiente"
                        enabled: !backend.running
                        highlighted: win.cur.id !== "listo"
                        Layout.preferredWidth: 130
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

    // Versión del instalador (abajo a la izquierda)
    Label {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 20; bottomMargin: 14 }
        visible: backend.version !== ""
        text: "Bruma Coucou · versión " + backend.version
        color: win.subtext
        font.pixelSize: 12
    }

    // Puntos de los pasos bajo la tarjeta
    Row {
        anchors.top: card.bottom
        anchors.topMargin: 18
        anchors.horizontalCenter: card.horizontalCenter
        spacing: 8
        // (las pantallas de actualizar y de las copias no son pasos de la instalación)
        visible: win.cur.id !== "update" && win.cur.id !== "copias"
        Repeater {
            model: win.steps.length - 2
            Rectangle {
                width: index === win.step ? 18 : 6
                height: 6
                radius: 3
                color: index === win.step ? win.accent : Qt.alpha(win.text, 0.3)
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }

    // ---------- Instalando ----------
    Rectangle {
        anchors.fill: parent
        z: 100
        visible: backend.running || win.fallo
        color: "#EEEBFC"
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPressed: win.startSystemMove() }
        CaptionButtons { anchors.top: parent.top; anchors.right: parent.right; visible: win.fallo }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 680)
            spacing: 16
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                visible: backend.running
                running: visible
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: win.fallo
                width: 64; height: 64; radius: 32
                color: win.sinClave ? Qt.alpha(win.accent, 0.13) : "#FDE7EA"
                FluentIcon { anchors.centerIn: parent; name: win.sinClave ? "lock" : "close"; size: 26; stroke: 2.2; color: win.sinClave ? win.accentText : "#D6304A" }
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: !win.fallo ? (win.actualizando ? "Actualizando " : "Instalando ") + win.disenos[win.diseno].titulo
                    : win.sinClave ? "Hace falta la contraseña" : "No se pudo terminar la instalación"
                color: win.text
                font.pixelSize: 28
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: backend.status
                color: win.subtext
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }
            // La contraseña la pide la ventana de KDE (pkexec): con un mensaje de polkit que no viene
            // en español y los colores del tema del sistema, no los de Coucou
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: backend.running && backend.progress === 6
                text: "Se abre la ventana del sistema para escribirla. Si aparece en inglés (\"Authentication is needed…\") o con otros colores, es normal: es la de KDE, no la de Coucou."
                color: win.accentText
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            ProgressBar {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: backend.running
                from: 0; to: 100
                value: backend.progress
                indeterminate: backend.progress === 0
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: backend.running
                text: "Puede tardar varios minutos. No apagues el equipo."
                color: win.subtext
                font.pixelSize: 13
            }
            Button {
                id: verDetalles
                Layout.alignment: Qt.AlignHCenter
                checkable: true
                flat: true
                text: checked ? "Ocultar detalles" : "Ver detalles"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: verDetalles.checked
                radius: 12
                color: "#FFFFFF"
                border.color: win.cardBorder
                ScrollView {
                    id: logView
                    anchors.fill: parent
                    anchors.margins: 10
                    TextArea {
                        readOnly: true
                        text: backend.output
                        wrapMode: Text.WrapAnywhere
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: win.text
                        background: null
                        onTextChanged: cursorPosition = length
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: win.fallo
                spacing: 8
                Button { text: "Volver"; onClicked: win.fallo = false }
                Button { text: "Abrir el registro"; onClicked: backend.openLog() }
                Button {
                    text: win.sinClave ? "Escribir la contraseña" : "Reintentar"
                    highlighted: true
                    onClicked: win.instalar()
                }
            }
        }
    }

    // ---------- Desinstalar: la pregunta y la pantalla de progreso ----------
    property bool desConApps: false
    readonly property bool desSinClave: Copias.resultado === 126 || Copias.resultado === 127
    function desinstalar() { Copias.desinstalarAqui(backend.folder, win.desConApps) }
    Dialog {
        id: preguntaDes
        anchors.centerIn: parent
        width: Math.min(600, win.width - 80)
        modal: true
        padding: 28
        background: Rectangle { radius: 16; color: win.cardBg; border.color: win.cardBorder }
        Overlay.modal: Rectangle { color: Qt.rgba(0.11, 0.1, 0.2, 0.35) }
        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            Label { text: "¿Desinstalar Bruma Coucou?"; color: win.text; font.pixelSize: 22; font.weight: Font.Bold }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: win.text
                text: "Se quita Bruma Coucou y la PC queda como estaba antes de instalarlo: los ajustes de tu cuenta, el inicio de sesión y la animación al encender. Antes se guarda una copia de cómo está todo ahora. Tus archivos no se tocan."
            }
            CheckBox {
                Layout.fillWidth: true
                text: "También quitar las apps que elegiste al instalar (Steam, Discord…)"
                checked: win.desConApps
                onToggled: win.desConApps = checked
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Button { text: "Cancelar"; onClicked: preguntaDes.close() }
                Button { text: "Desinstalar"; highlighted: true; onClicked: { preguntaDes.close(); win.desinstalar() } }
            }
        }
        footer: null
    }
    Rectangle {
        anchors.fill: parent
        z: 101
        visible: Copias.ocupado || Copias.resultado >= 0
        color: "#EEEBFC"
        MouseArea { anchors.fill: parent; hoverEnabled: true; onPressed: win.startSystemMove() }
        CaptionButtons { anchors.top: parent.top; anchors.right: parent.right; visible: !Copias.ocupado }
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 680)
            spacing: 16
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64; Layout.preferredHeight: 64
                visible: Copias.ocupado
                running: visible
            }
            Rectangle {
                readonly property bool bien: Copias.resultado === 0
                Layout.alignment: Qt.AlignHCenter
                visible: !Copias.ocupado
                width: 64; height: 64; radius: 32
                color: bien ? "#DDF5E4" : win.desSinClave ? Qt.alpha(win.accent, 0.13) : "#FDE7EA"
                FluentIcon {
                    anchors.centerIn: parent
                    name: parent.bien ? "check" : win.desSinClave ? "lock" : "close"
                    size: 26; stroke: 2.2
                    color: parent.bien ? "#1E8E3E" : win.desSinClave ? win.accentText : "#D6304A"
                }
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Copias.ocupado ? "Desinstalando Bruma Coucou"
                    : Copias.resultado === 0 ? (Copias.avisos > 0 ? "Bruma Coucou se desinstaló, con avisos" : "Bruma Coucou se desinstaló")
                    : win.desSinClave ? "Hace falta la contraseña"
                    : Copias.resultado === 3 ? "No hay nada que desinstalar" : "No se pudo terminar de desinstalar"
                color: win.text
                font.pixelSize: 28
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Copias.ocupado ? Copias.estado
                    : Copias.resultado === 0
                      ? "Todo terminó. Reinicia el equipo para ver todo como estaba: el inicio de sesión y la animación al encender de antes."
                        + (Copias.avisos > 0 ? "\nAlgunos pasos dieron aviso: están en los detalles." : "")
                      : Copias.estado
                color: win.subtext
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }
            ProgressBar {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: Copias.ocupado
                from: 0; to: 100
                value: Copias.progreso
                indeterminate: Copias.progreso === 0
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: Copias.ocupado
                text: "Puede tardar unos minutos. No apagues el equipo ni cierres esta ventana."
                color: win.subtext
                font.pixelSize: 13
            }
            Button {
                id: verDetallesDes
                Layout.alignment: Qt.AlignHCenter
                checkable: true
                flat: true
                text: checked ? "Ocultar detalles" : "Ver detalles"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: verDetallesDes.checked
                radius: 12
                color: "#FFFFFF"
                border.color: win.cardBorder
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    TextArea {
                        readOnly: true
                        text: Copias.salida
                        wrapMode: Text.WrapAnywhere
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: win.text
                        background: null
                        onTextChanged: cursorPosition = length
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: !Copias.ocupado
                spacing: 8
                Button { visible: Copias.resultado === 0; text: "Más tarde"; onClicked: Qt.quit() }
                Button { visible: Copias.resultado === 0; text: "Reiniciar ahora"; highlighted: true; onClicked: Copias.reiniciar() }
                Button { visible: Copias.resultado !== 0; text: "Volver"; onClicked: Copias.olvidarDesinstalar() }
                Button {
                    visible: Copias.resultado !== 0 && Copias.resultado !== 3
                    text: win.desSinClave ? "Escribir la contraseña" : "Reintentar"
                    highlighted: true
                    onClicked: win.desinstalar()
                }
            }
        }
    }

    // ================= Contenido de cada paso =================

    component Punto: RowLayout {
        property string g
        property string t
        property string d
        spacing: 16
        Layout.fillWidth: true
        Layout.topMargin: 6
        Rectangle {
            Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 14
            color: Qt.alpha(win.accent, 0.13)
            FluentIcon { anchors.centerIn: parent; name: g; size: 20; color: win.accentText }
        }
        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true
            Label { text: t; color: win.text; font.pixelSize: 15; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; text: d; color: win.subtext; font.pixelSize: 13; wrapMode: Text.WordWrap }
        }
    }

    component WelcomeStep: ColumnLayout {
        spacing: 8
        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            text: "Esto es lo que se va a instalar:"
            color: win.text
            font.pixelSize: 16
        }
        Punto { g: "palette"; t: "El diseño de Coucou"; d: "Su barra de vidrio con Mochi, el buscador y el centro de control, con sus temas, iconos, cursores y fuentes." }
        Punto { g: "apps"; t: "Las aplicaciones de Coucou"; d: "Configuración, Tienda de aplicaciones, Administrador de tareas y Bienvenido." }
        Punto { g: "lock"; t: "Inicio de sesión y arranque"; d: "La pantalla para entrar a tu cuenta y la animación al encender." }
        Punto { g: "shield"; t: "Una copia de tu configuración"; d: "Antes de cambiar nada se guarda cómo está la PC ahora, para poder volver a como estaba o desinstalar." }
        Item { Layout.fillHeight: true }
        Label {
            Layout.fillWidth: true
            text: "Necesita internet y la contraseña de administrador. Tus archivos y aplicaciones no se tocan."
            color: win.subtext
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    component ModoTile: Rectangle {
        id: mt
        property string clave
        property string titulo
        property string imagen
        readonly property bool selected: win.modo === clave
        Layout.fillWidth: true
        Layout.preferredHeight: 210
        radius: win.r(7)
        color: ma.containsMouse ? win.cardHover : win.cardBg
        border.width: selected ? 2 : 1
        border.color: selected ? win.accent : win.cardBorder
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.modo = mt.clave }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: "#F4F1FE"
                clip: true
                Image { anchors.fill: parent; source: backend.image(mt.imagen); fillMode: Image.PreserveAspectCrop; smooth: true }
            }
            RowLayout {
                spacing: 10
                Rectangle {
                    width: 22; height: 22; radius: 11
                    color: mt.selected ? win.accent : "transparent"
                    border.width: mt.selected ? 0 : 2
                    border.color: "#B4AEE0"
                    FluentIcon { anchors.centerIn: parent; visible: mt.selected; name: "check"; size: 13; stroke: 2; color: "white" }
                }
                Label { text: mt.titulo; color: win.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            }
        }
    }

    component ModoStep: ColumnLayout {
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            ModoTile { clave: "claro"; titulo: "Claro"; imagen: "modo-claro.png" }
            ModoTile { clave: "oscuro"; titulo: "Oscuro"; imagen: "modo-oscuro.png" }
        }
        Label {
            Layout.topMargin: 10
            visible: win.diseno !== "cachyos"
            text: "Color de énfasis"
            color: win.text
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Flow {
            Layout.fillWidth: true
            visible: win.diseno !== "cachyos"
            spacing: 8
            Repeater {
                model: win.colores
                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: modelData
                    border.width: win.acento.toUpperCase() === modelData ? 3 : 0
                    border.color: win.text
                    FluentIcon {
                        anchors.centerIn: parent
                        visible: win.acento.toUpperCase() === modelData
                        name: "check"; size: 16; stroke: 2; color: "white"
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.acentoElegido = modelData }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: win.diseno === "cachyos" ? "CachyOS usa sus propios colores (Breeze). Todo se cambia cuando quieras en Configuración."
                                           : "Se cambia cuando quieras en Configuración → Personalización."
            color: win.subtext
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
    }

    component AppsStep: ScrollView {
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { id: "juegos", g: "gamepad", t: "Juegos", d: "Steam, Lutris, Heroic, Wine, Proton, Gamescope y MangoHud, con los controladores de tu tarjeta." },
                    { id: "windows", g: "window", t: "Aplicaciones de Windows", d: "WinBoat ejecuta programas de Windows en su propia ventana (instala también Docker)." },
                    { id: "tienda", g: "store", t: "Tienda de aplicaciones", d: "Para buscar e instalar aplicaciones (Flathub), en el menú Inicio." },
                    { id: "vscode", g: "code", t: "Visual Studio Code", d: "Editor de código." },
                    { id: "discord", g: "chat", t: "Discord", d: "Chat de voz y texto." },
                    { id: "spotify", g: "sound", t: "Spotify", d: "Música y podcasts." },
                    { id: "anydesk", g: "display", t: "AnyDesk", d: "Escritorio remoto: controlar otro equipo o dejar que te ayuden." },
                    { id: "vlc", g: "play", t: "VLC", d: "Reproductor de vídeo y música." }
                ]
                OptionCard {
                    readonly property bool ya: win.yaInstaladas.indexOf(modelData.id) >= 0
                    kind: "check"; glyph: modelData.g
                    title: modelData.t
                    description: ya ? "Ya está instalada en este equipo: no se instala otra vez." : modelData.d
                    badge: ya ? "Instalado" : ""
                    checked: ya || !!win.apps[modelData.id]
                    enabled: !ya
                    opacity: ya ? 0.75 : 1
                    onToggled: if (!ya) win.alternar("apps", modelData.id)
                }
            }
        }
    }

    component RendimientoStep: ColumnLayout {
        spacing: 10
        Repeater {
            model: [
                { id: "ananicy", g: "gauge", t: "Prioridad automática (Ananicy-cpp)", d: "Le da prioridad a las aplicaciones que estás usando para que todo vaya fluido." },
                { id: "oomd", g: "memory", t: "Protección contra falta de memoria", d: "systemd-oomd cierra a tiempo lo que se come la RAM, antes de que el equipo se congele." },
                { id: "psd", g: "globe", t: "Navegador más rápido", d: "profile-sync-daemon mantiene el perfil del navegador en memoria (menos escrituras en disco)." }
            ]
            OptionCard {
                kind: "switch"; glyph: modelData.g
                title: modelData.t; description: modelData.d
                checked: !!win.rend[modelData.id]
                onToggled: function (on) { win.alternar("rend", modelData.id) }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: "Bluetooth y los perfiles de energía se activan siempre: los usa el menú de la barra."
            color: win.subtext
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
    }

    component ExtrasStep: ColumnLayout {
        spacing: 10
        OptionCard {
            visible: win.diseno === "cachyos"
            kind: "link"; glyph: "info"
            title: "Inicio de sesión y arranque de CachyOS"
            description: "Con el diseño CachyOS se dejan tal como vienen: no se cambia nada."
        }
        OptionCard {
            visible: win.diseno !== "cachyos"
            kind: "switch"; glyph: "lock"
            title: "Pantalla de inicio de sesión"
            description: win.diseno === "coucou" ? "La de Coucou, con tu fondo de pantalla." : "La de Windows 11, con la hora grande y tu foto."
            checked: win.login
            onToggled: function (on) { win.login = on }
        }
        OptionCard {
            visible: win.diseno !== "cachyos"
            kind: "switch"; glyph: "power"
            title: "Animación al encender"
            description: "Mochi mientras arranca el equipo, sin letras ni pantallas negras. Se rehace la imagen de arranque (tarda un minuto)."
            checked: win.arranque
            onToggled: function (on) { win.arranque = on }
        }
        OptionCard {
            kind: "switch"; glyph: "sound"
            title: "Avisos por voz"
            description: "Sebastián lee en voz alta las notificaciones y avisa las actualizaciones. Necesita internet: el texto de cada aviso pasa por un servicio de voz en internet."
            checked: win.voz
            onToggled: function (on) { win.voz = on }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 14
            implicitHeight: resumen.implicitHeight + 32
            radius: win.r(6)
            color: "#F4F1FE"
            border.color: win.cardBorder
            ColumnLayout {
                id: resumen
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 6
                Label { text: "Resumen"; color: win.text; font.pixelSize: 15; font.weight: Font.Bold }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: win.subtext
                    font.pixelSize: 13
                    text: {
                        var a = Object.keys(win.apps).filter(function (k) { return win.apps[k] }).length
                        var r = Object.keys(win.rend).filter(function (k) { return win.rend[k] }).length
                        return "Diseño: " + win.disenos[win.diseno].titulo + " · Modo " + win.modo
                            + (win.acento ? " · Color " + win.acento : "")
                            + "\nAplicaciones: " + (a ? a : "ninguna") + " · Servicios de rendimiento: " + (r ? r : "ninguno")
                            + (win.diseno !== "cachyos" ? (win.login ? " · Inicio de sesión" : "") + (win.arranque ? " · Animación al encender" : "") : "")
                            + (win.voz ? " · Avisos por voz" : "")
                            + "\nAl tocar Instalar se pide la contraseña de administrador una sola vez."
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    // Ya instalado: qué hay y qué trae de nuevo este instalador
    component UpdateStep: ColumnLayout {
        spacing: 8
        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            text: (backend.installedVersion !== "" && backend.installedVersion !== "?"
                  ? "Tienes la versión " + backend.installedVersion
                  : "Bruma Coucou ya está instalado en este equipo") + " · este instalador es la versión " + backend.version + "."
            color: win.text
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        Punto {
            visible: backend.newCount > 0
            g: "download"; t: backend.newCount === 1 ? "Se actualiza 1 paquete" : "Se actualizan " + backend.newCount + " paquetes"
            d: backend.changes.map(function (c) { return c.replace("→", " → ") }).join("\n")
        }
        Punto {
            visible: backend.newCount === 0
            g: "check"; t: "Ya está al día"
            d: "Todo lo de este instalador ya está en el equipo (o tienes algo más nuevo). No se cambia nada."
        }
        Punto { g: "palette"; t: "Tu diseño queda igual"; d: "No se vuelven a aplicar el diseño, el fondo, los colores, las apps, el inicio de sesión ni el arranque." }
        Punto { visible: backend.newCount > 0; g: "history"; t: "La barra al instante"; d: "Al terminar, la barra se reinicia sola con la versión nueva. Para aplicar todo, cerrá sesión con el botón del final." }
        Item { Layout.fillHeight: true }
    }

    // Historial y copias de seguridad; desde aquí también se desinstala
    component CopiasStep: ColumnLayout {
        spacing: 10
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: "#FFFFFF"
            border.color: win.cardBorder
            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                TextArea {
                    readOnly: true
                    text: win.copiasTexto
                    wrapMode: Text.Wrap
                    font.family: "monospace"
                    font.pixelSize: 12
                    color: win.text
                    background: null
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Button { text: "Abrir la carpeta de copias"; icon.name: "folder-open"; onClicked: Copias.abrirCopias() }
            Button { visible: backend.alreadyInstalled; text: "Probar sin cambiar nada"; icon.name: "system-search"; onClicked: Copias.desinstalar(backend.folder, true) }
            Button { visible: backend.alreadyInstalled; text: "Desinstalar Bruma Coucou…"; icon.name: "edit-undo"; onClicked: { win.desConApps = false; preguntaDes.open() } }
        }
        Label {
            Layout.fillWidth: true
            text: backend.alreadyInstalled ? "Desinstalar deja la PC como estaba antes de Bruma Coucou. Antes pregunta, y \"Probar sin cambiar nada\" muestra en una terminal qué haría. Las apps que elegiste y tus archivos se quedan." : "Bruma Coucou no está instalado en este equipo. Aquí queda el historial y las copias."
            color: win.subtext
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    component ListoStep: ColumnLayout {
        spacing: 10
        Label {
            Layout.fillWidth: true
            visible: win.actualizando
            text: "Listo: Bruma Coucou quedó actualizado y la barra se reinició con la versión nueva. Para que todos los cambios tomen efecto, cerrá sesión y volvé a entrar."
            color: win.text
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            visible: !win.actualizando
            text: "Se instaló Bruma Coucou. Para que todo tome el diseño nuevo (fuentes, ventanas y la barra) hay que cerrar sesión y volver a entrar."
            color: win.text
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        Punto { g: "settings"; t: "Ajustar la barra"; d: "En Configuración → Personalización → Barra de tareas: forma, burbujas, posición y más." }
        Punto { g: "history"; t: "Volver a como estaba"; d: "Se guardó cómo estaba la PC antes. En Copias de seguridad ves el historial y puedes desinstalar Bruma Coucou." }
        Punto { g: "file"; t: "Qué se hizo"; d: "Todo lo que pasó en la instalación quedó anotado en coucou-instalador.log, en la carpeta del instalador." }
        Button {
            Layout.topMargin: 6
            text: "Abrir el registro"
            onClicked: backend.openLog()
        }
        Item { Layout.fillHeight: true }
    }
}
