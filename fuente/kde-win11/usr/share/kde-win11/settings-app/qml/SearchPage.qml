import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Pages.js" as P

// Resultados del buscador del panel lateral
ScrollView {
    id: root
    property string query
    contentWidth: availableWidth

    readonly property var results: {
        var norm = function (s) { return s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "") }
        var q = norm(query)
        var out = []
        P.pages.forEach(function (pg) {
            if (norm(pg.title).indexOf(q) >= 0)
                out.push({ title: pg.title, desc: "Categoría", icon: pg.icon, category: pg.id })
        })
        P.flatten(backend.kcms).forEach(function (r) {
            var it = r.item
            if (norm(it.title).indexOf(q) < 0 && norm(it.desc).indexOf(q) < 0) return
            var where = [P.byId(r.category).title].concat(r.path.map(function (p) { return p.title })).join("  ›  ")
            out.push({ title: it.title, desc: where + "  ›  " + it.desc.replace("%HOST%", backend.sysInfo.hostname), icon: it.icon, item: it, path: r.path, parent: r.category })
        })
        if ("modo oscuro claro tema color enfasis transparencia".indexOf(q) >= 0)
            out.unshift({ title: "Colores", desc: "Personalización  ›  Modo oscuro, color de énfasis, transparencia", icon: "preferences-desktop-color", item: { page: "colors", title: "Colores" }, path: [], parent: "personalization" })
        // sin duplicados (un mismo módulo puede estar en varias categorías)
        var seen = {}
        return out.filter(function (r) {
            var k = r.item ? (r.item.kcm || r.item.action || r.item.page || r.title) : r.category
            if (seen[k]) return false
            seen[k] = true
            return true
        })
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader { Layout.topMargin: 4; Layout.bottomMargin: 20; parts: [{ title: "Resultados de búsqueda" }] }

        Label {
            visible: root.results.length === 0
            text: "No se encontraron resultados para «" + root.query + "»"
            color: win.subtext
        }

        Repeater {
            model: root.results
            SettingsCard {
                Layout.fillWidth: true
                title: modelData.title
                description: modelData.desc
                iconName: modelData.icon
                onClicked: {
                    if (modelData.category) { win.openCategory(modelData.category); return }
                    var it = modelData.item
                    if (!it.page && !it.items) { win.activate(it); return }
                    win.openCategory(modelData.parent)
                    modelData.path.forEach(function (p) { win.activate(p) })
                    win.activate(it)
                }
            }
        }
    }
}
