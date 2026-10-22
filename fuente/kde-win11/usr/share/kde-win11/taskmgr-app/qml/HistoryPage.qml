import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property string selKey: ""
    property int sortCol: 1
    property bool desc: true

    readonly property var rows: {
        var list = procModel.appHistory.slice()
        var f = win.search.toLowerCase()
        if (f) list = list.filter(function (r) { return r.name.toLowerCase().indexOf(f) >= 0 })
        var keys = ["name", "seconds", "net", "disk"]
        var k = keys[sortCol]
        list.sort(function (a, b) {
            var c = k === "name" ? a.name.localeCompare(b.name) : a[k] - b[k]
            return desc ? -c : c
        })
        return list
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PageHeader {
            title: "Historial de aplicaciones"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
        }
        Label {
            Layout.leftMargin: 24
            Layout.bottomMargin: 8
            text: "Uso de recursos de las aplicaciones abiertas en esta sesión de " + sysmon.userName + "."
            color: win.subtext
            font.pixelSize: 12
        }
        DataTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: page.rows
            sortColumn: page.sortCol
            sortDescending: page.desc
            selectedKey: page.selKey
            columns: [
                { title: "Nombre", width: 0, sort: 0 },
                { title: "Tiempo de CPU", width: 130, sort: 1, align: "right", heat: true },
                { title: "Red", width: 120, sort: 2, align: "right", heat: true },
                { title: "Disco", width: 120, sort: 3, align: "right", heat: true }
            ]
            cellText: function (r, i) {
                return [r.name, r.cpuTime, sysmon.formatBytes(r.net), sysmon.formatBytes(r.disk)][i]
            }
            cellHeat: function (r, i) {
                return i === 1 ? r.seconds / 600 : i === 2 ? r.net / 1e8 : i === 3 ? r.disk / 1e9 : -1
            }
            rowKey: function (r) { return r.name }
            rowIcon: function (r) { return r.icon }
            onSortRequested: function (c) { if (page.sortCol === c) page.desc = !page.desc; else { page.sortCol = c; page.desc = c > 0 } }
            onRowSelected: function (r) { page.selKey = r.name }
        }
    }
}
