import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property string selKey: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        PageHeader {
            title: "Usuarios"
            CommandButton { glyph: "runtask"; text: "Ejecutar nueva tarea"; onClicked: runDialog.open() }
            CommandButton {
                glyph: "user"
                text: "Administrar cuentas"
                onClicked: tools.launch("win11-settings", ["accounts"])
            }
        }
        DataTable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: sysmon.users
            twoLineHeader: true
            selectedKey: page.selKey
            columns: [
                { title: "Usuario", width: 0 },
                { title: "Estado", width: 120 },
                { title: "CPU", width: 84, align: "right", heat: true, total: win.pct(sysmon.cpu) },
                { title: "Memoria", width: 104, align: "right", heat: true, total: win.pct(sysmon.memory.percent || 0) },
                { title: "Disco", width: 96, align: "right", heat: true, total: win.pct(win.diskActive) },
                { title: "Red", width: 96, align: "right", heat: true, total: win.pct(win.netPercent) }
            ]
            cellText: function (r, i) {
                switch (i) {
                case 0: return r.fullName ? r.fullName + " (" + r.name + ")" : r.name
                case 1: return r.name === sysmon.userName ? "Activo" : ""
                case 2: return win.pct(r.cpu)
                case 3: return win.mb(r.mem)
                case 4: return r.disk < 1 ? "0 MB/s" : win.mbps(r.disk)
                case 5: return r.net < 1 ? "0 Mbps" : win.netRate(r.net)
                }
                return ""
            }
            cellHeat: function (r, i) {
                return i === 2 ? r.cpu / 40 : i === 3 ? r.mem / Math.max(1, (sysmon.memory.total || 1) * 0.5)
                     : i === 4 ? r.disk / (20 * 1048576) : i === 5 ? r.net / (1.25 * 1048576) : -1
            }
            rowKey: function (r) { return r.name }
            rowIcon: function (r) { return "user-identity" }
            onRowSelected: function (r) { page.selKey = r.name }
        }
    }
}
