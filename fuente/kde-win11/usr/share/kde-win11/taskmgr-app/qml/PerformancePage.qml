import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Win11TaskMgr.Core

// Rendimiento del Administrador de tareas de Windows 11: tarjetas con minigráfica a la izquierda
// y, a la derecha, el título, la gráfica de 60 segundos y las estadísticas del recurso elegido.
Item {
    id: page

    // Colores de cada recurso (los de Windows; más claros en modo oscuro)
    readonly property color cpuColor: win.dark ? "#4CC2FF" : "#117DBB"
    readonly property color memColor: win.dark ? "#D58CFF" : "#8B12AE"
    readonly property color diskColor: win.dark ? "#8BD14B" : "#4DA60C"
    readonly property color netColor: win.dark ? "#F5A65B" : "#A74F01"
    readonly property color gpuColor: win.dark ? "#4CC2FF" : "#117DBB"

    property string current: startPage.split("/")[1] || "cpu"   // p. ej. win11-taskmgr performance/gpu:0
    property bool logicalView: false     // CPU: una gráfica por procesador lógico

    function gb(b) { return ((b || 0) / 1073741824).toLocaleString(Qt.locale(), 'f', 1) }
    // "usado/total GB" o, si el total no llega a 1 GB, en MB (p. ej. GPU virtuales)
    function memPair(used, total) {
        if ((total || 0) < 1073741824)
            return Math.round((used || 0) / 1048576) + "/" + Math.round((total || 0) / 1048576) + " MB"
        return gb(used) + "/" + gb(total) + " GB"
    }
    function kbps(bytes) {
        var k = bytes * 8 / 1000
        return k < 1000 ? k.toLocaleString(Qt.locale(), 'f', 0) + " Kbps" : (k / 1000).toLocaleString(Qt.locale(), 'f', 1) + " Mbps"
    }
    function rateLabel(kb) { return kb < 1000 ? kb.toLocaleString(Qt.locale(), 'f', 0) + " Kbps" : (kb / 1000).toLocaleString(Qt.locale(), 'f', 0) + " Mbps" }
    function diskOf(id) { return sysmon.disks.find(function (d) { return "disk:" + d.name === id }) }
    function netOf(id) { return sysmon.nets.find(function (n) { return "net:" + n.name === id }) }
    function gpuOf(id) { return sysmon.gpus.find(function (g) { return "gpu:" + g.index === id }) }

    // Tarjetas de la izquierda
    readonly property var devices: {
        var l = [{ id: "cpu", title: "CPU", color: cpuColor, values: sysmon.cpuHistory, max: 100,
                   sub: win.pct(sysmon.cpu) + "  " + (sysmon.cpuStats.speed || 0).toLocaleString(Qt.locale(), 'f', 2) + " GHz" }]
        var m = sysmon.memory
        l.push({ id: "mem", title: "Memoria", color: memColor, values: sysmon.memHistory, max: 100,
                 sub: gb(m.used) + "/" + gb(m.total) + " GB (" + Math.round(m.percent || 0) + "%)" })
        for (var i = 0; i < sysmon.disks.length; ++i) {
            var d = sysmon.disks[i]
            l.push({ id: "disk:" + d.name, title: "Disco " + d.index + " (" + d.name + ")", color: diskColor, values: d.history, max: 100,
                     sub: d.type + "\n" + Math.round(d.active) + "%" })
        }
        for (var j = 0; j < sysmon.nets.length; ++j) {
            var n = sysmon.nets[j]
            l.push({ id: "net:" + n.name, title: n.type, color: netColor, values: n.history, values2: n.sendHistory, max: 0,
                     sub: n.name + "\nE: " + kbps(n.send).replace(" Kbps", "") + " R: " + kbps(n.recv) })
        }
        for (var k = 0; k < sysmon.gpus.length; ++k) {
            var g = sysmon.gpus[k]
            l.push({ id: "gpu:" + g.index, title: "GPU " + g.index, color: gpuColor, values: g.history, max: 100,
                     sub: g.name + "\n" + Math.round(g.usage) + "%" })
        }
        return l
    }
    readonly property var dev: devices.find(function (d) { return d.id === current }) || devices[0]
    readonly property bool isGpu: dev.id.startsWith("gpu")

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            title: "Rendimiento"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton { glyph: "more"; text: ""; onClicked: moreMenu.popup() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---------- Tarjetas ----------
            ListView {
                Layout.preferredWidth: 244
                Layout.fillHeight: true
                Layout.leftMargin: 12
                clip: true
                spacing: 2
                model: page.devices
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    width: 232
                    height: 76
                    radius: 6
                    color: page.current === modelData.id ? win.selection : (cardMouse.containsMouse ? win.hover : "transparent")
                    Rectangle {
                        visible: page.current === modelData.id
                        x: 0; width: 3; height: 18; radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: win.accent
                    }
                    Graph {
                        id: mini
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 50
                        values: modelData.values
                        values2: modelData.values2 || []
                        max: modelData.max
                        color: modelData.color
                        grid: false
                    }
                    Column {
                        anchors.left: mini.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Label { text: modelData.title; color: win.text; font.pixelSize: 14; width: parent.width; elide: Text.ElideRight }
                        Repeater {
                            model: modelData.sub.split("\n")
                            Label { text: modelData; color: win.subtext; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                        }
                    }
                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: page.current = modelData.id
                    }
                }
            }

            // ---------- Detalle ----------
            Flickable {
                id: detailFlick
                Layout.fillWidth: true
                Layout.preferredWidth: 100
                Layout.minimumWidth: 0
                contentWidth: width
                Layout.fillHeight: true
                clip: true
                contentHeight: detail.implicitHeight + 32
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: detail
                    x: 24
                    width: detailFlick.width - 48
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: page.dev.id.startsWith("disk") ? page.dev.title : (page.isGpu ? "GPU" : page.dev.title)
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                            color: win.text
                        }
                        Label {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            font.pixelSize: 16
                            color: win.text
                            text: {
                                var id = page.dev.id
                                if (id === "cpu") return sysmon.cpuInfo.model
                                if (id === "mem") return page.gb(sysmon.memory.physical) + " GB"
                                if (id.startsWith("disk")) { var d = page.diskOf(id); return d ? (d.model || d.name) : "" }
                                if (id.startsWith("net")) return id.substring(4)
                                var g = page.gpuOf(id); return g ? g.name : ""
                            }
                        }
                    }
                    Label {
                        visible: page.isGpu && page.gpuOf(page.dev.id) && !page.gpuOf(page.dev.id).measurable
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                        color: win.subtext
                        text: "El controlador de esta tarjeta (" + (page.gpuOf(page.dev.id) || {}).driver + ") no informa del uso de la GPU."
                    }

                    // ----- Gráfica principal (CPU, memoria, disco, red) -----
                    ColumnLayout {
                        visible: !page.isGpu
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            Label {
                                Layout.fillWidth: true
                                font.pixelSize: 12; color: win.subtext
                                text: page.dev.id === "cpu" ? "% de uso en 60 segundos"
                                    : page.dev.id === "mem" ? "Uso de memoria"
                                    : page.dev.id.startsWith("disk") ? "Tiempo activo" : "Rendimiento"
                            }
                            Label {
                                font.pixelSize: 12; color: win.subtext
                                text: page.dev.id === "mem" ? page.gb(sysmon.memory.total) + " GB"
                                    : page.dev.max > 0 ? "100%" : page.rateLabel(bigGraph.autoMax)
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(170, page.height * 0.38)
                            Graph {
                                id: bigGraph
                                anchors.fill: parent
                                visible: !(page.dev.id === "cpu" && page.logicalView)
                                values: page.dev.values
                                values2: page.dev.values2 || []
                                max: page.dev.max
                                minScale: 100      // red: 100 Kbps como mínimo, como Windows
                                color: page.dev.color
                                gridColor: Qt.alpha(page.dev.color, win.dark ? 0.18 : 0.14)
                            }
                            // Procesadores lógicos: una gráfica por núcleo, en rejilla
                            Grid {
                                id: coreGrid
                                anchors.fill: parent
                                visible: page.dev.id === "cpu" && page.logicalView
                                readonly property int n: sysmon.coreHistory.length
                                columns: Math.max(1, Math.ceil(Math.sqrt(n * 2)))
                                readonly property int rows: Math.max(1, Math.ceil(n / columns))
                                spacing: 4
                                Repeater {
                                    model: coreGrid.visible ? coreGrid.n : 0
                                    Graph {
                                        width: (coreGrid.width - (coreGrid.columns - 1) * 4) / coreGrid.columns
                                        height: (coreGrid.height - (coreGrid.rows - 1) * 4) / coreGrid.rows
                                        values: sysmon.coreHistory[index] || []
                                        max: 100
                                        color: page.cpuColor
                                        gridColor: Qt.alpha(page.cpuColor, win.dark ? 0.18 : 0.14)
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: graphMenu.popup()
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; text: "60 segundos"; font.pixelSize: 12; color: win.subtext }
                            Label { text: "0"; font.pixelSize: 12; color: win.subtext }
                        }
                    }

                    // ----- GPU: 3D, Copy, Video Encode, Video Decode y memoria -----
                    GridLayout {
                        visible: page.isGpu
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Repeater {
                            model: page.isGpu ? 4 : 0
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 100
                                spacing: 4
                                readonly property var g: page.gpuOf(page.dev.id) || {}
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { Layout.fillWidth: true; text: ["3D", "Copy", "Video Encode", "Video Decode"][index]; font.pixelSize: 12; color: win.subtext }
                                    Label { text: Math.round((parent.parent.g.engines || [0, 0, 0, 0])[index]) + "%"; font.pixelSize: 12; color: win.subtext }
                                }
                                Graph {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(90, page.height * 0.16)
                                    values: (parent.g.engineHistory || [[], [], [], []])[index]
                                    max: 100
                                    color: page.gpuColor
                                    gridColor: Qt.alpha(page.gpuColor, win.dark ? 0.18 : 0.14)
                                }
                            }
                        }
                    }
                    Repeater {
                        model: page.isGpu ? [
                            { label: "Uso de memoria de GPU dedicada", key: "vram" },
                            { label: "Uso de memoria de GPU compartida", key: "shared" }] : []
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 4
                            readonly property var g: page.gpuOf(page.dev.id) || {}
                            readonly property real total: modelData.key === "vram" ? (g.vramTotal || 0) : (g.sharedTotal || 0)
                            RowLayout {
                                Layout.fillWidth: true
                                Label { Layout.fillWidth: true; text: modelData.label; font.pixelSize: 12; color: win.subtext }
                                Label { text: parent.parent.total < 1073741824 ? Math.round(parent.parent.total / 1048576) + " MB" : page.gb(parent.parent.total) + " GB"; font.pixelSize: 12; color: win.subtext }
                            }
                            Graph {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                values: modelData.key === "vram" ? (parent.g.vramHistory || []) : (parent.g.sharedHistory || [])
                                max: Math.max(1, parent.total)
                                color: page.gpuColor
                                grid: false
                            }
                        }
                    }

                    // Segunda gráfica: velocidad de disco / composición de memoria
                    Loader {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        active: page.dev.id.startsWith("disk") || page.dev.id === "mem"
                        visible: active
                        sourceComponent: page.dev.id === "mem" ? memComposition : diskSpeed
                    }

                    // Estadísticas: valores grandes a la izquierda, ficha técnica a la derecha
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        spacing: 40
                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            columns: page.dev.id === "cpu" ? 3 : 2
                            columnSpacing: 28
                            rowSpacing: 10
                            Repeater {
                                model: page.bigStats
                                Column {
                                    Layout.columnSpan: modelData.span || 1
                                    Label { text: modelData.label; font.pixelSize: 12; color: win.subtext }
                                    Label { text: modelData.value; font.pixelSize: 20; color: win.text }
                                }
                            }
                        }
                        GridLayout {
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 4
                            Repeater {
                                model: page.smallStats.length * 2
                                Label {
                                    readonly property var item: page.smallStats[Math.floor(index / 2)]
                                    Layout.fillWidth: index % 2 === 1
                                    Layout.preferredWidth: index % 2 === 1 ? 60 : implicitWidth
                                    elide: Text.ElideRight
                                    text: index % 2 === 0 ? item[0] + ":" : item[1]
                                    font.pixelSize: 12
                                    color: index % 2 === 0 ? win.subtext : win.text
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var bigStats: {
        var id = dev.id, s = sysmon.cpuStats, m = sysmon.memory
        if (id === "cpu") return [
            { label: "Uso", value: win.pct(sysmon.cpu) },
            { label: "Velocidad", value: (s.speed || 0).toLocaleString(Qt.locale(), 'f', 2) + " GHz" },
            { label: "", value: "" },
            { label: "Procesos", value: String(s.processes || 0) },
            { label: "Subprocesos", value: String(s.threads || 0) },
            { label: "Identificadores", value: String(s.handles || 0) },
            { label: "Tiempo activo", value: s.uptime || "", span: 3 }]
        if (id === "mem") return [
            { label: "En uso (comprimida)", value: gb(m.used) + " GB (" + Math.round((m.compressed || 0) / 1048576) + " MB)" },
            { label: "Disponible", value: gb(m.available) + " GB" },
            { label: "Confirmada", value: gb(m.committed) + "/" + gb(m.commitLimit) + " GB" },
            { label: "En caché", value: gb(m.cached) + " GB" },
            { label: "Bloque paginado", value: Math.round((m.paged || 0) / 1048576) + " MB" },
            { label: "Bloque no paginado", value: Math.round((m.nonPaged || 0) / 1048576) + " MB" }]
        if (id.startsWith("disk")) {
            var d = diskOf(id) || {}
            return [
                { label: "Tiempo activo", value: Math.round(d.active || 0) + "%" },
                { label: "Tiempo medio de respuesta", value: (d.response || 0).toLocaleString(Qt.locale(), 'f', 1) + " ms" },
                { label: "Velocidad de lectura", value: sysmon.formatBytes(d.read || 0) + "/s" },
                { label: "Velocidad de escritura", value: sysmon.formatBytes(d.write || 0) + "/s" }]
        }
        if (id.startsWith("net")) {
            var n = netOf(id) || {}
            return [
                { label: "Enviar", value: kbps(n.send || 0) },
                { label: "Recibir", value: kbps(n.recv || 0) }]
        }
        var g = gpuOf(id) || {}
        return [
            { label: "Uso", value: g.measurable ? Math.round(g.usage || 0) + "%" : "N/D" },
            { label: "Memoria de GPU dedicada", value: memPair(g.vramUsed, g.vramTotal) },
            { label: "Memoria de GPU", value: gb((g.vramUsed || 0) + (g.sharedUsed || 0)) + "/" + gb((g.vramTotal || 0) + (g.sharedTotal || 0)) + " GB" },
            { label: "Memoria de GPU compartida", value: gb(g.sharedUsed) + "/" + gb(g.sharedTotal) + " GB" }]
    }
    readonly property var smallStats: {
        var id = dev.id, c = sysmon.cpuInfo, m = sysmon.memory
        if (id === "cpu") {
            var l = [["Velocidad base", (c.baseSpeed || 0).toLocaleString(Qt.locale(), 'f', 2) + " GHz"],
                     ["Sockets", String(c.sockets)], ["Núcleos", String(c.cores)],
                     ["Procesadores lógicos", String(c.logical)]]
            l.push(c.vm ? ["Máquina virtual", "Sí"] : ["Virtualización", c.virtualization])
            if (c.l1) l.push(["Caché L1", c.l1])
            if (c.l2) l.push(["Caché L2", c.l2])
            if (c.l3) l.push(["Caché L3", c.l3])
            return l
        }
        if (id === "mem") {
            var ml = [["Intercambio (swap)", gb(m.swapUsed) + "/" + gb(m.swapTotal) + " GB"]]
            if ((m.reserved || 0) > 1048576) ml.push(["Hardware reservado", Math.round(m.reserved / 1048576) + " MB"])
            return ml
        }
        if (id.startsWith("disk")) {
            var d = diskOf(id) || {}
            return [["Capacidad", sysmon.formatBytes(d.capacity || 0)],
                    ["Formateado", d.formatted ? sysmon.formatBytes(d.formatted) : "—"],
                    ["Disco del sistema", d.system ? "Sí" : "No"],
                    ["Archivo de paginación", d.pagefile ? "Sí" : "No"],
                    ["Tipo", d.type || ""]]
        }
        if (id.startsWith("net")) {
            var n = netOf(id) || {}
            return [["Nombre del adaptador", n.name || ""], ["Tipo de conexión", n.type || ""],
                    ["Dirección IPv4", n.ipv4 || "—"], ["Dirección IPv6", n.ipv6 || "—"],
                    ["Velocidad de vínculo", n.linkSpeed ? (n.linkSpeed >= 1000 ? (n.linkSpeed / 1000) + " Gbps" : n.linkSpeed + " Mbps") : "—"],
                    ["Dirección física", n.mac || "—"]]
        }
        var g = gpuOf(id) || {}
        return [["Versión del controlador", g.driverVersion || "—"], ["Controlador", g.driver || "—"],
                ["Versión de OpenGL", sysmon.openGLVersion || "—"], ["Ubicación física", g.location || "—"]]
    }

    Component {
        id: diskSpeed
        ColumnLayout {
            spacing: 4
            readonly property var d: page.diskOf(page.dev.id) || {}
            RowLayout {
                Label { Layout.fillWidth: true; text: "Velocidad de transferencia del disco"; font.pixelSize: 12; color: win.subtext }
                Label { text: sysmon.formatBytes(speedGraph.autoMax) + "/s"; font.pixelSize: 12; color: win.subtext }
            }
            Graph {
                id: speedGraph
                Layout.fillWidth: true
                Layout.preferredHeight: 90
                values: parent.d.readHistory || []
                values2: parent.d.writeHistory || []
                max: 0
                minScale: 1048576
                color: page.diskColor
                gridColor: Qt.alpha(page.diskColor, 0.15)
            }
            RowLayout {
                Label { Layout.fillWidth: true; text: "60 segundos"; font.pixelSize: 12; color: win.subtext }
                Label { text: "0"; font.pixelSize: 12; color: win.subtext }
            }
        }
    }
    Component {
        id: memComposition
        ColumnLayout {
            spacing: 4
            readonly property var m: sysmon.memory
            readonly property real total: Math.max(1, m.total || 1)
            Label { text: "Composición de memoria"; font.pixelSize: 12; color: win.subtext }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"
                border.color: page.memColor
                Row {
                    anchors.fill: parent
                    anchors.margins: 1
                    // En uso | Modificada | En espera (caché) | Libre
                    Rectangle { width: parent.width * (m.used - (m.modified || 0)) / total; height: parent.height; color: Qt.alpha(page.memColor, 0.35) }
                    Rectangle { width: Math.max(1, parent.width * (m.modified || 0) / total); height: parent.height; color: Qt.alpha(page.memColor, 0.6) }
                    Rectangle { width: 1; height: parent.height; color: page.memColor }
                    Rectangle { width: parent.width * (m.cached || 0) / total; height: parent.height; color: Qt.alpha(page.memColor, 0.12) }
                }
                ToolTip.visible: compMouse.containsMouse
                ToolTip.text: "En uso: " + page.gb(m.used) + " GB · Modificada: " + Math.round((m.modified || 0) / 1048576)
                              + " MB · En espera: " + page.gb(m.cached) + " GB · Libre: " + page.gb(m.free) + " GB"
                MouseArea { id: compMouse; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }

    // Clic derecho en la gráfica de CPU: cambiar entre uso general y procesadores lógicos
    Menu {
        id: graphMenu
        MenuItem {
            text: "Uso general"
            checkable: true
            checked: !page.logicalView
            enabled: page.dev.id === "cpu"
            onTriggered: page.logicalView = false
        }
        MenuItem {
            text: "Procesadores lógicos"
            checkable: true
            checked: page.logicalView
            enabled: page.dev.id === "cpu"
            onTriggered: page.logicalView = true
        }
        MenuSeparator {}
        MenuItem { text: "Copiar"; onTriggered: page.copySummary() }
    }
    Menu {
        id: moreMenu
        Menu {
            title: "Cambiar gráfico a"
            enabled: page.dev.id === "cpu"
            MenuItem { text: "Uso general"; checkable: true; checked: !page.logicalView; onTriggered: page.logicalView = false }
            MenuItem { text: "Procesadores lógicos"; checkable: true; checked: page.logicalView; onTriggered: page.logicalView = true }
        }
        MenuItem { text: "Copiar"; onTriggered: page.copySummary() }
    }
    TextEdit { id: clip; visible: false }
    function copySummary() {
        var t = (isGpu ? "GPU" : dev.title) + "\n"
        bigStats.forEach(function (s) { if (s.label) t += s.label + ": " + s.value + "\n" })
        smallStats.forEach(function (s) { t += s[0] + ": " + s[1] + "\n" })
        clip.text = t
        clip.selectAll()
        clip.copy()
    }
}
