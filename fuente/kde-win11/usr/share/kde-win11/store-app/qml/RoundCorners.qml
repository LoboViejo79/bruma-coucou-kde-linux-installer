import QtQuick
import QtQuick.Shapes

// Redondea las esquinas de imágenes tapándolas con el color del fondo.
// (clip solo recorta en rectángulo y las máscaras con sombreadores no van en el renderizador por software)
Item {
    id: root
    property real radius: 8
    property color color: win.layer
    anchors.fill: parent

    component Corner: Shape {
        property int rot: 0
        width: root.radius; height: root.radius
        rotation: rot
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            startX: 0; startY: 0
            PathLine { x: root.radius; y: 0 }
            PathArc { x: 0; y: root.radius; radiusX: root.radius; radiusY: root.radius; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: 0 }
        }
    }
    Corner { x: 0; y: 0; rot: 0 }
    Corner { x: root.width - root.radius; y: 0; rot: 90 }
    Corner { x: root.width - root.radius; y: root.height - root.radius; rot: 180 }
    Corner { x: 0; y: root.height - root.radius; rot: 270 }
}
