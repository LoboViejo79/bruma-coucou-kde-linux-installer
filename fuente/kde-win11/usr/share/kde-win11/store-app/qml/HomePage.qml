import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Inicio de la Microsoft Store (y Juegos con games: true), como la de Windows 11:
// carrusel grande a la izquierda, tres mosaicos a la derecha y paneles de tendencias en dos columnas.
// En Juegos, más compacto: la cabecera más baja y cada género en una fila que se recorre de costado
// (GameRow), así se ven muchos juegos y la página se baja con la rueda.
ScrollView {
    id: page
    property bool games: false
    property var hero: []
    property int heroIndex: 0
    property string error: ""
    property var collage: []          // iconos de juegos para el mosaico grande
    property var featured: null       // app del mosaico pequeño
    property var bestGames: []        // iconos del otro mosaico pequeño
    readonly property var cur: hero[heroIndex]

    contentWidth: availableWidth
    clip: true

    // Paneles por pares: [izquierda, derecha]
    readonly property var panels: games ? [
        [{ title: "Juegos populares", fetch: function (p, n, cb) { F.category("Game", p, n, cb) } },
         { title: "Acción", fetch: function (p, n, cb) { F.subcategory("Game", "ActionGame", p, n, cb) } }],
        [{ title: "Estrategia", fetch: function (p, n, cb) { F.subcategory("Game", "StrategyGame", p, n, cb) } },
         { title: "Aventura", fetch: function (p, n, cb) { F.subcategory("Game", "AdventureGame", p, n, cb) } }],
        [{ title: "Puzles", fetch: function (p, n, cb) { F.subcategory("Game", "LogicGame", p, n, cb) } },
         { title: "Emuladores", fetch: function (p, n, cb) { F.subcategory("Game", "Emulator", p, n, cb) } }]
    ] : [
        [{ title: "Tendencias de juegos", fetch: function (p, n, cb) { F.category("Game", p, n, cb) } },
         { title: "Tendencias en aplicaciones", fetch: function (p, n, cb) { F.collection("trending", p, n, cb) } }],
        [{ title: "Aplicaciones más populares", fetch: function (p, n, cb) { F.collection("popular", p, n, cb) } },
         { title: "Productividad esencial", fetch: function (p, n, cb) { F.category("Office", p, n, cb) } }],
        [{ title: "Música y vídeo", fetch: function (p, n, cb) { F.category("AudioVideo", p, n, cb) } },
         { title: "Novedades", fetch: function (p, n, cb) { F.collection("recently-added", p, n, cb) } }]
    ]

    readonly property var tiles: games
        ? F.gameCategories.slice(0, 8).map(function (c, i) { return { title: c.title, colors: F.tileColors[i % F.tileColors.length], game: c.id } })
        : F.appCategories.map(function (c, i) { return { title: c.title, icon: c.icon, colors: F.tileColors[i % F.tileColors.length], index: i + 1 } })

    // Destacados del carrusel: apps y juegos con imágenes vistosas (como el arte de la Store)
    readonly property var featuredIds: games
        ? ["net.supertuxkart.SuperTuxKart", "com.play0ad.zeroad", "org.luanti.luanti", "net.veloren.airshipper",
           "org.libretro.RetroArch", "com.valvesoftware.Steam"]
        : ["net.supertuxkart.SuperTuxKart", "org.blender.Blender", "com.play0ad.zeroad", "org.kde.krita",
           "org.luanti.luanti", "org.kde.kdenlive", "com.obsproject.Studio"]

    function loadHero() {
        var out = []
        var pending = featuredIds.length
        featuredIds.forEach(function (id, i) {
            F.details(id, function (d, err) {
                if (!page) return
                if (d) {
                    var shots = d.screenshots || []
                    var shot = shots.filter(function (s) { return s["default"] })[0] || shots[0]
                    if (shot)
                        out[i] = { app_id: id, name: d.name, summary: d.summary, icon: d.icon,
                                   main_categories: d.categories || [], shot: F.screenshot(shot, 1600) }
                } else if (err) {
                    page.error = err
                }
                if (--pending === 0) {
                    page.hero = out.filter(Boolean)
                    if (page.hero.length) page.error = ""
                }
            })
        })
        // App del mosaico pequeño: una popular que no esté en el carrusel
        var pick = function (apps) {
            if (!page) return
            page.featured = apps.filter(function (a) { return featuredIds.indexOf(a.app_id) < 0 })[0] || null
        }
        if (games) F.category("Game", 1, 12, pick)
        else F.collection("popular", 1, 12, pick)
        F.category("Game", 1, 40, function (apps) {
            if (!page) return
            page.collage = apps.map(function (a) { return a.icon }).filter(Boolean)
        })
        var best = function (apps) { if (page) page.bestGames = apps.slice(0, 4) }
        if (games) F.subcategory("Game", "Emulator", 1, 8, best)
        else F.collection("trending", 1, 30, function (a) {
            if (!page) return
            page.bestGames = a.filter(function (x) { return F.categoryName(x.main_categories) === "Juegos" }).slice(0, 4)
            if (page.bestGames.length < 4) F.category("Game", 1, 8, best)
        })
    }
    Component.onCompleted: loadHero()

    // Mosaico de la cabecera: fondo, contenido libre y texto
    component Tile: Item {
        id: tile
        property color base: "#222"
        property string title
        property bool big: false
        default property alias content: inner.data
        signal clicked()
        Rounded {
        anchors.fill: parent
        radius: 8
        Rectangle { anchors.fill: parent; color: tile.base }
        Item { id: inner; anchors.fill: parent; clip: true }
        Rectangle {
            visible: !tile.big
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
            }
        }
        Rectangle {
            visible: tile.big
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.10, 0.22, 0.40, 0.92) }
                GradientStop { position: 0.6; color: Qt.rgba(0.10, 0.22, 0.40, 0.2) }
            }
        }
        Label {
            anchors.left: parent.left
            anchors.leftMargin: tile.big ? 32 : 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: tile.big ? parent.height * 0.42 : 16
            width: parent.width * (tile.big ? 0.55 : 1) - 32
            text: tile.title
            color: "white"
            font.pixelSize: tile.big ? (page.games ? 21 : 26) : 16
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: tile.big ? 3 : 2
            elide: Text.ElideRight
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, tileArea.containsMouse ? 0.06 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        }
        MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
    }

    ColumnLayout {
        width: page.availableWidth
        spacing: page.games ? 20 : 28

        // ---------- Cabecera: carrusel + mosaicos ----------
        RowLayout {
            id: top
            Layout.fillWidth: true
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            Layout.topMargin: 12
            spacing: 14
            readonly property real h: page.games ? Math.min(300, Math.max(220, width * 0.2))
                                                 : Math.min(600, Math.max(360, width * 0.34))

            // Carrusel
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 60
                spacing: 10

                Item {
                    id: heroBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: top.h
                    HoverHandler { id: heroHover }

                    // Luz de la imagen que se derrama sobre la página
                    Glow {
                        anchors.fill: parent
                        anchors.margins: -130
                        z: -1
                        opacity: 0.95
                        sources: page.hero.map(function (h) { return h.shot })
                        current: page.heroIndex
                    }

                    Rounded {
                        anchors.fill: parent
                        radius: 8
                        Rectangle { anchors.fill: parent; color: "#111" }
                        Repeater {
                            model: page.hero
                            Image {
                                anchors.fill: parent
                                source: modelData.shot
                                sourceSize.width: 1600
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: index === page.heroIndex && status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 600 } }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.82) }
                                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.openApp(page.cur)
                        }

                        ColumnLayout {
                            visible: !!page.cur
                            anchors.left: parent.left
                            anchors.leftMargin: 36
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(460, parent.width - 72)
                            spacing: 8
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    implicitWidth: freeText.implicitWidth + 16; implicitHeight: 22; radius: 3
                                    color: "#3B8526"
                                    Label { id: freeText; anchors.centerIn: parent; text: page.cur && store.installed[page.cur.app_id.toLowerCase()] ? "Propia" : "Gratis"; color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                }
                                Rectangle {
                                    implicitWidth: catText.implicitWidth + 16; implicitHeight: 22; radius: 3
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    Label { id: catText; anchors.centerIn: parent; text: page.cur ? F.categoryName(page.cur.main_categories) : ""; color: "white"; font.pixelSize: 12 }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: page.cur ? page.cur.name : ""
                                color: "white"
                                font.pixelSize: page.games ? 26 : 34
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: page.cur ? page.cur.summary : ""
                                color: Qt.rgba(1, 1, 1, 0.8)
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Button {
                                Layout.topMargin: page.games ? 6 : 14
                                text: "Ver detalles"
                                font.weight: Font.DemiBold
                                onClicked: win.openApp(page.cur)
                            }
                        }

                        Timer {
                            id: rotate
                            interval: 7000
                            repeat: true
                            running: page.hero.length > 1 && !heroHover.hovered && page.visible
                            onTriggered: page.heroIndex = (page.heroIndex + 1) % page.hero.length
                        }
                        BusyIndicator { anchors.centerIn: parent; running: page.hero.length === 0 && page.error === "" }
                        Column {
                            anchors.centerIn: parent
                            visible: page.error !== ""
                            spacing: 10
                            Label { text: page.error; color: "white" }
                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Reintentar"
                                onClicked: { F.cache = ({}); page.loadHero() }
                            }
                        }
                    }

                    // Flechas al pasar el ratón
                    RoundButton {
                        width: 28; height: 40; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        opacity: heroHover.hovered && page.hero.length > 1 ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        contentItem: Item { FluentIcon { anchors.centerIn: parent; name: "prev"; size: 12; stroke: 2.4; color: win.text } }
                        onClicked: { page.heroIndex = (page.heroIndex + page.hero.length - 1) % page.hero.length; rotate.restart() }
                    }
                    RoundButton {
                        width: 28; height: 40; radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 6
                        opacity: heroHover.hovered && page.hero.length > 1 ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        contentItem: Item { FluentIcon { anchors.centerIn: parent; name: "next"; size: 12; stroke: 2.4; color: win.text } }
                        onClicked: { page.heroIndex = (page.heroIndex + 1) % page.hero.length; rotate.restart() }
                    }
                }

                // Puntos del carrusel
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: page.hero.length
                        Rectangle {
                            width: index === page.heroIndex ? 16 : 6; height: 6; radius: 3
                            color: win.text
                            opacity: index === page.heroIndex ? 0.9 : 0.4
                            Behavior on width { NumberAnimation { duration: 180 } }
                            MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: { page.heroIndex = index; rotate.restart() } }
                        }
                    }
                }
            }

            // Mosaicos de la derecha
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 40
                Layout.alignment: Qt.AlignTop
                spacing: 12

                // Mosaico grande: collage de juegos inclinado
                Tile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: top.h * 0.64
                    base: "#2A4D7A"
                    big: true
                    title: page.games ? "Más de 700 juegos para elegir" : "Juega cientos de juegos geniales"
                    onClicked: page.games ? win.openList("Todos los juegos", function (p, n, cb) { F.category("Game", p, n, cb) }) : win.go("games")
                    Grid {
                        x: parent.width * 0.22
                        y: -parent.height * 0.35
                        rotation: -24
                        columns: 7
                        spacing: 10
                        opacity: 0.9
                        Repeater {
                            model: page.collage
                            Rectangle {
                                width: 58; height: 58; radius: 8
                                color: Qt.rgba(1, 1, 1, 0.08)
                                Image { anchors.centerIn: parent; width: 46; height: 46; source: modelData; sourceSize: Qt.size(64, 64); asynchronous: true }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: top.h * 0.36 - 12
                    spacing: 12

                    // App destacada con los colores de su icono
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        base: "#0E2A17"
                        title: page.featured ? page.featured.name : ""
                        onClicked: win.openApp(page.featured)
                        Image {
                            anchors.fill: parent
                            source: page.featured ? page.featured.icon : ""
                            sourceSize: Qt.size(4, 4)
                            fillMode: Image.Stretch
                            smooth: true
                            opacity: 0.55
                        }
                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -14
                            width: 72; height: 72
                            source: page.featured ? page.featured.icon : ""
                            sourceSize: Qt.size(128, 128)
                            asynchronous: true
                        }
                    }

                    // Los mejores juegos
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        base: "#13261A"
                        title: page.games ? "Emuladores y clásicos" : "Consigue los mejores juegos"
                        onClicked: page.games ? win.openList("Emuladores", function (p, n, cb) { F.subcategory("Game", "Emulator", p, n, cb) })
                                              : win.openList("Juegos populares", function (p, n, cb) { F.category("Game", p, n, cb) })
                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -14
                            width: bestRow.implicitWidth + 12; height: bestRow.implicitHeight + 12
                            radius: 4
                            color: "transparent"
                            border.color: "#3FB950"
                            Row {
                                id: bestRow
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: page.bestGames
                                    Rectangle {
                                        width: 40; height: 54; radius: 2
                                        color: "#0B0B0B"
                                        Image { anchors.centerIn: parent; width: 34; height: 34; source: modelData.icon; sourceSize: Qt.size(64, 64); asynchronous: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------- Juegos: una fila por género ----------
        Repeater {
            model: page.games ? page.panels.reduce(function (a, par) { return a.concat(par) }, []) : []
            GameRow {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                title: modelData.title
                fetch: modelData.fetch
                onSeeAll: win.openList(modelData.title, modelData.fetch)
            }
        }

        // ---------- Paneles de tendencias (dos columnas) ----------
        Repeater {
            model: page.games ? [] : page.panels
            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                columns: page.availableWidth > 1100 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16
                Repeater {
                    model: modelData
                    TrendPanel {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        title: modelData.title
                        fetch: modelData.fetch
                        onSeeAll: win.openList(modelData.title, modelData.fetch)
                    }
                }
            }
        }

        // ---------- Categorías ----------
        ColumnLayout {
            id: catBox
            Layout.fillWidth: true
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            spacing: 12
            Label {
                text: page.games ? "Explorar por género" : "Explorar categorías"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: win.text
            }
            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor((catBox.width + 12) / 212))
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: page.tiles
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: page.games ? 60 : 84
                        Layout.preferredWidth: 200
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: modelData.colors[0] }
                            GradientStop { position: 1; color: modelData.colors[1] }
                        }
                        scale: catArea.pressed ? 0.97 : catArea.containsMouse ? 1.02 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Image {
                            visible: !!modelData.icon
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; height: 40
                            source: modelData.icon ? "image://icon/" + modelData.icon : ""
                            sourceSize: Qt.size(64, 64)
                        }
                        FluentIcon {
                            visible: !modelData.icon
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: "games"
                            size: 36
                            color: Qt.rgba(1, 1, 1, 0.85)
                        }
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            text: modelData.title
                            color: "white"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        MouseArea {
                            id: catArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var t = modelData
                                if (t.game) win.openList(t.title, function (p, n, cb) { F.subcategory("Game", t.game, p, n, cb) })
                                else win.openCategory(t.index)
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 16 }
    }
}
