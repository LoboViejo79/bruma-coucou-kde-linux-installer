import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Resultados de búsqueda con filtro Todo / Aplicaciones / Juegos
Item {
    id: page
    property string query
    property var results: []
    property bool loading: true
    property string error: ""
    property int filter: 0

    readonly property var shown: results.filter(function (a) {
        var isGame = F.categoryName(a.main_categories) === "Juegos"
        return filter === 0 || (filter === 1 && !isGame) || (filter === 2 && isGame)
    })

    Component.onCompleted: F.search(query, function (apps, err) {
        loading = false
        error = err
        results = apps
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 20
        anchors.topMargin: 24
        spacing: 16

        Label {
            Layout.fillWidth: true
            text: "Resultados de «" + page.query + "»"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            color: win.text
            elide: Text.ElideRight
        }

        TabBar {
            id: tabs
            onCurrentIndexChanged: page.filter = currentIndex
            TabButton { text: "Todo"; width: implicitWidth }
            TabButton { text: "Aplicaciones"; width: implicitWidth }
            TabButton { text: "Juegos"; width: implicitWidth }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property int columns: Math.max(1, Math.floor((width + 12) / 352))
            cellWidth: Math.floor(width / columns)
            cellHeight: 120
            clip: true
            model: page.shown
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight
                AppCard { wide: true; app: modelData; width: parent.width - 12 }
            }
        }
    }

    BusyIndicator { anchors.centerIn: parent; running: page.loading }
    Label {
        anchors.centerIn: parent
        visible: !page.loading && page.shown.length === 0
        text: page.error || "No encontramos nada para «" + page.query + "».\nPrueba con otras palabras."
        horizontalAlignment: Text.AlignHCenter
        color: win.subtext
        font.pixelSize: 15
    }
}
