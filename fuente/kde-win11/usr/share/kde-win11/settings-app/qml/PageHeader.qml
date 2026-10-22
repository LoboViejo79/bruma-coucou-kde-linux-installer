import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Título de página con ruta (p. ej. "Personalización  >  Colores")
RowLayout {
    id: root
    property var parts: []      // [{title, onClick}]
    spacing: 12

    Repeater {
        model: root.parts
        RowLayout {
            spacing: 12
            Label {
                visible: index > 0
                text: "›"
                font.pixelSize: 28
                color: win.subtext
            }
            Label {
                text: modelData.title
                font.pixelSize: 28
                font.weight: Font.DemiBold
                color: index === root.parts.length - 1 ? win.text : win.subtext
                MouseArea {
                    anchors.fill: parent
                    enabled: index < root.parts.length - 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: win.popTo(index)
                }
            }
        }
    }
}
