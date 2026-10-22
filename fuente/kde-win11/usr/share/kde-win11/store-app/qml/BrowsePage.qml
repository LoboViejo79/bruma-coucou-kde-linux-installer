import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Lista navegable: título + chips de categoría opcionales + cuadrícula con carga por páginas
Item {
    id: page
    property string title
    // [{title, fetch(page, perPage, cb)}]; con un solo elemento no se muestran chips
    property var sections: []
    property int current: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 32
        anchors.rightMargin: 20
        anchors.topMargin: 24
        spacing: 16

        Label {
            text: page.title
            font.pixelSize: 28
            font.weight: Font.DemiBold
            color: win.text
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            visible: page.sections.length > 1
            contentWidth: chips.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chips
                spacing: 8
                Repeater {
                    model: page.sections
                    Rectangle {
                        readonly property bool on: index === page.current
                        height: 32
                        width: chipText.implicitWidth + 28
                        radius: 16
                        color: on ? win.accent : chipArea.containsMouse ? win.cardHover : win.cardBg
                        border.color: on ? win.accent : win.cardBorder
                        Label {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.title
                            color: parent.on ? "white" : win.text
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { page.current = index; grid.reload() }
                        }
                    }
                }
            }
        }

        AppGrid {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            fetch: function (p, done) {
                var s = page.sections[page.current]
                if (s) s.fetch(p, 30, done)
            }
        }
    }
}
