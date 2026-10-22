import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var sel: null
    property int sortCol: 0
    property bool desc: false
    Component.onCompleted: tools.loadStartup()

    readonly property var rows: {
        var list = tools.startupApps.slice()
        var f = win.search.toLowerCase()
        if (f) list = list.filter(function (r) { return r.name.toLowerCase().indexOf(f) >= 0 })
        var k = ["name", "publisher", "enabled"][sortCol] || "name"
        list.sort(function (a, b) {
            var c = k === "enabled" ? (a.enabled === b.enabled ? 0 : a.enabled ? -1 : 1) : String(a[k]).localeCompare(String(b[k]))
            return desc ? -c : c
        })
        return list
    }
    readonly property var selRow: sel ? rows.find(function (r) { return r.id === sel }) : null

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PageHeader {
            title: "Aplicaciones de arranque"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton {
                glyph: page.selRow && page.selRow.enabled ? "stop" : "check"
                text: page.selRow && page.selRow.enabled ? "Deshabilitar" : "Habilitar"
                enabled: page.selRow !== null && page.selRow !== undefined
                onClicked: tools.setStartupEnabled(page.selRow.id, !page.selRow.enabled)
            }
        }
        Label {
            Layout.leftMargin: 24
            Layout.bottomMargin: 8
            text: "Programas que se abren solos al iniciar sesión."
            color: win.subtext
            font.pixelSize: 12
        }
        DataTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.rows
            sortColumn: page.sortCol
            sortDescending: page.desc
            selectedKey: page.sel || ""
            columns: [
                { title: "Nombre", width: 0, sort: 0 },
                { title: "Editor", width: 140, sort: 1 },
                { title: "Estado", width: 130, sort: 2 },
                { title: "Impacto de inicio", width: 150 }
            ]
            cellText: function (r, i) {
                return [r.name, r.publisher, r.enabled ? "Habilitado" : "Deshabilitado", "No medido"][i]
            }
            rowKey: function (r) { return r.id }
            rowIcon: function (r) { return r.icon || "application-x-executable" }
            onSortRequested: function (c) { if (page.sortCol === c) page.desc = !page.desc; else { page.sortCol = c; page.desc = false } }
            onRowSelected: function (r) { page.sel = r.id }
            onRowActivated: function (r) { tools.setStartupEnabled(r.id, !r.enabled) }
            onRowMenu: function (r) { page.sel = r.id; menu.popup() }
        }
    }
    Menu {
        id: menu
        MenuItem {
            text: page.selRow && page.selRow.enabled ? "Deshabilitar" : "Habilitar"
            onTriggered: tools.setStartupEnabled(page.selRow.id, !page.selRow.enabled)
        }
        MenuItem { text: "Abrir ubicación del archivo"; onTriggered: tools.openStartupLocation(page.selRow.id) }
        MenuItem { text: "Buscar en línea"; onTriggered: procModel.searchOnline(page.selRow.name) }
    }
}
