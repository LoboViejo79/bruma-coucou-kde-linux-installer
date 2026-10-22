import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var sel: null     // {key, kind, pid, window, efficiency, name, count}

    function select(row) {
        sel = { key: row.key, kind: row.kind, pid: row.pid, window: row.window, efficiency: row.efficiency,
                name: row.name, count: row.count, expanded: row.expanded }
    }
    function endSelected() { if (sel) procModel.endTask(sel.key) }

    Shortcut { sequence: "Delete"; enabled: page.sel !== null; onActivated: page.endSelected() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            title: "Procesos"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton { glyph: "endtask"; text: "Finalizar tarea"; enabled: page.sel !== null; onClicked: page.endSelected() }
            CommandButton {
                glyph: "leaf"
                text: "Modo de eficiencia"
                enabled: page.sel !== null
                checkable: true
                checked: page.sel !== null && page.sel.efficiency
                onClicked: {
                    procModel.setEfficiency(page.sel.key, !page.sel.efficiency)
                    page.sel = Object.assign({}, page.sel, { efficiency: !page.sel.efficiency })
                }
            }
        }

        DataTable {
            id: table
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: procModel
            twoLineHeader: true
            sortColumn: procModel.sortColumn
            sortDescending: procModel.sortDescending
            selectedKey: page.sel ? page.sel.key : ""
            columns: [
                { title: "Nombre", width: 0, sort: 0 },
                { title: "Estado", width: 130, sort: 1, status: true },
                { title: "CPU", width: 84, sort: 2, align: "right", heat: true, total: win.pct(sysmon.cpu) },
                { title: "Memoria", width: 104, sort: 3, align: "right", heat: true, total: win.pct(sysmon.memory.percent || 0) },
                { title: "Disco", width: 96, sort: 4, align: "right", heat: true, total: win.pct(win.diskActive) },
                { title: "Red", width: 96, sort: 5, align: "right", heat: true, total: win.pct(win.netPercent) },
                { title: "GPU", width: 84, sort: 9, align: "right", heat: true, total: win.pct(win.gpuPercent) },
                { title: "Motor de GPU", width: 140, sort: 10 }
            ]
            cellText: function (r, i) {
                switch (i) {
                case 0: return r.name
                case 1: return r.status
                case 2: return win.pct(r.cpu)
                case 3: return win.mb(r.mem)
                case 4: return r.disk < 1 ? "0 MB/s" : win.mbps(r.disk)
                case 5: return r.net < 1 ? "0 Mbps" : win.netRate(r.net)
                case 6: return win.pct(r.gpu)
                case 7: return r.gpuEngine
                }
                return ""
            }
            cellHeat: function (r, i) {
                switch (i) {
                case 2: return r.cpu / 40
                case 3: return r.mem / Math.max(1, (sysmon.memory.total || 1) * 0.12)
                case 4: return r.disk / (20 * 1048576)
                case 5: return r.net / (1.25 * 1048576)
                case 6: return r.gpu / 40
                }
                return -1
            }
            rowKey: function (r) { return r.key }
            rowKind: function (r) { return r.kind }
            rowIcon: function (r) { return r.iconName }
            rowDepth: function (r) { return r.depth }
            rowExpandable: function (r) { return r.kind === 1 && r.count > 1 }
            rowExpanded: function (r) { return r.expanded }
            rowEfficiency: function (r) { return r.efficiency }
            onSortRequested: function (c) { procModel.sortBy(c) }
            onRowSelected: function (r) { page.select(r) }
            onRowToggled: function (r) { procModel.toggle(r.key) }
            onRowActivated: function (r) {
                if (r.window >= 0) win.activateWindow(r.window)
                else if (r.kind === 1 && r.count > 1) procModel.toggle(r.key)
            }
            onRowMenu: function (r) { page.select(r); menu.popup() }
        }
    }

    Menu {
        id: menu
        MenuItem {
            text: page.sel && page.sel.expanded ? "Contraer" : "Expandir"
            visible: page.sel !== null && page.sel.kind === 1 && page.sel.count > 1
            height: visible ? implicitHeight : 0
            onTriggered: procModel.toggle(page.sel.key)
        }
        MenuItem {
            text: "Cambiar a"
            visible: page.sel !== null && page.sel.window >= 0
            height: visible ? implicitHeight : 0
            onTriggered: win.activateWindow(page.sel.window)
        }
        MenuItem { text: "Finalizar tarea"; onTriggered: page.endSelected() }
        MenuItem {
            text: "Modo de eficiencia"
            checkable: true
            checked: page.sel !== null && page.sel.efficiency
            onTriggered: procModel.setEfficiency(page.sel.key, checked)
        }
        MenuSeparator {}
        MenuItem { text: "Abrir ubicación del archivo"; onTriggered: procModel.openLocation(page.sel.pid) }
        MenuItem { text: "Buscar en línea"; onTriggered: procModel.searchOnline(page.sel.name) }
        MenuItem {
            text: "Ir a detalles"
            onTriggered: { win.detailsPid = page.sel.pid; win.current = "details" }
        }
    }
}
