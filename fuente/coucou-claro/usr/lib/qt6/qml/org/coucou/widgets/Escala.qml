import QtQuick

// Coucou: lo de adentro de un widget se diseña a un tamaño fijo (anchoBase × altoBase) y se agranda o
// achica junto con el widget, sin deformarse: así se ve igual de bien chico que grande.
Item {
    id: e
    property real anchoBase: 170
    property real altoBase: 170
    default property alias contenido: caja.data
    readonly property real k: Math.max(0.1, Math.min(width / anchoBase, height / altoBase))
    Item {
        id: caja
        width: e.anchoBase; height: e.altoBase
        anchors.centerIn: parent
        scale: e.k
    }
}
