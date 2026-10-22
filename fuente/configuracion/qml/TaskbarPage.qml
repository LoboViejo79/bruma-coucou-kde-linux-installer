import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
    id: root
    contentWidth: availableWidth
    property string current: backend.taskbarStyle()
    property string pending: ""
    property string position: backend.coucouBarPosition()
    property string screenPick: screenOf(backend.coucouSetting("screen", "primary"))
    function screenOf(v) { return v.indexOf("at:") === 0 ? (v.split("|")[1] || "primary") : v }
    Timer {
        interval: 700; repeat: true; running: root.visible
        onTriggered: {
            root.current = backend.taskbarStyle()
            root.position = backend.coucouBarPosition()
            root.screenPick = root.screenOf(backend.coucouSetting("screen", "primary"))
            root.cover = backend.coucouSetting("barCover", "shrink")
            root.previews = backend.coucouSetting("barPreviews", "on")
            root.autoclose = backend.coucouSetting("autoCloseInterval", "15")
            root.hover = backend.coucouSetting("openOnHover", "off")
            root.sounds = backend.coucouSetting("soundEnabled", "on")
            if (root.pending === root.current) root.pending = ""
        }
    }
    Timer { id: giveUp; interval: 20000; onTriggered: root.pending = "" }
    function choose(id) {
        if (id === current && pending === "") return
        pending = id
        giveUp.restart()
        backend.launch("/usr/lib/coucou/estilo", [id])
    }
    function placeOn(which) {
        screenPick = which
        var arg = which
        for (var i = 0; i < Qt.application.screens.length; i++) {
            var sc = Qt.application.screens[i]
            if (sc.name === which) arg = which + "@" + sc.virtualX + "," + sc.virtualY
        }
        backend.launch("coucou-launch", ["--bar-screen", arg])
    }
    property string cover: backend.coucouSetting("barCover", "shrink")
    property string shape: backend.coucouSetting("barShape", "island")
    property string bubbles: backend.coucouBubbles()
    property string previews: backend.coucouSetting("barPreviews", "on")
    property string autoclose: backend.coucouSetting("autoCloseInterval", "15")
    property string hover: backend.coucouSetting("openOnHover", "off")
    property string sounds: backend.coucouSetting("soundEnabled", "on")
    function coucouOpt(prop, flag, value) {
        root[prop] = value
        backend.launch("coucou-launch", [flag, value])
    }
    function place(where) {
        position = where
        backend.launch("coucou-launch", ["--bar-position", where])
    }
    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4
        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 12
            parts: [{ title: "Personalización" }, { title: "Barra de tareas" }]
        }
        SettingsCard {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            clickable: false
            glyph: "taskbar"
            title: root.pending === "coucou" ? "Poniendo la barra de Coucou…"
                 : root.pending === "cachyos" ? "Poniendo la barra de CachyOS…"
                 : "Barra que se usa"
            description: root.pending !== "" ? "Tarda unos segundos: el escritorio cambia de aspecto"
                       : root.current === "cachyos" ? "La original de CachyOS: el panel de Plasma con su aspecto de fábrica (Breeze)"
                       : root.current === "coucou" ? "La de Coucou: la barra de vidrio con Mochi y todo su diseño"
                       : "El escritorio tiene otro panel (de una instalación vieja): elegí una"
            trailing: [
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [{ id: "coucou", name: "Coucou" }, { id: "cachyos", name: "CachyOS original" }]
                        Button {
                            text: modelData.name
                            enabled: root.pending === ""
                            highlighted: (root.pending || root.current) === modelData.id
                            onClicked: root.choose(modelData.id)
                        }
                    }
                }
            ]
        }
        Label {
            Layout.topMargin: 14
            Layout.bottomMargin: 2
            visible: root.current === "coucou" || root.pending === "coucou"
            text: "Aspecto de la barra"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: win.text
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" || root.pending === "coucou"
            clickable: false
            glyph: "display"
            title: "Posición de la barra"
            description: "Arriba o abajo de la pantalla"
            trailing: [
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [{ id: "top", name: "Arriba" }, { id: "bottom", name: "Abajo" }]
                        Button {
                            text: modelData.name
                            highlighted: root.position === modelData.id
                            onClicked: root.place(modelData.id)
                        }
                    }
                }
            ]
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: (root.current === "coucou" || root.pending === "coucou") && Qt.application.screens.length > 1
            clickable: false
            glyph: "display"
            title: "Pantalla de la barra"
            description: root.screenPick === "cursor"
                ? "En todas: la barra se pasa a la pantalla que estás usando"
                : "En una sola pantalla"
            trailing: [
                ComboBox {
                    id: screenBox
                    implicitWidth: 240
                    textRole: "name"
                    valueRole: "id"
                    model: {
                        var list = [{ id: "cursor", name: "En todas (la que estés usando)" },
                                    { id: "primary", name: "Solo la principal" }]
                        for (var i = 0; i < Qt.application.screens.length; i++) {
                            var sc = Qt.application.screens[i]
                            list.push({ id: sc.name, name: "Solo " + (sc.model || sc.name) + " (" + sc.width + "×" + sc.height + ")" })
                        }
                        return list
                    }
                    currentIndex: Math.max(0, indexOfValue(root.screenPick))
                    onActivated: root.placeOn(currentValue)
                }
            ]
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" || root.pending === "coucou"
            clickable: false
            glyph: "taskbar"
            title: "Forma de la barra"
            description: root.shape === "wide" ? "Todo el ancho, flotando, con las puntas redondeadas"
                       : root.shape === "edge" ? "Todo el ancho, pegada al borde y recta, como en Windows"
                       : "Una isla en el centro de la pantalla, flotando"
            trailing: [
                ComboBox {
                    id: shapeBox
                    implicitWidth: 230
                    textRole: "name"
                    valueRole: "id"
                    model: [{ id: "island", name: "Isla (centrada)" },
                            { id: "wide", name: "Ancha y flotante" },
                            { id: "edge", name: "Pegada al borde" }]
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.shape))
                    onActivated: root.coucouOpt("shape", "--bar-shape", currentValue)
                }
            ]
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" || root.pending === "coucou"
            clickable: false
            glyph: "multitask"
            title: "Burbujas de la barra"
            description: "Clic derecho en un grupo: burbuja propia y lado (izq., centro, der.)"
            trailing: [
                ComboBox {
                    implicitWidth: 230
                    textRole: "name"
                    valueRole: "id"
                    model: [{ id: "one", name: "Todo en una burbuja" },
                            { id: "clock", name: "La fecha aparte" },
                            { id: "all", name: "Cada grupo en su burbuja" },
                            { id: "stretch", name: "Separadas, apps estiradas" }]
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.bubbles))
                    onActivated: root.coucouOpt("bubbles", "--bar-bubbles", currentValue)
                }
            ]
        }
        Label {
            Layout.topMargin: 14
            Layout.bottomMargin: 2
            visible: root.current === "coucou" && root.pending === ""
            text: "Comportamiento"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: win.text
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            clickable: false
            glyph: "window"
            title: "Con una ventana maximizada o a media pantalla"
            description: root.cover === "hide" ? "La barra se oculta a los 5 segundos; vuelve al llevar el mouse al borde de la pantalla"
                       : root.cover === "off" ? "La barra queda siempre igual, encima de la ventana"
                       : "La barra se achica (Mochi y la hora) o se corre a un costado"
            trailing: [
                ComboBox {
                    id: coverBox
                    implicitWidth: 230
                    textRole: "name"
                    valueRole: "id"
                    model: [{ id: "shrink", name: "Achicar la barra" },
                            { id: "hide", name: "Ocultarla a los 5 segundos" },
                            { id: "off", name: "No hacer nada" }]
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cover))
                    Connections {
                        target: root
                        function onCoverChanged() { coverBox.currentIndex = Math.max(0, coverBox.indexOfValue(root.cover)) }
                    }
                    onActivated: root.coucouOpt("cover", "--bar-cover", currentValue)
                }
            ]
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            clickable: false
            glyph: "multitask"
            title: "Vista previa de las ventanas"
            description: "Al dejar el mouse sobre una app abierta se ven sus ventanas"
            trailing: Switch {
                checked: root.previews === "on"
                onToggled: root.coucouOpt("previews", "--bar-previews", checked ? "on" : "off")
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            clickable: false
            glyph: "clock"
            title: "Cerrar solas las ventanas de la barra"
            description: "Calendario, búsqueda, Wi‑Fi…: se cierran si no las usas"
            trailing: [
                ComboBox {
                    id: closeBox
                    implicitWidth: 170
                    textRole: "name"
                    valueRole: "id"
                    model: {
                        var list = [{ id: "15", name: "A los 15 segundos" },
                                    { id: "30", name: "A los 30 segundos" },
                                    { id: "60", name: "Al minuto" },
                                    { id: "86400", name: "Nunca" }]
                        var known = list.some(function (x) { return x.id === root.autoclose })
                        if (!known && +root.autoclose > 0) list.splice(0, 0, { id: root.autoclose, name: "A los " + root.autoclose + " segundos" })
                        return list
                    }
                    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.autoclose))
                    Connections {
                        target: root
                        function onAutocloseChanged() { closeBox.currentIndex = Math.max(0, closeBox.indexOfValue(root.autoclose)) }
                    }
                    onActivated: root.coucouOpt("autoclose", "--bar-autoclose", currentValue)
                }
            ]
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            clickable: false
            glyph: "cursor"
            title: "Abrir al pasar el mouse"
            description: "Las ventanas de la barra se abren sin hacer clic"
            trailing: Switch {
                checked: root.hover === "on"
                onToggled: root.coucouOpt("hover", "--bar-hover", checked ? "on" : "off")
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            clickable: false
            glyph: "sound"
            title: "Sonidos de Coucou"
            description: "Los sonidos de Mochi y de la barra"
            trailing: Switch {
                checked: root.sounds === "on"
                onToggled: root.coucouOpt("sounds", "--bar-sounds", checked ? "on" : "off")
            }
        }
        SettingsCard {
            Layout.fillWidth: true
            visible: root.current === "coucou" && root.pending === ""
            glyph: "bell"
            external: true
            title: "Notificaciones"
            description: "Cómo avisan las apps: con o sin el mensaje, compactas, u ocultas por app"
            onClicked: backend.launch("coucou-launch", ["--notif-edit"])
        }
    }
}
