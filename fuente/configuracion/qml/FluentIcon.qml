import QtQuick

// Iconos de línea estilo Segoe Fluent Icons (los de las tarjetas de Configuración de Windows 11),
// dibujados en vector sobre una rejilla de 24×24. Funcionan también sin aceleración 3D.
Item {
    id: root
    property string name
    property color color: win.text
    property real size: 20
    property real stroke: 1.5
    width: size
    height: size

    readonly property var glyphs: ({
        display: "M3.5 5.5h17v10h-17Z M9 19.5h6 M12 15.5v4",
        laptop: "M5 6h14v9.5H5Z M3 18.5h18",
        sound: "M4 9.5h3.5L12 5.5v13l-4.5-4H4Z M15.5 9a4 4 0 0 1 0 6 M18 6.5a7.5 7.5 0 0 1 0 11",
        bell: "M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15Z M10 20.5a2 2 0 0 0 4 0",
        focus: "M12 4a8 8 0 1 1 0 16 8 8 0 0 1 0-16Z M12 8.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7Z",
        moon: "M19 14.5A7.5 7.5 0 0 1 9.5 5a7.5 7.5 0 1 0 9.5 9.5Z",
        power: "M12 3.5v8 M7.2 6.3a7.5 7.5 0 1 0 9.6 0",
        storage: "M3.5 9.5h17v5h-17Z M17 12h.01",
        share: "M14 4.5h5.5V10 M19.5 4.5 11 13 M17 13.5v6H4.5V7h6",
        open: "M14 4.5h5.5V10 M19.5 4.5 11 13 M17 13.5v6H4.5V7h6",
        multitask: "M8.5 4h11.5v11.5H8.5Z M4 8.5v11.5h11.5",
        window: "M4 5h16v14H4Z M4 9h16",
        clipboard: "M8.5 5H6.5A1.5 1.5 0 0 0 5 6.5v13A1.5 1.5 0 0 0 6.5 21h11a1.5 1.5 0 0 0 1.5-1.5v-13A1.5 1.5 0 0 0 17.5 5h-2 M9 3.5h6v3H9Z",
        advanced: "M6 4v16 M12 4v16 M18 4v16 M4 8.5h4 M10 15.5h4 M16 10.5h4",
        info: "M12 3.5a8.5 8.5 0 1 1 0 17 8.5 8.5 0 0 1 0-17Z M12 11v5.5 M12 7.8h.01",
        activation: "M12 3.5a8.5 8.5 0 1 1 0 17 8.5 8.5 0 0 1 0-17Z M8.5 12.2l2.4 2.4 4.6-4.8",
        wrench: "M14.5 4.5a4.5 4.5 0 0 0-4.2 6.1L4.5 16.4a2.1 2.1 0 0 0 3 3l5.8-5.8a4.5 4.5 0 0 0 6.1-4.2l-2.7 2.7-3-1-1-3Z",
        bluetooth: "M7 7.5l10 9-5 4.5v-18l5 4.5-10 9",
        mouse: "M12 3.5a5.5 5.5 0 0 1 5.5 5.5v6a5.5 5.5 0 0 1-11 0V9A5.5 5.5 0 0 1 12 3.5Z M12 3.5v6",
        keyboard: "M3.5 6.5h17v11h-17Z M7 10h.01 M10 10h.01 M13 10h.01 M16 10h.01 M8 14h8",
        printer: "M7 9V4h10v5 M17 16h3.5v-5.5A1.5 1.5 0 0 0 19 9H5a1.5 1.5 0 0 0-1.5 1.5V16H7 M7 13h10v7H7Z",
        touchpad: "M4 5h16v14H4Z M4 15h16 M12 15v4",
        touch: "M10 11V5.5a1.5 1.5 0 0 1 3 0V12 M13 10a1.5 1.5 0 0 1 3 0v2 M16 11a1.5 1.5 0 0 1 3 0v4a6 6 0 0 1-6 6h-1a6 6 0 0 1-4.5-2l-3-3.5a1.5 1.5 0 0 1 2.3-2L10 14",
        pen: "M15 4.5l4.5 4.5L9 19.5H4.5V15Z M13 6.5l4.5 4.5",
        gamepad: "M8 6.5h8a5 5 0 0 1 4.9 4l1 5.2a2.7 2.7 0 0 1-4.7 2.3L15.5 16h-7l-1.7 2a2.7 2.7 0 0 1-4.7-2.3l1-5.2a5 5 0 0 1 4.9-4Z M8 9.5v4 M6 11.5h4 M15.5 10.5h.01 M17.5 12.5h.01",
        play: "M12 3.5a8.5 8.5 0 1 1 0 17 8.5 8.5 0 0 1 0-17Z M10 8.5l5 3.5-5 3.5Z",
        usb: "M9 3.5h6v5H9Z M7.5 8.5h9V14a4.5 4.5 0 0 1-9 0Z M12 18.5v2.5",
        wifi: "M2.5 9a14 14 0 0 1 19 0 M5.5 12.5a9.5 9.5 0 0 1 13 0 M8.5 16a5 5 0 0 1 7 0 M12 19.5h.01",
        globe: "M12 3.5a8.5 8.5 0 1 1 0 17 8.5 8.5 0 0 1 0-17Z M3.5 12h17 M12 3.5c2.5 2.5 3.5 5.5 3.5 8.5s-1 6-3.5 8.5c-2.5-2.5-3.5-5.5-3.5-8.5s1-6 3.5-8.5Z",
        shield: "M12 3.5l7 2.5v6c0 4.5-3 7.5-7 8.5-4-1-7-4-7-8.5V6Z",
        cellular: "M5 19v-3 M9.5 19v-6 M14 19v-9 M18.5 19V6",
        hotspot: "M12 12h.01 M8.5 15.5a5 5 0 0 1 0-7 M15.5 8.5a5 5 0 0 1 0 7 M5.6 18.4a9 9 0 0 1 0-12.8 M18.4 5.6a9 9 0 0 1 0 12.8",
        ethernet: "M4.5 5h15v10h-15Z M9 15v4h6v-4 M8 8.5v3 M11 8.5v3 M13 8.5v3 M16 8.5v3",
        folder: "M3.5 6.5A1.5 1.5 0 0 1 5 5h4.5l2 2H19a1.5 1.5 0 0 1 1.5 1.5v9A1.5 1.5 0 0 1 19 19H5a1.5 1.5 0 0 1-1.5-1.5Z",
        image: "M3.5 5h17v14h-17Z M3.5 15.5l5-4.5 4 3.5 3-2.5 5 4 M15.5 9h.01",
        palette: "M12 3.5a8.5 8.5 0 0 0 0 17c1.3 0 1.8-.9 1.4-1.9-.4-1 .2-2.1 1.3-2.1H17a3.5 3.5 0 0 0 3.5-3.5C20.5 7.2 16.7 3.5 12 3.5Z M7.5 11h.01 M10 7.5h.01 M14.5 7.5h.01",
        brush: "M14 4.5l5.5 5.5-7 7-5.5-5.5Z M7 11.5l-3 3c-1 1-1 4.5-1 4.5s3.5 0 4.5-1l3-3",
        lock: "M6.5 10.5h11v9.5h-11Z M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5",
        font: "M5 19l5.5-14h1L17 19 M7.2 14h8.6",
        start: "M4.5 4.5h6.5v6.5H4.5Z M13 4.5h6.5v6.5H13Z M4.5 13h6.5v6.5H4.5Z M13 13h6.5v6.5H13Z",
        taskbar: "M3.5 5h17v14h-17Z M3.5 15.5h17",
        apps: "M4.5 4.5h6.5v6.5H4.5Z M4.5 13h6.5v6.5H4.5Z M13 6h7 M13 9.5h5 M13 14.5h7 M13 18h5",
        file: "M6 3.5h8l4 4v13H6Z M14 3.5v4h4",
        user: "M12 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8Z M4.5 20.5a7.5 7.5 0 0 1 15 0",
        mail: "M3.5 6h17v12h-17Z M3.5 7l8.5 6.5L20.5 7",
        key: "M7.5 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8Z M11.5 12h9 M17.5 12v3 M20.5 12v2.5",
        clock: "M12 3.5a8.5 8.5 0 1 1 0 17 8.5 8.5 0 0 1 0-17Z M12 7.5V12l3 2",
        language: "M4 5.5h9 M8.5 4v1.5 M6 5.5c0 4 2.5 7 6 8.5 M11 5.5c0 4-2.5 7-6.5 8.5 M12.5 20l4-9.5 4 9.5 M14 17h5",
        spell: "M5 15l3.5-9h1L13 15 M6.2 12h5.6 M13.5 17l2.5 2.5 4.5-5",
        eye: "M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z M12 9.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Z",
        sparkle: "M12 3.5l1.8 4.7 4.7 1.8-4.7 1.8L12 16.5l-1.8-4.7L5.5 10l4.7-1.8Z M18 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8Z",
        cursor: "M6 3.5v15l4-4 3 6 2.5-1.2-3-6h5.5Z",
        access: "M12 3.5a1.8 1.8 0 1 1 0 3.6 1.8 1.8 0 0 1 0-3.6Z M5 8.5l7 1.5 7-1.5 M12 10v4.5 M12 14.5l-3.5 6 M12 14.5l3.5 6",
        history: "M4.5 12a7.5 7.5 0 1 0 2.2-5.3 M4 4.5v3.5h3.5 M12 8v4l2.5 2",
        search: "M10.5 3.5a7 7 0 1 1 0 14 7 7 0 0 1 0-14Z M15.5 15.5 20.5 20.5",
        chart: "M4.5 19.5h15 M7 16v-4 M11 16V8 M15 16v-6 M19 16V5",
        cpu: "M7 7h10v10H7Z M10 10h4v4h-4Z M9.5 4v3 M14.5 4v3 M9.5 17v3 M14.5 17v3 M4 9.5h3 M4 14.5h3 M17 9.5h3 M17 14.5h3",
        memory: "M3.5 7.5h17v9h-17Z M7 10.5v3 M10.5 10.5v3 M14 10.5v3 M17.5 10.5v3 M6 16.5v2 M18 16.5v2",
        update: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M19.5 4v4h-4",
        home: "M4 10.2 12 3.6l8 6.6V19a1.5 1.5 0 0 1-1.5 1.5H15v-6H9v6H5.5A1.5 1.5 0 0 1 4 19Z",
        battery: "M3.5 8h15v8h-15Z M20.5 10.5v3 M5.5 10h6v4h-6Z",
        puzzle: "M9 4.5h3.5a1.5 1.5 0 0 1 3 0H19v4a1.5 1.5 0 0 1 0 3v4h-4a1.5 1.5 0 0 0-3 0H8v-4a1.5 1.5 0 0 0 0-3Z",
        link: "M10 14l4-4 M8.5 11 6.5 13a3.2 3.2 0 0 0 4.5 4.5l2-2 M15.5 13l2-2a3.2 3.2 0 0 0-4.5-4.5l-2 2",
        thunder: "M13 3.5 5.5 13.5h6l-1 7 7.5-10h-6Z",
        sensor: "M10 4.5a2 2 0 0 1 4 0v9.5a3.5 3.5 0 1 1-4 0Z M12 11v5",
        terminal: "M3.5 5h17v14h-17Z M7 9.5l3 2.5-3 2.5 M12 15h5",
        next: "M9 4.5 16.5 12 9 19.5",
        back: "M19.5 12h-15 M10.5 6l-6 6 6 6",
        min: "M5 12h14",
        max: "M5.5 5.5h13v13h-13Z",
        restore: "M5.5 8.5h10v10h-10Z M8.5 8.5V5.5h10v10h-3",
        close: "M5.5 5.5l13 13 M18.5 5.5l-13 13",
        check: "M5 12.5 9.5 17 19 7.5"
    })

    // Se dibuja en C++ (image://glyph) con QSvgRenderer: nítido y sin depender de la GPU
    Image {
        anchors.fill: parent
        readonly property color solid: Qt.rgba(root.color.r, root.color.g, root.color.b, 1)
        source: "image://glyph/" + encodeURIComponent(JSON.stringify({
            d: root.glyphs[root.name] || root.glyphs.info, c: solid.toString(), w: root.stroke }))
        sourceSize: Qt.size(Math.ceil(root.size * 2), Math.ceil(root.size * 2))
        opacity: root.color.a
        smooth: true
        mipmap: true
        cache: true
    }
}
