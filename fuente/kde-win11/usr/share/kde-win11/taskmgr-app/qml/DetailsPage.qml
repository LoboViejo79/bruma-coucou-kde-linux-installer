import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Win11TaskMgr.Core

Item {
    id: page
    property var sel: null    // {key, pid, name, efficiency}

    ProcessModel { id: details; monitor: sysmon; details: true; filter: win.search }

    Component.onCompleted: {
        // Llegada desde "Ir a detalles": selecciona y muestra ese proceso
        if (win.detailsPid > 0) {
            sel = { key: "p:" + win.detailsPid, pid: win.detailsPid, name: "", efficiency: false }
            scrollTimer.start()
        }
    }
    Timer {
        id: scrollTimer
        interval: 50
        onTriggered: {
            for (var i = 0; i < details.rowCount(); ++i) {
                if (details.data(details.index(i, 0), 258) === page.sel.key) { table.positionViewAtIndex(i, ListView.Center); break }
            }
            win.detailsPid = 0
        }
    }

    Shortcut { sequence: "Delete"; enabled: page.sel !== null; onActivated: details.endTask(page.sel.key) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PageHeader {
            title: "Detalles"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton { glyph: "endtask"; text: "Finalizar tarea"; enabled: page.sel !== null; onClicked: details.endTask(page.sel.key) }
            CommandButton {
                glyph: "leaf"
                text: "Modo de eficiencia"
                enabled: page.sel !== null
                checkable: true
                checked: page.sel !== null && page.sel.efficiency
                onClicked: {
                    details.setEfficiency(page.sel.key, !page.sel.efficiency)
                    page.sel = Object.assign({}, page.sel, { efficiency: !page.sel.efficiency })
                }
            }
        }
        DataTable {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: details
            sortColumn: details.sortColumn
            sortDescending: details.sortDescending
            selectedKey: page.sel ? page.sel.key : ""
            minFill: 200
            columns: [
                { title: "Nombre", width: 0, sort: 0 },
                { title: "PID", width: 80, sort: 6, align: "right" },
                { title: "Estado", width: 120, sort: 1, status: true },
                { title: "Nombre de usuario", width: 140, sort: 7 },
                { title: "CPU", width: 70, sort: 2, align: "right" },
                { title: "Memoria (privada)", width: 140, sort: 3, align: "right" },
                { title: "Descripción", width: 240, sort: 8 }
            ]
            cellText: function (r, i) {
                switch (i) {
                case 0: return r.name
                case 1: return String(r.pid)
                case 2: return r.status
                case 3: return r.user
                case 4: return Math.round(r.cpu).toString().padStart(2, "0")
                case 5: return Math.round(r.mem / 1024).toLocaleString(Qt.locale(), 'f', 0) + " K"
                case 6: return r.description
                }
                return ""
            }
            rowKey: function (r) { return r.key }
            rowIcon: function (r) { return r.iconName }
            rowEfficiency: function (r) { return r.efficiency }
            onSortRequested: function (c) { details.sortBy(c) }
            onRowSelected: function (r) { page.sel = { key: r.key, pid: r.pid, name: r.name, efficiency: r.efficiency } }
            onRowMenu: function (r) { page.sel = { key: r.key, pid: r.pid, name: r.name, efficiency: r.efficiency }; menu.popup() }
        }
    }

    Menu {
        id: menu
        MenuItem { text: "Finalizar tarea"; onTriggered: details.endTask(page.sel.key) }
        MenuItem { text: "Finalizar árbol de procesos"; onTriggered: details.endTree(page.sel.pid) }
        MenuItem {
            text: "Modo de eficiencia"
            checkable: true
            checked: page.sel !== null && page.sel.efficiency
            onTriggered: details.setEfficiency(page.sel.key, checked)
        }
        Menu {
            title: "Establecer prioridad"
            MenuItem { text: "Alta"; onTriggered: details.setPriority(page.sel.pid, -10) }
            MenuItem { text: "Por encima de lo normal"; onTriggered: details.setPriority(page.sel.pid, -5) }
            MenuItem { text: "Normal"; onTriggered: details.setPriority(page.sel.pid, 0) }
            MenuItem { text: "Por debajo de lo normal"; onTriggered: details.setPriority(page.sel.pid, 5) }
            MenuItem { text: "Baja"; onTriggered: details.setPriority(page.sel.pid, 15) }
        }
        MenuSeparator {}
        MenuItem { text: "Abrir ubicación del archivo"; onTriggered: details.openLocation(page.sel.pid) }
        MenuItem { text: "Buscar en línea"; onTriggered: details.searchOnline(page.sel.name) }
    }
}
