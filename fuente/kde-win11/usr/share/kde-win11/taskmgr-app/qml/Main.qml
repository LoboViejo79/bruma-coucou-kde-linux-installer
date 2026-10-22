import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.taskmanager as TaskManager
import Win11TaskMgr.Core

// Administrador de tareas de Windows 11: barra de título con buscador, panel de navegación
// plegable a la izquierda y la página a la derecha sobre una capa con la esquina redondeada.
ApplicationWindow {
    id: win
    width: 1100
    height: 760
    minimumWidth: 640
    minimumHeight: 460
    visible: true
    title: "Administrador de tareas"
    flags: Qt.Window | Qt.FramelessWindowHint | (prefs.alwaysOnTop ? Qt.WindowStaysOnTopHint : 0)

    readonly property bool dark: themeDark
    readonly property color accent: themeAccent
    readonly property color accentText: dark ? Qt.lighter(accent, 1.6) : Qt.darker(accent, 1.1)
    readonly property color bg: dark ? "#202020" : "#F3F3F3"
    readonly property color layer: dark ? "#272727" : "#F9F9F9"
    readonly property color layerBorder: dark ? "#1C1C1C" : "#E5E5E5"
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color selection: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color navSelected: dark ? "#2D2D2D" : "#EAEAEA"
    readonly property color text: dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: dark ? "#C5C5C5" : "#5F5F5F"
    readonly property bool maximized: visibility === Window.Maximized

    font.family: "Selawik"
    font.pixelSize: 14
    color: bg

    Settings {
        id: prefs
        category: "General"
        property string startPage: "processes"
        property int speed: 1000          // 0 = en pausa
        property bool alwaysOnTop: false
        property bool navExpanded: true
        property real width: 1100
        property real height: 760
    }
    Component.onCompleted: {
        width = prefs.width
        height = prefs.height
        applySpeed()
    }
    onClosing: { prefs.width = width; prefs.height = height }
    function applySpeed() {
        sysmon.paused = prefs.speed === 0
        if (prefs.speed > 0) sysmon.interval = prefs.speed
    }

    readonly property var pages: [
        { id: "processes", title: "Procesos", glyph: "start" },
        { id: "performance", title: "Rendimiento", glyph: "pulse" },
        { id: "history", title: "Historial de aplicaciones", glyph: "history" },
        { id: "startup", title: "Aplicaciones de arranque", glyph: "gauge" },
        { id: "users", title: "Usuarios", glyph: "people" },
        { id: "details", title: "Detalles", glyph: "list" },
        { id: "services", title: "Servicios", glyph: "puzzle" }
    ]
    property string current: startPage.split("/")[0] === "settings" || pages.some(function (p) { return p.id === startPage.split("/")[0] }) ? startPage.split("/")[0] : prefs.startPage
    property string search: ""
    property int detailsPid: 0      // "Ir a detalles" desde Procesos

    // ---------- Ventanas abiertas (para "Aplicaciones" y "Cambiar a") ----------
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        filterNotMinimized: false
        onCountChanged: appsTimer.restart()
        onDataChanged: appsTimer.restart()
    }
    Timer {
        id: appsTimer
        interval: 150
        onTriggered: {
            var list = []
            for (var i = 0; i < tasksModel.count; ++i) {
                var idx = tasksModel.index(i, 0)
                if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsWindow) !== true) continue
                list.push({
                    pid: tasksModel.data(idx, TaskManager.AbstractTasksModel.AppPid),
                    appId: tasksModel.data(idx, TaskManager.AbstractTasksModel.AppId) || "",
                    name: tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName) || "",
                    window: i
                })
            }
            procModel.setApps(list)
        }
    }
    Component.onDestruction: sysmon.paused = true
    function activateWindow(row) {
        if (row >= 0 && row < tasksModel.count) tasksModel.requestActivate(tasksModel.index(row, 0))
    }

    ProcessModel { id: procModel; monitor: sysmon; filter: win.current === "processes" ? win.search : "" }

    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Escape"; enabled: searchField.text !== ""; onActivated: searchField.text = "" }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.cycle(1) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: win.cycle(-1) }
    function cycle(d) {
        var i = pages.findIndex(function (p) { return p.id === current })
        current = pages[(i + d + pages.length) % pages.length].id
    }

    ResizeEdges {}

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------- Barra de título ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onDoubleTapped: win.maximized ? win.showNormal() : win.showMaximized() }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: "image://icon/utilities-system-monitor"
                    sourceSize: Qt.size(32, 32)
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Administrador de tareas"
                    font.pixelSize: 12
                    color: win.text
                }
            }
            TextField {
                id: searchField
                anchors.centerIn: parent
                width: Math.min(480, parent.width - 520)
                visible: width > 160
                height: 32
                placeholderText: "Escribe un nombre, publicador o PID para buscar"
                leftPadding: 36
                onTextChanged: searchDelay.restart()
                Timer { id: searchDelay; interval: 120; onTriggered: win.search = searchField.text.trim() }
                FluentIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"; size: 14; stroke: 1.6
                }
            }
            CaptionButtons { anchors.right: parent.right; anchors.top: parent.top }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---------- Navegación ----------
            ColumnLayout {
                Layout.preferredWidth: prefs.navExpanded ? 240 : 52
                Layout.maximumWidth: Layout.preferredWidth
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.leftMargin: 4
                spacing: 2
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                NavItem {
                    Layout.fillWidth: true
                    glyph: "hamburger"
                    title: ""
                    onClicked: prefs.navExpanded = !prefs.navExpanded
                }
                Repeater {
                    model: win.pages
                    NavItem {
                        Layout.fillWidth: true
                        glyph: modelData.glyph
                        title: modelData.title
                        compact: !prefs.navExpanded
                        selected: win.current === modelData.id
                        onClicked: win.current = modelData.id
                    }
                }
                Item { Layout.fillHeight: true }
                NavItem {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    glyph: "settings"
                    title: "Configuración"
                    compact: !prefs.navExpanded
                    selected: win.current === "settings"
                    onClicked: win.current = "settings"
                }
            }

            // ---------- Contenido (capa con la esquina superior izquierda redondeada) ----------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: -8
                    anchors.bottomMargin: -8
                    radius: 8
                    color: win.layer
                    border.color: win.layerBorder
                }
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    anchors.margins: 1
                    asynchronous: false
                    source: {
                        switch (win.current) {
                        case "performance": return "PerformancePage.qml"
                        case "history": return "HistoryPage.qml"
                        case "startup": return "StartupPage.qml"
                        case "users": return "UsersPage.qml"
                        case "details": return "DetailsPage.qml"
                        case "services": return "ServicesPage.qml"
                        case "settings": return "SettingsPage.qml"
                        default: return "ProcessesPage.qml"
                        }
                    }
                    onLoaded: { item.opacity = 0; fadeIn.restart() }
                    NumberAnimation { id: fadeIn; target: pageLoader.item; property: "opacity"; to: 1; duration: 150 }
                }
            }
        }
    }

    RunTaskDialog { id: runDialog }

    // ---------- Formatos compartidos ----------
    function pct(v) { return (v < 0.05 ? "0" : v.toLocaleString(Qt.locale(), 'f', 1)) + "%" }
    function mb(bytes) { return (bytes / 1048576).toLocaleString(Qt.locale(), 'f', 1) + " MB" }
    function mbps(bytes) { return (bytes / 1048576).toLocaleString(Qt.locale(), 'f', 1) + " MB/s" }
    function netRate(bytes) { return (bytes * 8 / 1e6).toLocaleString(Qt.locale(), 'f', 1) + " Mbps" }
    // Tinte de las celdas (mapa de calor), de amarillo pálido a naranja
    function heat(t) {
        t = Math.max(0, Math.min(1, t))
        if (dark) return Qt.rgba(0.95, 0.70 - 0.25 * t, 0.15, 0.06 + 0.40 * t)
        return Qt.rgba(1.0, 0.957 - 0.20 * t, 0.77 - 0.45 * t, 1)
    }
    readonly property real diskActive: {
        var m = 0
        for (var i = 0; i < sysmon.disks.length; ++i) m = Math.max(m, sysmon.disks[i].active)
        return m
    }
    readonly property real gpuPercent: {
        var m = 0
        for (var i = 0; i < sysmon.gpus.length; ++i) m = Math.max(m, sysmon.gpus[i].usage)
        return m
    }
    readonly property real netPercent: {
        var link = 0
        for (var i = 0; i < sysmon.nets.length; ++i) link += sysmon.nets[i].linkSpeed || 0
        if (link <= 0) link = 1000
        return Math.min(100, sysmon.netTotal * 8 / (link * 1e6) * 100)
    }
}
