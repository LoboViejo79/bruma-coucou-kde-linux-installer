import QtQuick

// Iconos de línea estilo Fluent (Segoe Fluent Icons) dibujados en vector; "filled" = variante rellena.
// Funcionan también con el renderizador por software (máquinas virtuales sin 3D).
Item {
    id: root
    property string name
    property bool filled: false
    property color color: win.text
    property real size: 20
    property real stroke: 1.6
    // color de los detalles (p. ej. la marca de la insignia) en la variante rellena
    property color detailColor: win.layer
    width: size
    height: size

    // Rutas en una rejilla de 24×24. "s": trazos; "f": relleno de la variante filled; "d": detalles
    readonly property var glyphs: ({
        home: { s: "M4 10.2 12 3.6l8 6.6V19a1.5 1.5 0 0 1-1.5 1.5H15v-6H9v6H5.5A1.5 1.5 0 0 1 4 19Z" },
        apps: { s: "M4 4.5h5.5V10H4Z M4 14h5.5v5.5H4Z M14 14h5.5v5.5H14Z M16.75 3.2l3.55 3.55-3.55 3.55-3.55-3.55Z" },
        games: { s: "M8 6.5h8a5 5 0 0 1 4.9 4l1 5.2a2.7 2.7 0 0 1-4.7 2.3L15.5 16h-7l-1.7 2a2.7 2.7 0 0 1-4.7-2.3l1-5.2a5 5 0 0 1 4.9-4Z",
                 d: "M8 9.5v4 M6 11.5h4 M15.5 10.5h.01 M17.5 12.5h.01" },
        library: { s: "M4 4h3.5v16H4Z M9.5 4H13v16H9.5Z M15 5.3l3.3-.9 3.2 14.9-3.3.9Z" },
        search: { s: "M10.5 3.5a7 7 0 1 1 0 14 7 7 0 0 1 0-14Z M15.5 15.5 20.5 20.5" },
        back: { s: "M15 4.5 7.5 12l7.5 7.5" },
        next: { s: "M9 4.5 16.5 12 9 19.5" },
        prev: { s: "M15 4.5 7.5 12l7.5 7.5" },
        close: { s: "M5.5 5.5l13 13 M18.5 5.5l-13 13" },
        more: { s: "M5.5 12h.01 M12 12h.01 M18.5 12h.01" },
        check: { s: "M5 12.5 9.5 17 19 7.5" },
        verified: { s: "M12 2.8l2.3 1.7 2.8-.1.9 2.7 2.3 1.6-.9 2.7.9 2.7-2.3 1.6-.9 2.7-2.8-.1L12 21.2l-2.3-1.7-2.8.1-.9-2.7-2.3-1.6.9-2.7-.9-2.7 2.3-1.6.9-2.7 2.8.1Z",
                    d: "M8.5 12.2l2.3 2.3 4.7-4.7" },
        update: { s: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M19.5 4v4h-4" },
        download: { s: "M12 4v11 M7.5 10.5 12 15l4.5-4.5 M5 19.5h14" },
        cancel: { s: "M6.5 6.5l11 11 M17.5 6.5l-11 11" },
        min: { s: "M5 12h14" },
        max: { s: "M5.5 5.5h13v13h-13Z" },
        restore: { s: "M5.5 8.5h10v10h-10Z M8.5 8.5V5.5h10v10h-3" },
        news: { s: "M12 3.5l1.8 4.7 4.7 1.8-4.7 1.8L12 16.5l-1.8-4.7L5.5 10l4.7-1.8Z M18 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8Z" },
        downloads: { s: "M12 4v10 M7.5 9.5 12 14l4.5-4.5 M5 19.5h14" }
    })
    readonly property var g: glyphs[name] || glyphs.apps
    readonly property var fillable: ["home", "apps", "games", "library", "verified"]

    // Se dibuja en C++ (image://glyph) con QSvgRenderer: nítido y sin depender de la GPU
    Image {
        anchors.fill: parent
        function hex(c) { return Qt.rgba(c.r, c.g, c.b, 1).toString() }
        source: "image://glyph/" + encodeURIComponent(JSON.stringify({
            d: root.g.s, c: hex(root.color), w: root.name === "more" ? 2.6 : root.stroke,
            // Solo las formas cerradas tienen variante rellena; las de líneas se quedan en trazo
            f: root.filled && root.fillable.indexOf(root.name) >= 0 ? hex(root.color) : "",
            d2: root.g.d || "", c2: root.filled && root.fillable.indexOf(root.name) >= 0 ? hex(root.detailColor) : hex(root.color), w2: 1.7 }))
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        opacity: root.color.a
        smooth: true
        mipmap: true
    }
}
