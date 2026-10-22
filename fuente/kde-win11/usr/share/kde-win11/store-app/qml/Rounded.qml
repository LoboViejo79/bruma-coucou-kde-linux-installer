import QtQuick
import QtQuick.Effects

// Recorta el contenido con esquinas redondeadas de verdad (máscara en la GPU).
// Sin aceleración (renderizador por software) tapa las esquinas con el color del fondo.
Item {
    id: root
    property real radius: 8
    property color fallbackColor: win.layer
    default property alias content: inner.data

    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: win.fx
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            autoPaddingEnabled: false
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        visible: false
        layer.enabled: true
    }
    RoundCorners { visible: !win.fx; radius: root.radius; color: root.fallbackColor }
}
