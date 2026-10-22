import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

ApplicationWindow {
    id: win
    width: 1280
    height: 820
    minimumWidth: 760
    minimumHeight: 520
    visible: true
    title: "Tienda"
    flags: Qt.Window | Qt.FramelessWindowHint
    readonly property bool maximized: visibility === Window.Maximized
    // Efectos con sombreadores (desenfoque, máscaras): no disponibles en el renderizador por software
    readonly property bool fx: !gfx.software

    // Paleta de la Microsoft Store de Windows 11 (Mica + capa de contenido)
    readonly property bool dark: store.mode === "dark"
    readonly property color accent: store.accent
    readonly property color bg: dark ? "#202020" : "#F3F3F3"
    readonly property color layer: dark ? "#272727" : "#F9F9F9"
    readonly property color cardBg: dark ? "#2D2D2D" : "#FFFFFF"
    readonly property color cardHover: dark ? "#353535" : "#F6F6F6"
    readonly property color cardBorder: dark ? "#1F1F1F" : "#E5E5E5"
    readonly property color cardBorderHover: dark ? "#454545" : "#CFCFCF"
    readonly property color panelBg: dark ? "#2B2B2B" : "#FFFFFF"
    readonly property color navHover: dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color text: dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: dark ? "#C5C5C5" : "#5F5F5F"

    font.family: "Selawik"
    font.pixelSize: 14
    color: bg

    property string section: "home"

    function go(s) {
        section = s
        var comp = s === "apps" ? appsPage : s === "games" ? gamesPage : s === "library" ? libraryPage
                 : s === "downloads" ? downloadsPage : s === "news" ? newsPage : homePage
        stack.replace(null, comp, {}, StackView.Immediate)
    }
    function openApp(app) {
        if (!app) return
        stack.push(appPage, { app: app })
    }
    // Página Aplicaciones con una categoría ya elegida (índice de chip)
    function openCategory(index) {
        stack.push(appsPage, { current: index })
    }
    function openList(title, fetch) {
        stack.push(browsePage, { title: title, sections: [{ title: title, fetch: fetch }] })
    }
    function search(q) {
        q = q.trim()
        if (!q) return
        suggestions.close()
        stack.push(searchPage, { query: q })
    }

    Component.onCompleted: {
        if (startPage === "updates" || startPage === "downloads") go("downloads")
        else if (startPage === "library") go("library")
        else if (startPage === "apps" || startPage === "games") go(startPage)
        else if (startPage.indexOf("search:") === 0) search(startPage.slice(7))
        else if (startPage.indexOf("appstream://") === 0) openApp({ app_id: startPage.slice(12) })
        else if (startPage.indexOf(".") > 0) openApp({ app_id: startPage })
    }

    Shortcut { sequences: [StandardKey.Back, "Alt+Left", "Backspace"]; enabled: stack.depth > 1 && !searchField.activeFocus; onActivated: stack.pop() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }

    // Avisos breves (errores de instalación, "instalado correctamente")
    Connections {
        target: store
        function onNotify(text, error) { toast.show(text, error) }
    }

    Item { id: gfx; readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software }

    Component { id: homePage; HomePage {} }
    Component { id: gamesPage; HomePage { games: true } }
    Component {
        id: appsPage
        BrowsePage {
            title: "Aplicaciones"
            sections: [{ title: "Populares", fetch: function (p, n, cb) { F.collection("popular", p, n, cb) } }]
                .concat(F.appCategories.map(function (c) {
                    return { title: c.title, fetch: function (p, n, cb) { F.category(c.id, p, n, cb) } }
                }))
        }
    }
    Component { id: libraryPage; LibraryPage { mode: "library" } }
    Component { id: downloadsPage; LibraryPage { mode: "downloads" } }
    Component {
        id: newsPage
        BrowsePage {
            title: "Novedades"
            sections: [
                { title: "Recién llegadas", fetch: function (p, n, cb) { F.collection("recently-added", p, n, cb) } },
                { title: "Actualizadas", fetch: function (p, n, cb) { F.collection("recently-updated", p, n, cb) } },
                { title: "Tendencias", fetch: function (p, n, cb) { F.collection("trending", p, n, cb) } },
                { title: "Verificadas", fetch: function (p, n, cb) { F.collection("verified", p, n, cb) } }
            ]
        }
    }
    Component { id: appPage; AppPage {} }
    Component { id: browsePage; BrowsePage {} }
    Component { id: searchPage; SearchPage {} }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Barra superior: atrás, título y buscador ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onDoubleTapped: win.maximized ? win.showNormal() : win.showMaximized() }

            // Foto o iniciales del usuario (como "AC" en la Store)
            Rectangle {
                id: avatar
                anchors.right: captions.left
                anchors.rightMargin: 46
                anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; radius: 15
                color: store.avatar ? "transparent" : (win.dark ? "#3A3A3A" : "#D6D6D6")
                Image {
                    anchors.fill: parent
                    visible: store.avatar !== ""
                    source: store.avatar ? "image://avatar/" + encodeURIComponent(store.avatar) : ""
                    sourceSize: Qt.size(60, 60)
                }
                Label {
                    anchors.centerIn: parent
                    visible: store.avatar === ""
                    text: store.initials
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: win.text
                }
                ToolTip.visible: avHover.hovered
                ToolTip.text: store.userName
                HoverHandler { id: avHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.go("library") }
            }
            CaptionButtons { id: captions; anchors.right: parent.right; anchors.top: parent.top }

            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                ToolButton {
                    flat: true
                    enabled: stack.depth > 1
                    opacity: enabled ? 1 : 0.4
                    onClicked: stack.pop()
                    contentItem: Item {
                        implicitWidth: 16; implicitHeight: 16
                        FluentIcon { anchors.centerIn: parent; name: "back"; size: 16 }
                    }
                }
                Image {
                    source: Qt.resolvedUrl("../icons/win11-store.svg")
                    sourceSize: Qt.size(40, 40)
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                Label { text: "Tienda"; font.pixelSize: 12; color: win.text }
            }

            TextField {
                id: searchField
                anchors.centerIn: parent
                width: Math.min(600, parent.width - 480)
                height: 34
                placeholderText: "Buscar aplicaciones, juegos y mucho más"
                rightPadding: 38
                onAccepted: win.search(text)
                onTextEdited: {
                    if (text.trim().length >= 2) suggestTimer.restart()
                    else suggestions.close()
                }
                Keys.onDownPressed: if (suggestions.opened) { suggestList.forceActiveFocus(); suggestList.currentIndex = 0 }
                Keys.onEscapePressed: suggestions.close()
                FluentIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 16
                    color: win.subtext
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: win.search(searchField.text) }
                }

                Timer {
                    id: suggestTimer
                    interval: 250
                    onTriggered: {
                        var q = searchField.text.trim()
                        F.search(q, function (apps) {
                            if (searchField.text.trim() !== q || !searchField.activeFocus) return
                            suggestList.model = apps.slice(0, 6)
                            if (apps.length) suggestions.open(); else suggestions.close()
                        })
                    }
                }

                Popup {
                    id: suggestions
                    y: searchField.height + 4
                    width: searchField.width
                    padding: 4
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                    background: Rectangle {
                        radius: 8
                        color: win.dark ? "#2C2C2C" : "#FFFFFF"
                        border.color: win.cardBorder
                    }
                    contentItem: ListView {
                        id: suggestList
                        implicitHeight: contentHeight
                        interactive: false
                        keyNavigationEnabled: true
                        Keys.onReturnPressed: { suggestions.close(); win.openApp(model[currentIndex]) }
                        Keys.onUpPressed: function (e) { if (currentIndex === 0) searchField.forceActiveFocus(); else e.accepted = false }
                        delegate: ItemDelegate {
                            width: suggestList.width
                            height: 48
                            highlighted: ListView.isCurrentItem && suggestList.activeFocus
                            onClicked: { suggestions.close(); win.openApp(modelData) }
                            contentItem: RowLayout {
                                spacing: 12
                                Image {
                                    source: modelData.icon || ""
                                    sourceSize: Qt.size(64, 64)
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    asynchronous: true
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Layout.fillWidth: true
                                    Label { text: modelData.name; color: win.text; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Label { text: F.categoryName(modelData.main_categories); color: win.subtext; font.pixelSize: 11 }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---------- Barra lateral ----------
            ColumnLayout {
                Layout.preferredWidth: 76
                Layout.fillHeight: true
                spacing: 2
                RailButton { Layout.alignment: Qt.AlignHCenter; text: "Inicio"; iconName: "home"; selected: win.section === "home"; onClicked: win.go("home") }
                RailButton { Layout.alignment: Qt.AlignHCenter; text: "Aplicaciones"; iconName: "apps"; selected: win.section === "apps"; onClicked: win.go("apps") }
                RailButton { Layout.alignment: Qt.AlignHCenter; text: "Juegos"; iconName: "games"; selected: win.section === "games"; onClicked: win.go("games") }
                Item { Layout.fillHeight: true }
                RailButton { Layout.alignment: Qt.AlignHCenter; text: "Novedades"; iconName: "news"; selected: win.section === "news"; onClicked: win.go("news") }
                RailButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Descargas"
                    iconName: "downloads"
                    selected: win.section === "downloads"
                    badge: store.updates.length + Object.keys(store.jobs).length
                    onClicked: win.go("downloads")
                }
                RailButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    text: "Biblioteca"
                    iconName: "library"
                    selected: win.section === "library"
                    onClicked: win.go("library")
                }
            }

            // ---------- Contenido (capa con esquina redondeada) ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: win.layer
                border.color: win.cardBorder
                radius: 8
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 16; height: parent.height; color: win.layer }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.right: parent.right; height: 16; color: win.layer; anchors.leftMargin: 1 }

                StackView {
                    id: stack
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.leftMargin: 1
                    clip: true
                    initialItem: homePage
                    pushEnter: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                            NumberAnimation { property: "y"; from: 40; to: 0; duration: 250; easing.type: Easing.OutCubic }
                        }
                    }
                    pushExit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
                    popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
                    popExit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !win.maximized
        color: "transparent"
        border.color: win.dark ? "#3A3A3A" : "#CFCFCF"
        z: 999
    }
    ResizeEdges {}

    // ---------- Aviso flotante ----------
    Rectangle {
        id: toast
        property bool error: false
        function show(t, e) { toastText.text = t; error = e; opacity = 1; toastTimer.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(parent.width - 120, toastRow.implicitWidth + 32)
        height: toastRow.implicitHeight + 24
        radius: 8
        color: win.dark ? "#2C2C2C" : "#FFFFFF"
        border.color: error ? "#C42B1C" : win.cardBorder
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 10
            Image {
                source: "image://icon/" + (toast.error ? "dialog-error" : "dialog-ok")
                sourceSize: Qt.size(32, 32)
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }
            Label { id: toastText; Layout.fillWidth: true; color: win.text; wrapMode: Text.Wrap }
        }
        MouseArea { anchors.fill: parent; onClicked: toast.opacity = 0 }
        Timer { id: toastTimer; interval: toast.error ? 9000 : 4000; onTriggered: toast.opacity = 0 }
    }
}
