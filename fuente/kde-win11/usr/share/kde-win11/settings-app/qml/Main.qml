import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    // Paleta de Configuración de Windows 11 (fondo Mica aproximado)
    readonly property bool dark: backend.mode === "dark"
    property color accent: backend.uiAccent()
    readonly property color bg: dark ? "#202020" : "#F3F3F3"
    readonly property color cardBg: dark ? "#2B2B2B" : "#FBFBFB"
    readonly property color cardHover: dark ? "#323232" : "#F6F6F6"
    readonly property color cardBorder: dark ? "#1D1D1D" : "#E5E5E5"
    readonly property color navHover: dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color navSelected: dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color text: dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: dark ? "#C5C5C5" : "#5F5F5F"
    readonly property string fontFamily: "Selawik"
    readonly property bool maximized: visibility === Window.Maximized

    font.family: fontFamily
    font.pixelSize: 14
    color: bg

    Connections {
        target: backend
        function onThemeChanged() { win.accent = backend.uiAccent() }
    }

    // La biblioteca de páginas oculta lo que este equipo no tiene (batería, táctil, módem...)
    readonly property bool hardwareReady: P.setHardware(function (w) { return backend.hasHardware(w) })

    // Navegación: categoría + pila de subpáginas
    property string currentId: startPage && P.byId(startPage.split("/")[0]) ? startPage.split("/")[0] : "home"
    property var crumbs: []          // [{page, title, list}]
    property string search: ""
    // La página actual puede quedarse el "atrás" (p. ej. subpáginas de un módulo de KDE)
    property var backHook: null

    function openCategory(id) { currentId = id; crumbs = []; search = ""; searchField.text = "" }
    function openSub(page, title, list) { crumbs = crumbs.concat([{ page: page, title: title, list: list }]) }
    function back() {
        if (backHook && backHook()) return
        if (search !== "") { searchField.text = ""; return }
        if (crumbs.length) crumbs = crumbs.slice(0, crumbs.length - 1)
        else if (currentId !== "home") currentId = "home"
    }
    function popTo(depth) { crumbs = crumbs.slice(0, depth) }   // 0 = volver a la categoría
    readonly property var pathParts: [{ title: P.byId(currentId).title }].concat(crumbs.map(function (c) { return { title: c.title } }))
    readonly property bool canGoBack: crumbs.length > 0 || search !== "" || currentId !== "home"

    function activate(item) {
        if (search !== "") { search = ""; searchField.text = "" }
        if (item.items) openSub("list", item.title, item)
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

    Component.onCompleted: {
        // Ruta directa: win11-settings "system/Acerca de"
        var parts = startPage.split("/")
        if (parts.length > 1 && P.byId(parts[0])) openPath(parts[0], parts.slice(1))
        else if (startPage === "colors") { currentId = "personalization"; openSub("colors", "Colores") }
        else if (startPage === "installed") { currentId = "apps"; openSub("installed", "Aplicaciones instaladas") }
    }

    Shortcut { sequences: ["Alt+Left", StandardKey.Back]; onActivated: win.back() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Escape"; enabled: win.search !== ""; onActivated: searchField.text = "" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: content
                    anchors.fill: parent
                    anchors.topMargin: 6
                    property var category: P.byId(win.currentId)
                    property var sub: win.crumbs.length ? win.crumbs[win.crumbs.length - 1] : null
                    sourceComponent: {
                        if (win.search !== "") return searchPage
                        if (sub) {
                            if (sub.page === "list") return linksPage
                            if (sub.page === "colors") return colorsPage
                            if (sub.page === "installed") return appsPage
                            if (sub.page === "clipboard") return clipboardPage
                            if (sub.page === "kcm") return kcmPage
                        }
                        switch (category.type) {
                        case "home": return homePage
                        case "system": return systemPage
                        case "personalization": return personalizationPage
                        case "update": return updatePage
                        default: return linksPage
                        }
                    }
                    // Animación de entrada como en Windows 11 (desliza hacia arriba + fundido)
                    onLoaded: { item.opacity = 0; item.y = 24; enter.restart() }
                    ParallelAnimation {
                        id: enter
                        NumberAnimation { target: content.item; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: content.item; property: "y"; to: 0; duration: 280; easing.type: Easing.OutCubic }
                    }
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

    Component { id: linksPage; LinksPage { category: content.sub && content.sub.list ? content.sub.list : content.category } }
    Component { id: homePage; HomePage {} }
    Component { id: systemPage; SystemPage { category: content.category } }
    Component { id: personalizationPage; PersonalizationPage { category: content.category } }
    Component { id: colorsPage; ColorsPage {} }
    Component { id: appsPage; AppsPage {} }
    Component { id: clipboardPage; ClipboardPage {} }
    Component { id: kcmPage; KcmPage { kcm: content.sub && content.sub.list ? content.sub.list.kcm : "" } }
    Component { id: updatePage; UpdatePage {} }
    Component { id: searchPage; SearchPage { query: win.search } }
}
