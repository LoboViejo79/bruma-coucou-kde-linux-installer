import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property string sel: ""
    property int sortCol: 0
    property bool desc: false
    Component.onCompleted: tools.loadServices()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: tools.loadServices() }

    readonly property var rows: {
        var list = tools.services.slice()
        var f = win.search.toLowerCase()
        if (f) list = list.filter(function (r) { return r.name.toLowerCase().indexOf(f) >= 0 || r.description.toLowerCase().indexOf(f) >= 0 })
        var k = ["name", "description", "status", "group"][sortCol]
        list.sort(function (a, b) { var c = String(a[k]).localeCompare(String(b[k])); return desc ? -c : c })
        return list
    }
    readonly property var selRow: sel ? rows.find(function (r) { return r.group + ":" + r.name === sel }) : null
    function act(a) { if (selRow) tools.serviceAction(selRow.name, a, selRow.user) }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PageHeader {
            title: "Servicios"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton { glyph: "start2"; text: "Iniciar"; enabled: !!page.selRow && !page.selRow.running; onClicked: page.act("start") }
            CommandButton { glyph: "stop"; text: "Detener"; enabled: !!page.selRow && page.selRow.running; onClicked: page.act("stop") }
            CommandButton { glyph: "update"; text: "Reiniciar"; enabled: !!page.selRow && page.selRow.running; onClicked: page.act("restart") }
        }
        DataTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.rows
            sortColumn: page.sortCol
            sortDescending: page.desc
            selectedKey: page.sel
            columns: [
                { title: "Nombre", width: 0, sort: 0 },
                { title: "Descripción", width: 300, sort: 1 },
                { title: "Estado", width: 120, sort: 2 },
                { title: "Grupo", width: 100, sort: 3 }
            ]
            cellText: function (r, i) { return [r.name, r.description, r.status, r.group][i] }
            rowKey: function (r) { return r.group + ":" + r.name }
            rowIcon: function (r) { return "preferences-system-services" }
            onSortRequested: function (c) { if (page.sortCol === c) page.desc = !page.desc; else { page.sortCol = c; page.desc = false } }
            onRowSelected: function (r) { page.sel = r.group + ":" + r.name }
            onRowMenu: function (r) { page.sel = r.group + ":" + r.name; menu.popup() }
        }
    }
    Menu {
        id: menu
        MenuItem { text: "Iniciar"; enabled: !!page.selRow && !page.selRow.running; onTriggered: page.act("start") }
        MenuItem { text: "Detener"; enabled: !!page.selRow && page.selRow.running; onTriggered: page.act("stop") }
        MenuItem { text: "Reiniciar"; enabled: !!page.selRow && page.selRow.running; onTriggered: page.act("restart") }
        MenuSeparator {}
        MenuItem { text: "Buscar en línea"; onTriggered: procModel.searchOnline(page.selRow.name + " service linux") }
    }
}
