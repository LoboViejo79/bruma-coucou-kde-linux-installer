import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Dialogs

// Coucou: todo lo de la interfaz de Coucou en un solo lugar. Activar o quitar
// Coucou Code, el color, la barra, la pantalla de bloqueo, el inicio de
// sesión, la pantalla de carga y la tecla Windows. Cada opción se guarda al
// instante en la configuración de KDE (o la aplica Coucou), sin botón "Aplicar".
ScrollView {
    id: root
    contentWidth: availableWidth

    readonly property var lockGroup: ["Greeter", "LnF", "General"]
    function lockOpt(key, def) { return backend.kconfigRead("kscreenlockerrc", lockGroup, key, def) }
    function setLock(key, value) { backend.kconfigWrite("kscreenlockerrc", lockGroup, key, value) }

    property string barPosition: backend.coucouBarPosition()
    property string barTone: backend.coucouSetting("barTone", "auto")
    property string barShape: backend.coucouSetting("barShape", "island")
    // Las burbujas de la barra (bar-layout.json → split)
    property string bubbles: backend.coucouBubbles()
    property string taskbar: backend.taskbarStyle()
    property bool loginCoucou: backend.fileExists("/etc/sddm.conf.d/99-coucou.conf")
    property bool splashOn: backend.kconfigRead("ksplashrc", ["KSplash"], "Engine", "KSplashQML") !== "none"
    property bool metaCoucou: backend.coucouState("meta-key") === "on"
    // Avisos por voz: el servicio coucou-voz activado para el usuario
    property bool voiceOn: backend.fileExists(backend.homePath() + "/.config/systemd/user/graphical-session.target.wants/coucou-voz.service")

    Timer {
        interval: 1500; repeat: true; running: root.visible
        onTriggered: {
            root.barPosition = backend.coucouBarPosition()
            root.barTone = backend.coucouSetting("barTone", "auto")
            root.barShape = backend.coucouSetting("barShape", "island")
            root.taskbar = backend.taskbarStyle()
            root.loginCoucou = backend.fileExists("/etc/sddm.conf.d/99-coucou.conf")
        }
    }

    readonly property var swatches: ["#6574F6", "#8B5CF6", "#EC4899", "#F43F5E", "#F97316", "#EAB308", "#22C55E", "#10B981", "#06B6D4", "#3B82F6"]

    // Un título de grupo y sus filas en una sola tarjeta redonda
    component Group: ColumnLayout {
        property string title
        default property alias rows: box.data
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 8
        Label { text: parent.title; color: win.subtext; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8; leftPadding: 6 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: box.implicitHeight
            radius: 16
            color: win.cardBg
            border.color: win.cardBorder
            ColumnLayout { id: box; anchors.left: parent.left; anchors.right: parent.right; spacing: 0 }
        }
    }
    // Una fila: icono en su cuadrito de color, título, descripción y control
    component Row_: Item {
        id: row
        property string title
        property string desc
        property string glyph: "advanced"
        property color tint: win.accent
        property bool last: false
        property alias control: slot.data
        signal clicked()
        property bool clickable: false
        Layout.fillWidth: true
        implicitHeight: Math.max(62, rl.implicitHeight + 22)
        Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 15; color: rowMouse.containsMouse && row.clickable ? win.cardHover : "transparent" }
        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: row.clickable; enabled: row.clickable; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
        RowLayout {
            id: rl
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9
                color: row.tint
                FluentIcon { anchors.centerIn: parent; name: row.glyph; size: 17; color: "#FFFFFF"; stroke: 1.6 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Label { Layout.fillWidth: true; text: row.title; color: win.text; font.pixelSize: 14; elide: Text.ElideRight }
                Label { Layout.fillWidth: true; visible: row.desc !== ""; text: row.desc; color: win.subtext; font.pixelSize: 12; wrapMode: Text.WordWrap }
            }
            RowLayout { id: slot; spacing: 8 }
        }
        Rectangle { visible: !row.last; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.leftMargin: 62; height: 1; color: win.cardBorder }
    }
    // Botones de dos o tres opciones, como los de iOS
    component Segmented: Rectangle {
        id: seg
        property var options: []
        property string value
        signal picked(string id)
        implicitWidth: segRow.implicitWidth + 6; implicitHeight: 32; radius: 10
        color: win.dark ? "#14FFFFFF" : "#10000000"
        Row {
            id: segRow; anchors.centerIn: parent; spacing: 2
            Repeater {
                model: seg.options
                Rectangle {
                    width: segLabel.implicitWidth + 26; height: 26; radius: 8
                    color: seg.value === modelData.id ? win.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Label { id: segLabel; anchors.centerIn: parent; text: modelData.name; font.pixelSize: 12; color: seg.value === modelData.id ? "#FFFFFF" : win.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(modelData.id) }
                }
            }
        }
    }
    component Preview: Button {
        text: "Vista previa"
        flat: false
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 860)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 8
            parts: [{ title: "Coucou" }]
        }

        // ── Portada ─────────────────────────────────────────────────────────
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            radius: 20
            color: "#000"
            layer.enabled: true
            layer.effect: OpacityMask { maskSource: Rectangle { width: hero.width; height: hero.height; radius: 20 } }
            Image { anchors.fill: parent; source: backend.wallpaper; sourceSize.width: 1200; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#E6110F29" }
                    GradientStop { position: 0.6; color: "#80110F29" }
                    GradientStop { position: 1; color: "#20110F29" }
                }
            }
            // La barra de Coucou en miniatura
            Rectangle {
                anchors { right: parent.right; rightMargin: 34 }
                y: root.barPosition === "bottom" ? parent.height - height - 18 : 18
                width: 250; height: 30; radius: 15
                color: "#D91E1B48"; border.color: "#80A79BFF"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: "#D8D4FF"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 16; height: 13; radius: 6; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter
                        Row { anchors.centerIn: parent; spacing: 3
                            Rectangle { width: 2; height: 4; radius: 1; color: "#1E1B48" }
                            Rectangle { width: 2; height: 4; radius: 1; color: "#1E1B48" } } }
                    Repeater { model: ["#F6C445", "#E5484D", "#3BA2FF", "#22C55E"]
                        Rectangle { width: 11; height: 11; radius: 3; color: modelData; anchors.verticalCenter: parent.verticalCenter } }
                    Item { width: 18; height: 1 }
                    Repeater { model: 3; Rectangle { width: 7; height: 7; radius: 3; color: "#D8D4FF"; anchors.verticalCenter: parent.verticalCenter } }
                    Rectangle { width: 26; height: 7; radius: 3; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            ColumnLayout {
                anchors { left: parent.left; leftMargin: 30; verticalCenter: parent.verticalCenter }
                width: parent.width * 0.5
                spacing: 6
                RowLayout {
                    spacing: 12
                    Image { source: "image://icon/coucou"; sourceSize: Qt.size(44, 44); Layout.preferredWidth: 44; Layout.preferredHeight: 44 }
                    Label { text: "Coucou Code"; color: "#FFFFFF"; font.pixelSize: 26; font.weight: Font.DemiBold }
                }
                Label {
                    Layout.fillWidth: true
                    text: win.coucou ? "Activo: la barra, el bloqueo, el inicio de sesión y esta ventana usan el diseño de Coucou."
                                     : "Pon todo el sistema con el diseño de Coucou: barra de vidrio, violeta, Mochi y bloqueo estilo iPhone."
                    color: "#DDE0FF"; font.pixelSize: 13; wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.topMargin: 8
                    implicitWidth: heroLabel.implicitWidth + 36; implicitHeight: 38; radius: 19
                    color: win.coucou ? "#33FFFFFF" : "#FFFFFF"
                    Label { id: heroLabel; anchors.centerIn: parent; text: win.coucou ? "Quitar Coucou Code" : "Activar Coucou Code"
                            color: win.coucou ? "#FFFFFF" : "#1E1B48"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!win.coucou) { win.applyCoucouCode(); return }
                            // Quitar: vuelve el tema de antes
                            const before = backend.rememberedTheme()
                            win.leaveCoucouCode()
                            backend.applyLookAndFeel(before.lookAndFeel || "org.kde.win11.desktop")
                        }
                    }
                }
            }
        }

        // ── Color ───────────────────────────────────────────────────────────
        Group {
            title: "Color y estilo"
            Row_ {
                title: "Color de énfasis"; desc: "Botones, selección, la barra y el bloqueo"; glyph: "palette"; tint: win.accent
                control: Row {
                    spacing: 6
                    Repeater {
                        model: root.swatches
                        Rectangle {
                            width: 24; height: 24; radius: 12; color: modelData
                            border.width: backend.accent.toUpperCase() === modelData.toUpperCase() ? 3 : 0
                            border.color: win.dark ? "#FFFFFF" : "#1A1A1A"
                            scale: sw.containsMouse ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            MouseArea { id: sw; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: win.setAppearance(backend.mode, modelData, backend.transparency) }
                        }
                    }
                }
            }
            Row_ {
                title: "Modo"; desc: "Violeta noche (oscuro) o lavanda y blanco (claro)"; glyph: "moon"; tint: "#4B4BA8"
                control: Segmented {
                    options: [{ id: "dark", name: "Oscuro" }, { id: "light", name: "Claro" }]
                    value: backend.mode
                    onPicked: id => win.setAppearance(id, backend.accent, backend.transparency)
                }
            }
            Row_ {
                title: "Transparencia"; desc: "Barras y menús de vidrio"; glyph: "opacity"; tint: "#0EA5E9"; last: true
                control: Switch { checked: backend.transparency; onToggled: win.setAppearance(backend.mode, backend.accent, checked) }
            }
        }

        // ── Fondo de pantalla ──────────────────────────────────────────────
        Group {
            title: "Fondo de pantalla"
            Item {
                id: wallBox
                Layout.fillWidth: true
                implicitHeight: wallCol.implicitHeight + 28
                property var all: backend.wallpapers()
                property string filter: "Todos"
                property bool alsoLock: true
                readonly property string current: String(backend.wallpaper).replace("file://", "")
                readonly property var groups: ["Todos"].concat(all.map(function (w) { return w.group }).filter(function (g, i, a) { return a.indexOf(g) === i }))
                readonly property var shown: all.filter(function (w) { return filter === "Todos" || w.group === filter })

                FileDialog {
                    id: wallPicker
                    title: "Elegir un fondo de pantalla"
                    nameFilters: ["Imágenes (*.jpg *.jpeg *.png *.webp)"]
                    onAccepted: backend.setWallpaper(String(selectedFile), wallBox.alsoLock)
                }

                ColumnLayout {
                    id: wallCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    // El fondo actual, grande, con las acciones
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Rectangle {
                            id: curWall
                            Layout.preferredWidth: 176; Layout.preferredHeight: 99; radius: 12
                            color: win.cardHover; clip: true
                            layer.enabled: true
                            layer.effect: OpacityMask { maskSource: Rectangle { width: curWall.width; height: curWall.height; radius: 12 } }
                            Image {
                                anchors.fill: parent
                                source: wallBox.current ? "image://thumb/" + encodeURIComponent(wallBox.current) : ""
                                sourceSize.width: 360
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            Label { text: "Fondo actual"; color: win.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Label { Layout.fillWidth: true; text: "Elige uno abajo o busca cualquier imagen de tu computadora."; color: win.subtext; font.pixelSize: 12; wrapMode: Text.WordWrap }
                            RowLayout {
                                spacing: 8
                                Button { text: "Elegir otra imagen…"; highlighted: true; onClicked: wallPicker.open() }
                                Button {
                                    text: "Usar también al iniciar sesión"
                                    flat: true
                                    onClicked: backend.launch("/usr/lib/coucou/admin", ["/usr/lib/coucou/login-theme", "coucou-login", String(backend.wallpaper)])
                                    ToolTip.visible: hovered; ToolTip.delay: 500
                                    ToolTip.text: "La pantalla de inicio de sesión toma este fondo (pide la contraseña de administrador)"
                                }
                            }
                            RowLayout {
                                spacing: 8
                                Switch { checked: wallBox.alsoLock; onToggled: wallBox.alsoLock = checked }
                                Label { text: "También en la pantalla de bloqueo"; color: win.text; font.pixelSize: 13 }
                            }
                        }
                    }

                    // Filtros: Todos, CachyOS, Sistema, Tus imágenes
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: wallBox.groups
                            Rectangle {
                                width: chipText.implicitWidth + 24; height: 28; radius: 14
                                color: wallBox.filter === modelData ? win.accent : (chipMouse.containsMouse ? win.cardHover : (win.dark ? "#14FFFFFF" : "#0F3C32A0"))
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Label { id: chipText; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: wallBox.filter === modelData ? "#FFFFFF" : win.text }
                                MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallBox.filter = modelData }
                            }
                        }
                    }

                    // La galería
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(2, Math.floor((width + 10) / 150))
                        columnSpacing: 10
                        rowSpacing: 10
                        Repeater {
                            model: wallBox.shown
                            Item {
                                id: tile
                                readonly property bool isCurrent: wallBox.current === modelData.path
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 9 / 16
                                Rectangle {
                                    id: tileBg
                                    anchors.fill: parent
                                    radius: 12
                                    color: win.cardHover
                                    layer.enabled: true
                                    layer.effect: OpacityMask { maskSource: Rectangle { width: tileBg.width; height: tileBg.height; radius: 12 } }
                                    Image {
                                        anchors.fill: parent
                                        source: "image://thumb/" + encodeURIComponent(modelData.path)
                                        sourceSize.width: 320
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        opacity: status === Image.Ready ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }
                                }
                                // Borde del seleccionado y al pasar el puntero
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: -3
                                    radius: 15; color: "transparent"
                                    border.width: tile.isCurrent ? 3 : (tileMouse.containsMouse ? 2 : 0)
                                    border.color: tile.isCurrent ? win.accent : Qt.alpha(win.accent, 0.6)
                                }
                                Rectangle {
                                    visible: tile.isCurrent
                                    anchors { right: parent.right; top: parent.top; margins: 8 }
                                    width: 22; height: 22; radius: 11; color: win.accent
                                    FluentIcon { anchors.centerIn: parent; name: "check"; size: 13; color: "#FFFFFF"; stroke: 2.2 }
                                }
                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.setWallpaper(modelData.path, wallBox.alsoLock)
                                }
                                ToolTip.visible: tileMouse.containsMouse; ToolTip.delay: 600; ToolTip.text: modelData.name
                            }
                        }
                    }
                }
            }
        }

        // ── Barra ───────────────────────────────────────────────────────────
        Group {
            title: "Barra"
            Row_ {
                title: "Barra de tareas"; glyph: "taskbar"; tint: "#6574F6"; clickable: true
                desc: root.taskbar === "coucou" ? "Forma, burbujas, pantalla y más" : "Volver a la barra de Coucou"
                onClicked: win.openPath("personalization", ["Barra de tareas"])
                control: Label { text: "›"; color: win.subtext; font.pixelSize: 20 }
            }
            Row_ {
                title: "Posición"; desc: "Arriba o abajo de la pantalla"; glyph: "display"; tint: "#8B5CF6"
                control: Segmented {
                    options: [{ id: "top", name: "Arriba" }, { id: "bottom", name: "Abajo" }]
                    value: root.barPosition
                    onPicked: id => { root.barPosition = id; backend.launch("coucou-launch", ["--bar-position", id]) }
                }
            }
            Row_ {
                title: "Forma"; glyph: "taskbar"; tint: "#0EA5E9"
                desc: root.barShape === "wide" ? "De lado a lado, flotando, con las puntas redondeadas"
                    : root.barShape === "edge" ? "De lado a lado, pegada al borde, recta como en Windows"
                    : "Una isla en el centro, flotando"
                control: Segmented {
                    options: [{ id: "island", name: "Isla" }, { id: "wide", name: "Ancha" }, { id: "edge", name: "Pegada" }]
                    value: root.barShape
                    onPicked: id => { root.barShape = id; backend.launch("coucou-launch", ["--bar-shape", id]) }
                }
            }
            Row_ {
                title: "Burbujas"; glyph: "multitask"; tint: "#14B8A6"
                desc: "Clic derecho en un grupo de la barra: burbuja propia y lado"
                control: Segmented {
                    options: [{ id: "one", name: "Una" }, { id: "clock", name: "Fecha aparte" }, { id: "all", name: "Todas" }, { id: "stretch", name: "Estiradas" }]
                    value: root.bubbles
                    onPicked: id => { root.bubbles = id; backend.launch("coucou-launch", ["--bar-bubbles", id]) }
                }
            }
            Row_ {
                title: "Colores de la barra"; glyph: "palette"; tint: "#EC4899"
                desc: root.barTone === "color" ? "Vidrio teñido con el color de énfasis"
                    : root.barTone === "light" ? "Siempre clara" : root.barTone === "dark" ? "Siempre oscura" : "Clara u oscura, como el sistema"
                control: Segmented {
                    options: [{ id: "auto", name: "Auto" }, { id: "light", name: "Clara" }, { id: "dark", name: "Oscura" }, { id: "color", name: "Color" }]
                    value: root.barTone
                    onPicked: id => { root.barTone = id; backend.launch("coucou-launch", ["--bar-tone", id, "--bar-accent", "auto"]) }
                }
            }
            Row_ {
                title: "Avisos por voz"; glyph: "sound"; tint: "#F97316"
                desc: "Sebastián lee en voz alta tus notificaciones y te avisa de las actualizaciones del sistema (no habla con «No molestar»)"
                control: RowLayout {
                    spacing: 8
                    Button {
                        text: "Probar"; flat: true
                        onClicked: backend.launch("/usr/lib/coucou/coucou-voz", ["--probar"])
                    }
                    Switch {
                        checked: root.voiceOn
                        onToggled: {
                            root.voiceOn = checked
                            backend.launch("systemctl", ["--user", checked ? "enable" : "disable", "--now", "coucou-voz.service"])
                        }
                    }
                }
            }
            Row_ {
                title: "Tecla Windows"; desc: "Abre el buscador de Coucou (apps, archivos y acciones)"; glyph: "keyboard"; tint: "#22C55E"
                control: Switch {
                    checked: root.metaCoucou
                    onToggled: {
                        root.metaCoucou = checked
                        backend.launch("coucou-launch", ["--meta-key", checked ? "on" : "off"])
                    }
                }
            }
            Row_ {
                title: "Mochi, el chat y la barra"; desc: "Íconos, botones, notificaciones y más, en los ajustes de Coucou"; glyph: "sparkle"; tint: "#EC4899"; last: true; clickable: true
                onClicked: backend.launch("coucou-launch", ["--open-settings"])
                control: Label { text: "↗"; color: win.subtext; font.pixelSize: 16 }
            }
        }

        // ── Pantalla de bloqueo ────────────────────────────────────────────
        Group {
            title: "Pantalla de bloqueo"
            Row_ {
                title: "Hora de 24 horas"; desc: "13:45 en vez de 1:45"; glyph: "clock"; tint: "#F97316"
                control: Switch { checked: root.lockOpt("coucouClock24", "true") === "true"; onToggled: root.setLock("coucouClock24", checked ? "true" : "false") }
            }
            Row_ {
                title: "Hora en negrita"; desc: "Gruesa como el iPhone, o fina y elegante"; glyph: "font"; tint: "#EAB308"
                control: Switch { checked: root.lockOpt("coucouClockBold", "true") === "true"; onToggled: root.setLock("coucouClockBold", checked ? "true" : "false") }
            }
            Row_ {
                title: "Mostrar la fecha"; glyph: "clock"; tint: "#10B981"
                control: Switch { checked: root.lockOpt("coucouShowDate", "true") === "true"; onToggled: root.setLock("coucouShowDate", checked ? "true" : "false") }
            }
            Row_ {
                title: "Desenfoque al desbloquear"; desc: "Cuánto se difumina el fondo"; glyph: "focus"; tint: "#06B6D4"
                control: Slider {
                    from: 0; to: 100; implicitWidth: 180
                    value: Number(root.lockOpt("coucouBlur", "80"))
                    onMoved: root.setLock("coucouBlur", String(Math.round(value)))
                }
            }
            Row_ {
                title: "Mochi en vez de tu foto"; glyph: "user"; tint: "#8B5CF6"
                control: Switch { checked: root.lockOpt("coucouUseMochi", "false") === "true"; onToggled: root.setLock("coucouUseMochi", checked ? "true" : "false") }
            }
            Row_ {
                title: "“Pulsa una tecla”"; desc: "La pista y la barrita de abajo, en reposo"; glyph: "eye"; tint: "#3B82F6"
                control: Switch { checked: root.lockOpt("coucouShowHint", "true") === "true"; onToggled: root.setLock("coucouShowHint", checked ? "true" : "false") }
            }
            Row_ {
                title: "Botón de suspender"; glyph: "moon"; tint: "#4B4BA8"
                control: Switch { checked: root.lockOpt("coucouShowSuspend", "true") === "true"; onToggled: root.setLock("coucouShowSuspend", checked ? "true" : "false") }
            }
            Row_ {
                title: "Bloquear al suspender"; desc: "Pide la contraseña al volver"; glyph: "lock"; tint: "#F43F5E"
                control: Switch {
                    checked: backend.kconfigRead("kscreenlockerrc", ["Daemon"], "LockOnResume", "true") === "true"
                    onToggled: backend.kconfigWrite("kscreenlockerrc", ["Daemon"], "LockOnResume", checked ? "true" : "false")
                }
            }
            Row_ {
                title: "Bloquear solo tras"; desc: "Minutos sin usar el equipo"; glyph: "history"; tint: "#64748B"; last: true
                control: RowLayout {
                    SpinBox {
                        from: 1; to: 120
                        value: Number(backend.kconfigRead("kscreenlockerrc", ["Daemon"], "Timeout", "5"))
                        onValueModified: backend.kconfigWrite("kscreenlockerrc", ["Daemon"], "Timeout", String(value))
                    }
                    Button { text: "Vista previa"; enabled: win.coucou; onClicked: backend.launch("/usr/lib/kscreenlocker_greet", ["--testing"]) }
                }
            }
        }

        // ── Inicio de sesión, carga, apagado ───────────────────────────────
        Group {
            title: "Inicio de sesión y arranque"
            Row_ {
                title: "Inicio de sesión de Coucou"; desc: "Pide la contraseña de administrador"; glyph: "user"; tint: "#6574F6"
                control: RowLayout {
                    Button { text: "Vista previa"; onClicked: backend.launch("sddm-greeter-qt6", ["--test-mode", "--theme", "/usr/share/sddm/themes/coucou-login"]) }
                    Switch {
                        checked: root.loginCoucou
                        onToggled: backend.launch("/usr/lib/coucou/admin", checked ? ["/usr/lib/coucou/login-theme", "coucou-login", String(backend.wallpaper)]
                                                                    : ["/usr/lib/coucou/login-theme", "default"])
                    }
                }
            }
            Row_ {
                title: "Pantalla de carga con Mochi"; desc: "Al iniciar la sesión"; glyph: "activation"; tint: "#EC4899"; last: true
                control: RowLayout {
                    Button { text: "Vista previa"; onClicked: backend.launch("ksplashqml", ["org.coucou.code", "--test", "--window"]) }
                    Switch {
                        checked: root.splashOn
                        onToggled: {
                            root.splashOn = checked
                            backend.kconfigWrite("ksplashrc", ["KSplash"], "Engine", checked ? "KSplashQML" : "none")
                            if (checked) backend.kconfigWrite("ksplashrc", ["KSplash"], "Theme", win.coucou ? win.coucouId : backend.currentLookAndFeel())
                        }
                    }
                }
            }
        }

        Label {
            Layout.topMargin: 18
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: win.subtext
            text: "Los cambios se guardan solos. La pantalla de bloqueo los toma la próxima vez que se bloquea; la vista previa la muestra en una ventana (ciérrala con tu contraseña o con la X)."
        }
        Item { Layout.preferredHeight: 24 }
    }
}
