import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Título de página con ruta (p. ej. "Personalización  >  Colores")
RowLayout {
    id: root
    property var parts: []      // [{title, onClick}]
    spacing: 12
    // Lo que se muestra: queda fijo mientras la página se va (en la transición a otra), así no cambia
    // de título mientras desaparece
    property var partes: []
    function enUso() {
        for (var p = root.parent; p; p = p.parent) if (p.actual !== undefined) return p.actual
        return true
    }
    // (dos vueltas después: para entonces Main.qml ya decidió cuál página es la nueva)
    onPartsChanged: Qt.callLater(() => Qt.callLater(() => { if (enUso()) root.partes = root.parts }))
    Component.onCompleted: partes = parts

    Repeater {
        model: root.partes
        RowLayout {
            spacing: 12
            Label {
                visible: index > 0
                text: "›"
                font.pixelSize: 28
                color: win.subtext
            }
            Label {
                // El último de la ruta: ahí llega el título de la tarjeta tocada (ver Main.qml)
                objectName: index === root.partes.length - 1 ? "heroDestino" : ""
                text: modelData.title
                font.pixelSize: 28
                font.weight: Font.DemiBold
                color: index === root.partes.length - 1 ? win.text : win.subtext
                MouseArea {
                    anchors.fill: parent
                    enabled: index < root.partes.length - 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: win.popTo(index)
                }
            }
        }
    }
}
