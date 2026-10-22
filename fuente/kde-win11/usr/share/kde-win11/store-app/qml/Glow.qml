import QtQuick
import QtQuick.Effects

// Resplandor de color detrás de una imagen (como el del carrusel de la Microsoft Store):
// la imagen muy reducida y desenfocada, desbordando su caja.
Item {
    id: root
    property var sources: []        // URLs de las imágenes
    property int current: 0

    Item {
        id: glow
        anchors.fill: parent
        layer.enabled: win.fx
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            blurMultiplier: 2.0
            saturation: 0.8
            brightness: 0.08
            autoPaddingEnabled: true
        }
        Repeater {
            model: root.sources
            Image {
                anchors.fill: parent
                anchors.margins: 10
                source: modelData
                sourceSize: Qt.size(48, 27)
                fillMode: Image.Stretch
                smooth: true
                opacity: index === root.current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700 } }
            }
        }
    }
}
