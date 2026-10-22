import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Cuadrícula de tarjetas anchas con carga por páginas al llegar al final.
// fetch(page, done) debe llamar a done(apps, totalPages, error).
GridView {
    id: grid
    property var fetch: null
    property string emptyText: "No hay resultados"
    property int page: 0
    property int totalPages: 1
    property bool loading: false
    property string error: ""
    property var items: []

    readonly property int columns: Math.max(1, Math.floor((width + 12) / 352))
    cellWidth: Math.floor(width / columns)
    cellHeight: 120
    clip: true
    model: items
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    delegate: Item {
        width: grid.cellWidth
        height: grid.cellHeight
        AppCard {
            wide: true
            app: modelData
            width: parent.width - 12
        }
    }

    function reload() {
        items = []; page = 0; totalPages = 1; error = ""
        loadMore()
    }
    function loadMore() {
        if (!fetch || loading || page >= totalPages) return
        loading = true
        var want = page + 1
        fetch(want, function (apps, pages, err) {
            loading = false
            if (err) { error = err; return }
            page = want
            totalPages = pages || 1
            items = items.concat(apps)
        })
    }
    onAtYEndChanged: if (atYEnd && items.length) loadMore()
    Component.onCompleted: reload()

    footer: Item {
        width: grid.width
        height: grid.loading || grid.error || (!grid.items.length) ? 120 : 24
        BusyIndicator { anchors.centerIn: parent; running: grid.loading; visible: running }
        Label {
            anchors.centerIn: parent
            visible: !grid.loading && (grid.error !== "" || grid.items.length === 0)
            text: grid.error || grid.emptyText
            color: win.subtext
        }
    }
}
