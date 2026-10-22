// Puntos que giran, como al iniciar sesión en Windows
import QtQuick

Item {
    id: sp
    property real size: 30
    property bool running: true
    width: size
    height: size

    Repeater {
        model: 5
        delegate: Item {
            id: d
            anchors.fill: parent
            property real angle: 0
            rotation: angle
            Rectangle {
                width: sp.size * 0.11; height: width; radius: width / 2
                color: "white"
                x: (sp.size - width) / 2
                y: 0
            }
            SequentialAnimation on angle {
                running: sp.running
                loops: Animation.Infinite
                PauseAnimation { duration: index * 140 }
                NumberAnimation { from: 0; to: 360; duration: 1500; easing.type: Easing.InOutCubic }
                PauseAnimation { duration: (4 - index) * 140 + 300 }
            }
        }
    }
}
