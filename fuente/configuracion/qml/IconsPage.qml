import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Personalización › Iconos. De arriba abajo:
//   1. En uso: el tema de ahora con una muestra grande, y "Restablecer" (todo como vino).
//   2. Color de las carpetas (del tema de Coucou: Papirus con carpetas del color elegido).
//   3. Temas instalados, con buscador. Un clic lo aplica en todo: explorador, apps, menús, la barra
//      de Coucou y las apps GTK; al cambiar entre claro y oscuro se usa su variante.
//   4. Explorador de archivos (los iconos de su panel lateral), más temas para bajar y opciones de KDE.
// Todo lo hace /usr/lib/coucou/coucou-iconos (por backend.launch); lo elegido se lee de
// backend.iconThemes() (el tema) y de ~/.config/coucouiconosrc (el color de las carpetas).
// Se acomoda al ancho de la ventana: las tarjetas pasan de 4 por fila a 1.
ScrollView {
    id: root
    contentWidth: availableWidth

    property var data: backend.iconThemes()
    property string choice: data.choice || "auto"
    property var families: data.families || []
    property string folderColor: backend.kconfigRead("coucouiconosrc", ["Iconos"], "Carpetas", "violet")
    property string applying: ""        // lo que se está aplicando: un tema, "color:<c>", "reset", "lugares"
    property string installing: ""
    property string note: ""
    property string filter: ""
    property bool askReopen: false
    property bool confirmReset: false
    property bool showVariants: false
    property int rev: 0                 // sube tras aplicar algo: las muestras se vuelven a leer
    readonly property bool darkMode: win.dark
    readonly property string tool: "/usr/lib/coucou/coucou-iconos"
    readonly property bool hasCoucou: backend.fileExists("/usr/share/icons/Coucou/index.theme")
    readonly property string autoTheme: hasCoucou ? (darkMode ? "Coucou-Dark" : "Coucou") : (darkMode ? "Win11-dark" : "Win11")

    // Medidas: el ancho útil y cuántas tarjetas entran por fila
    readonly property real pageW: Math.max(260, Math.min(root.availableWidth - 32, 1000))
    readonly property int cols: Math.max(1, Math.floor((pageW + 12) / 236))
    readonly property real cardW: (pageW - 12 * (cols - 1)) / cols
    readonly property bool narrow: pageW < 620

    // El tema en uso: { id, name, theme }
    readonly property var current: {
        if (choice === "auto")
            return { id: "auto", name: hasCoucou ? "Coucou" : "Automático", theme: autoTheme, auto: true }
        for (var i = 0; i < families.length; i++)
            if (families[i].id === choice)
                return { id: choice, name: families[i].name, theme: variantOf(families[i]), auto: false }
        return { id: "auto", name: "Automático", theme: autoTheme, auto: true }
    }
    readonly property bool usesCoucou: current.theme.indexOf("Coucou") === 0
    readonly property bool isDefault: choice === "auto" && folderColor === "violet"

    // Lo que se ve en las muestras: carpetas y archivos de todos los días
    readonly property var sample: [
        ["folder"], ["folder-documents"], ["folder-download", "folder-downloads"], ["folder-pictures", "folder-images"],
        ["folder-music", "folder-sound"], ["user-home", "folder-home"], ["user-desktop"], ["user-trash"],
        ["application-pdf", "x-office-document"], ["image-png", "image-x-generic"], ["application-zip", "package-x-generic"],
        ["text-plain", "text-x-generic"], ["video-mp4", "video-x-generic"], ["audio-mpeg", "audio-x-generic"],
        ["computer"], ["network-workgroup", "folder-network"]
    ]

    // Colores de carpetas de Papirus (los que no estén instalados no se muestran)
    readonly property var colors: [
        { id: "violet", name: "Violeta" }, { id: "indigo", name: "Índigo" }, { id: "blue", name: "Azul" },
        { id: "cyan", name: "Celeste" }, { id: "teal", name: "Turquesa" }, { id: "green", name: "Verde" },
        { id: "yellow", name: "Amarillo" }, { id: "orange", name: "Naranja" }, { id: "red", name: "Rojo" },
        { id: "pink", name: "Rosa" }, { id: "magenta", name: "Magenta" }, { id: "brown", name: "Marrón" },
        { id: "grey", name: "Gris" }, { id: "black", name: "Negro" }
    ].filter(function (c) { return backend.fileExists("/usr/share/icons/Papirus/48x48/places/folder-" + c.id + ".svg") })

    // Más temas de los repositorios de CachyOS/Arch (se bajan con la contraseña de administrador)
    readonly property var extras: [
        { pkg: "papirus-icon-theme", id: "Papirus", name: "Papirus", desc: "Planos y coloridos, los más completos", colors: ["#5294E2", "#F2C14E", "#E5484D"] },
        { pkg: "tela-circle-icon-theme-purple", id: "Tela-circle-purple", name: "Tela Circle violeta", desc: "Apps redondas, carpetas violetas", colors: ["#7E57C2", "#9575CD", "#B39DDB"] },
        { pkg: "tela-circle-icon-theme-standard", id: "Tela-circle", name: "Tela Circle", desc: "Apps redondas, carpetas azules", colors: ["#5677FC", "#7C93FF", "#AEBBFF"] },
        { pkg: "qogir-icon-theme", id: "Qogir", name: "Qogir", desc: "Suaves y modernos, carpetas celestes", colors: ["#5E9EF0", "#8DBBF5", "#C7DDFB"] },
        { pkg: "pop-icon-theme", id: "Pop", name: "Pop!_OS", desc: "Cálidos y redondeados", colors: ["#48B9C7", "#F6A623", "#574F4A"] },
        { pkg: "elementary-icon-theme", id: "elementary", name: "elementary OS", desc: "Detallados, al estilo macOS", colors: ["#64BAFF", "#FFC27D", "#9BDB4D"] },
        { pkg: "obsidian-icon-theme", id: "Obsidian", name: "Obsidian", desc: "Basados en Faenza, carpetas grises", colors: ["#6E6E6E", "#9E9E9E", "#E0E0E0"] }
    ]

    function reload() {
        data = backend.iconThemes()
        folderColor = backend.kconfigRead("coucouiconosrc", ["Iconos"], "Carpetas", "violet")
        rev++
    }
    function has(id) {
        for (var i = 0; i < families.length; i++) if (families[i].id === id) return true
        return false
    }
    function variantOf(f) { return root.darkMode ? f.dark : f.light }
    function iconOf(theme, names) {
        for (var i = 0; i < names.length; i++) {
            var f = backend.iconFile(theme, names[i])
            if (f !== "") return f
        }
        return ""
    }
    // Aplicar algo: lo hace coucou-iconos y la página se refresca cuando termina
    function run(args, tag) {
        if (applying !== "") return
        applying = tag
        confirmReset = false
        backend.launch(tool, args)
        doneTimer.restart()
    }
    function pick(id) {
        if (applying !== "" || (id === choice)) return
        applying = id
        choice = id
        backend.setIconTheme(id)
        doneTimer.restart()
    }
    // Variantes de un tema (Obsidian-Amber, Obsidian-Gray… de Obsidian): ocultas salvo que se pidan,
    // se busquen o una esté en uso
    function isVariant(f) {
        var i = f.id.indexOf("-")
        return i > 0 && has(f.id.slice(0, i))
    }
    readonly property int variantCount: families.filter(function (f) { return isVariant(f) }).length
    function shown(f) {
        if (f.id === "Coucou" && hasCoucou) return false     // ya está como "Coucou (automático)"
        if (!matches(f.name)) return false
        return !isVariant(f) || showVariants || filter !== "" || f.id === choice
    }
    function matches(name) {
        return filter === "" || name.toLowerCase().indexOf(filter.toLowerCase()) >= 0
    }

    Timer {
        id: doneTimer
        interval: 2200
        onTriggered: { root.applying = ""; root.reload(); root.askReopen = backend.explorerOpen() }
    }
    Connections {
        target: backend
        // Lo bajado de la tienda o de los repositorios aparece enseguida para elegirlo
        function onStoreClosed(knsrc) { if (knsrc === "icons") root.reload() }
        function onIconPackInstalled(pkg, ok) {
            root.installing = ""
            root.reload()
            root.note = ok ? "" : "No se pudo bajar el tema (¿sin internet o contraseña cancelada?)."
        }
    }

    // ── Piezas ───────────────────────────────────────────────────────────────

    // Título de una sección, con su explicación
    component Section: ColumnLayout {
        id: sec
        property string title
        property string text
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 2
        Label { text: sec.title; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text }
        Label {
            Layout.fillWidth: true
            visible: sec.text !== ""
            text: sec.text
            color: win.subtext; wrapMode: Text.WordWrap; font.pixelSize: 12
        }
    }

    // Muestra de iconos de un tema
    component Sample: Grid {
        id: s
        property string theme
        property int count: 8
        property int size: 32
        columns: 4
        spacing: Math.round(size / 3)
        Repeater {
            model: root.sample.slice(0, s.count)
            Image {
                width: s.size; height: s.size
                sourceSize: Qt.size(s.size * 2, s.size * 2)
                source: (root.rev, root.iconOf(s.theme, modelData))
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
            }
        }
    }

    // Tarjeta de un tema: la muestra arriba, el nombre abajo
    component ThemeCard: Rectangle {
        id: card
        property string title
        property string subtitle
        property bool active
        property bool busy
        property alias content: slot.data
        signal picked()
        width: root.cardW; height: 186
        radius: 8
        color: hover.containsMouse ? win.cardHover : win.cardBg
        border.width: active ? 2 : 1
        border.color: active ? win.accent : win.cardBorder
        scale: hover.pressed ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        Rectangle {
            id: box
            x: 8; y: 8; width: parent.width - 16; height: 116
            radius: 6; clip: true
            color: win.dark ? "#1C1B2E" : "#F6F5FC"
            border.width: 1; border.color: win.dark ? "#2A2840" : "#E6E3F5"
            Item { id: slot; anchors.fill: parent }
            Rectangle {
                visible: card.active && !card.busy
                anchors { right: parent.right; top: parent.top; margins: 6 }
                width: 22; height: 22; radius: 11; color: win.accent
                Label { anchors.centerIn: parent; text: "✓"; color: "#FFF"; font.pixelSize: 13; font.bold: true }
            }
            Rectangle {
                visible: card.busy
                anchors.fill: parent; color: "#80000000"; radius: 6
                BusyIndicator { anchors.centerIn: parent; running: card.busy; width: 34; height: 34 }
            }
        }
        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: box.bottom; margins: 12; topMargin: 9 }
            spacing: 1
            Label { Layout.fillWidth: true; text: card.title; color: win.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label {
                Layout.fillWidth: true
                text: card.busy ? "Aplicando…" : (card.active ? "En uso" : card.subtitle)
                color: card.active && !card.busy ? win.accent : win.subtext; font.pixelSize: 11; elide: Text.ElideRight
            }
        }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
    }

    // Un aviso dentro de la página (con sus botones a la derecha, o abajo si no entran)
    component Notice: Rectangle {
        id: n
        property string text
        property alias buttons: btns.data
        Layout.fillWidth: true
        implicitHeight: lay.implicitHeight + 24
        radius: 8
        color: win.dark ? "#2A2550" : "#EEEBFD"
        border.width: 1; border.color: win.dark ? "#3D3770" : "#D9D3FA"
        GridLayout {
            id: lay
            anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 12; bottomMargin: 12 }
            columns: root.narrow ? 1 : 2
            columnSpacing: 12; rowSpacing: 8
            Label { Layout.fillWidth: true; text: n.text; color: win.text; wrapMode: Text.WordWrap; font.pixelSize: 12 }
            RowLayout { id: btns; spacing: 8 }
        }
    }

    // ── La página ────────────────────────────────────────────────────────────

    ColumnLayout {
        width: root.pageW
        x: Math.max(8, (root.availableWidth - width) / 2 - 8)
        spacing: 6

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            parts: [{ title: "Personalización" }, { title: "Iconos" }]
        }

        // 1. En uso ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: inUse.implicitHeight + 32
            radius: win.cardRadius
            color: win.cardBg
            border.color: win.cardBorder

            GridLayout {
                id: inUse
                anchors { fill: parent; margins: 16 }
                columns: root.narrow ? 1 : 2
                columnSpacing: 20; rowSpacing: 14

                Rectangle {
                    Layout.preferredWidth: root.narrow ? -1 : 300
                    Layout.fillWidth: root.narrow
                    Layout.preferredHeight: big.implicitHeight + 28
                    radius: 8
                    color: win.dark ? "#1C1B2E" : "#F6F5FC"
                    border.width: 1; border.color: win.dark ? "#2A2840" : "#E6E3F5"
                    Sample { id: big; anchors.centerIn: parent; theme: root.current.theme; count: 8; size: 44 }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    Label { text: "En uso"; color: win.subtext; font.pixelSize: 12 }
                    Label {
                        Layout.fillWidth: true
                        text: root.current.name + (root.usesCoucou && root.folderColor !== "violet"
                              ? " · carpetas " + (root.colors.find(function (c) { return c.id === root.folderColor }) || { name: root.folderColor }).name.toLowerCase() : "")
                        color: win.text; font.pixelSize: 20; font.weight: Font.DemiBold; wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.current.auto ? "Los del diseño de Coucou. Cambian solos entre claro y oscuro."
                                                : "Elegido por ti. Cambia solo entre su versión clara y oscura."
                        color: win.subtext; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8
                        Button {
                            text: "Restablecer"
                            icon.name: "edit-undo"
                            enabled: !root.isDefault && root.applying === ""
                            onClicked: root.confirmReset = true
                        }
                        Button {
                            text: "Más opciones (KDE)"
                            icon.name: "configure"
                            flat: true
                            onClicked: win.openSub("kcm", "Más opciones de iconos", { kcm: "kcm_icons", title: "Más opciones de iconos" })
                        }
                    }
                    Label {
                        visible: root.isDefault
                        text: "Ya están los iconos de siempre."
                        color: win.subtext; font.pixelSize: 11
                    }
                }
            }
        }

        // Restablecer: se confirma antes
        Notice {
            visible: root.confirmReset
            Layout.topMargin: 6
            text: "Vuelven los iconos de Coucou con carpetas violetas, y los del panel del explorador se reparan. Los temas que bajaste quedan instalados para elegirlos otra vez."
            buttons: [
                Button { text: "Restablecer"; highlighted: true; onClicked: root.run(["restablecer"], "reset") },
                Button { text: "Cancelar"; flat: true; onClicked: root.confirmReset = false }
            ]
        }
        // El explorador que ya estaba abierto toma los iconos al reabrirlo
        Notice {
            visible: root.askReopen && root.applying === ""
            Layout.topMargin: 6
            text: "El explorador de archivos que ya estaba abierto toma los iconos nuevos al reabrirlo (vuelve a las mismas carpetas)."
            buttons: [
                Button { text: "Reabrir el explorador"; highlighted: true; onClicked: { backend.reopenExplorer(); root.askReopen = false } },
                Button { text: "Ahora no"; flat: true; onClicked: root.askReopen = false }
            ]
        }
        Label {
            visible: root.applying === "reset" || root.applying === "lugares" || root.applying.indexOf("color:") === 0
            Layout.topMargin: 6
            text: "Aplicando…"
            color: win.accent; font.pixelSize: 12
        }

        // 2. Color de las carpetas ─────────────────────────────────────────────
        Section {
            visible: root.hasCoucou && root.colors.length > 0
            title: "Color de las carpetas"
            text: root.usesCoucou ? "Las carpetas del tema de Coucou, en el color que quieras. Solo en tu cuenta."
                                  : "Es para el tema de Coucou, que ahora no está en uso."
        }
        Flow {
            visible: root.hasCoucou && root.colors.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            opacity: root.usesCoucou ? 1 : 0.45
            Repeater {
                model: root.colors
                delegate: Rectangle {
                    id: sw
                    required property var modelData
                    readonly property bool on: root.folderColor === modelData.id
                    readonly property bool busy: root.applying === "color:" + modelData.id
                    width: 76; height: 84
                    radius: 8
                    color: swMouse.containsMouse && root.usesCoucou ? win.cardHover : win.cardBg
                    border.width: on ? 2 : 1
                    border.color: on ? win.accent : win.cardBorder
                    Image {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                        width: 40; height: 40
                        sourceSize: Qt.size(80, 80)
                        source: "file:///usr/share/icons/Papirus/48x48/places/folder-" + sw.modelData.id + ".svg"
                        opacity: sw.busy ? 0.4 : 1
                    }
                    BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 40; height: 40; running: sw.busy; visible: sw.busy }
                    Label {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8; leftMargin: 4; rightMargin: 4 }
                        horizontalAlignment: Text.AlignHCenter
                        text: sw.modelData.name
                        color: sw.on ? win.accent : win.subtext
                        font.pixelSize: 11; elide: Text.ElideRight
                    }
                    MouseArea {
                        id: swMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.usesCoucou && !sw.on
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.run(["carpetas", sw.modelData.id], "color:" + sw.modelData.id)
                    }
                }
            }
        }
        Button {
            visible: root.hasCoucou && !root.usesCoucou
            Layout.topMargin: 6
            text: "Usar los iconos de Coucou"
            onClicked: root.pick("auto")
        }

        // 3. Temas instalados ──────────────────────────────────────────────────
        Section {
            title: "Temas de iconos"
            text: "Haz clic en uno para usarlo en todo: el explorador de archivos, las apps, los menús y la barra. Al cambiar entre claro y oscuro se usa su versión clara u oscura."
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            spacing: 16
            TextField {
                width: Math.min(340, root.pageW)
                visible: root.families.length > 6
                placeholderText: "Buscar un tema…"
                onTextChanged: root.filter = text.trim()
            }
            Switch {
                visible: root.variantCount > 0
                text: "Mostrar variantes (" + root.variantCount + ")"
                checked: root.showVariants
                onToggled: root.showVariants = checked
            }
        }
        // Las tarjetas de los temas se arman después de abrir la ventana (cada una busca 8 iconos en su
        // tema): así la página aparece enseguida y no se traba
        Loader {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: item ? item.implicitHeight : 200
            asynchronous: true
            sourceComponent: Component {
                Flow {
                    width: root.pageW
                    spacing: 12

                    ThemeCard {
                        visible: root.matches("Coucou Automático")
                        title: root.hasCoucou ? "Coucou (automático)" : "Automático"
                        subtitle: "Los del diseño, carpetas violetas"
                        active: root.choice === "auto" && root.applying === ""
                        busy: root.applying === "auto"
                        onPicked: root.pick("auto")
                        content: Sample { anchors.centerIn: parent; theme: root.autoTheme }
                    }
                    Repeater {
                        // Solo las tarjetas que se ven: cada una lee 8 iconos y con muchos temas (las variantes
                        // de Obsidian son 23) la página tardaba en abrir
                        model: root.families.filter(function (f) { return root.shown(f) })
                        delegate: ThemeCard {
                            required property var modelData
                            title: modelData.name
                            subtitle: modelData.light !== modelData.dark ? "Claro y oscuro" : modelData.light
                            active: root.choice === modelData.id && root.applying === ""
                            busy: root.applying === modelData.id
                            onPicked: root.pick(modelData.id)
                            content: Sample { anchors.centerIn: parent; theme: root.variantOf(modelData) }
                        }
                    }
                }
            }
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: parent.status !== Loader.Ready; visible: running }
        }

        // 4. Explorador de archivos ────────────────────────────────────────────
        Section {
            title: "Explorador de archivos"
            text: ""
        }
        SettingsCard {
            Layout.fillWidth: true
            Layout.topMargin: 6
            bottomRadius: 0
            clickable: false
            iconName: "user-home"
            title: "Iconos del panel lateral"
            description: "Inicio, Descargas, Documentos, Papelera… vuelven a tomar los del tema elegido"
            trailing: Button {
                text: root.applying === "lugares" ? "Reparando…" : "Reparar"
                enabled: root.applying === ""
                onClicked: root.run(["lugares"], "lugares")
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            topRadius: 0
            clickable: false
            iconName: "system-file-manager"
            title: "Ventanas del explorador abiertas"
            description: "Se cierran y se vuelven a abrir en las mismas carpetas, con los iconos nuevos"
            trailing: Button {
                text: "Reabrir"
                onClicked: { backend.reopenExplorer(); root.askReopen = false }
            }
        }

        // 5. Más temas ─────────────────────────────────────────────────────────
        Section {
            title: "Más temas para descargar"
            text: "Se bajan de los repositorios de CachyOS (pide la contraseña de administrador) y quedan arriba para elegir."
        }
        Label {
            visible: root.note !== ""
            Layout.fillWidth: true
            text: root.note; color: "#E5484D"; wrapMode: Text.WordWrap
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 12
            Repeater {
                model: root.extras.filter(function (e) { return !root.has(e.id) })
                delegate: ThemeCard {
                    required property var modelData
                    title: modelData.name
                    subtitle: root.installing === modelData.pkg ? "Descargando…" : modelData.desc
                    busy: root.installing === modelData.pkg
                    onPicked: {
                        if (root.installing !== "") return
                        root.note = ""
                        root.installing = modelData.pkg
                        backend.installIconPack(modelData.pkg)
                    }
                    content: [
                        Row {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -10
                            spacing: 12
                            Repeater {
                                model: modelData.colors
                                // Una carpeta dibujada con los colores del tema
                                Item {
                                    width: 40; height: 32
                                    Rectangle { x: 0; y: 0; width: 18; height: 9; radius: 3; color: Qt.darker(modelData, 1.15) }
                                    Rectangle { x: 0; y: 5; width: 40; height: 27; radius: 4; color: modelData }
                                }
                            }
                        },
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
                            width: dl.implicitWidth + 20; height: 22; radius: 11; color: win.accent
                            Label { id: dl; anchors.centerIn: parent; text: "↓ Descargar"; color: "#FFF"; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                    ]
                }
            }
        }
        Button {
            Layout.topMargin: 10
            Layout.bottomMargin: 30
            text: "Descargar de la tienda de KDE"
            icon.name: "get-hot-new-stuff"
            onClicked: backend.openStore("icons")
        }
    }
}
