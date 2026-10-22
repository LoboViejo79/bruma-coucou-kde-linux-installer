/*
    Coucou Code: pantalla de carga. Mochi en el centro sobre el violeta de
    Coucou, con los tres puntos de "escribiendo" del chat.
    Empieza igual que termina el inicio de sesión (violeta noche con Mochi), deja
    ver el fondo desenfocado y al final se disuelve en el escritorio, que tiene
    ese mismo fondo: el paso del login a la sesión se ve como una sola animación.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    property int stage
    color: "#14123A"

    // El mismo fondo de auroras que la pantalla de arranque (Plymouth)
    Image {
        anchors.fill: parent
        source: "bg.png"
        fillMode: Image.Stretch
    }

    onStageChanged: {
        if (stage == 2) intro.start()
        if (stage == 5) outro.start()
    }

    // El fondo del login y del escritorio, ya desenfocado (lo prepara login-theme)
    Image {
        id: wall
        anchors.fill: parent
        source: "file:///var/lib/coucou/login-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        onStatusChanged: if (status === Image.Ready) opacity = 1
    }
    // Velo de auroras: del todo opaco como el final del arranque, después deja ver el fondo
    Image {
        id: veil
        anchors.fill: parent
        source: "bg.png"
        fillMode: Image.Stretch
        opacity: wall.opacity > 0 ? 0.62 : 1
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
    }

    // Brillo violeta detrás de Mochi, suave
    RadialGradient {
        anchors.centerIn: mochi
        width: 520; height: 520
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#556574F6" }
            GradientStop { position: 0.5; color: "#00000000" }
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.6; duration: 1400; easing.type: Easing.InOutSine }
        }
    }

    // Onda que sale de Mochi cada 2,6 s, como en el arranque
    Rectangle {
        id: ripple
        anchors.centerIn: mochi
        property real k: 0
        width: (150 + 200 * (1 - (1 - k) * (1 - k))) * 0.907; height: width
        radius: width / 2
        color: "transparent"
        border.color: "#B3A8FF"; border.width: 3
        opacity: 0.45 * (1 - k)
        SequentialAnimation on k {
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 1800 }
            PauseAnimation { duration: 800 }
        }
    }

    Image {
        id: mochi
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        source: "mochi.png"
        sourceSize: Qt.size(170, 170)
        opacity: 1
        SequentialAnimation on anchors.verticalCenterOffset {
            loops: Animation.Infinite
            NumberAnimation { to: -42; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: -30; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    Text {
        id: name
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: mochi.bottom
        anchors.topMargin: 24
        text: "Coucou"
        color: "#FFFFFF"
        font.family: "Inter"; font.pixelSize: 30; font.weight: Font.DemiBold
        opacity: 1
    }

    // Tres puntos, como Mochi escribiendo
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: name.bottom
        anchors.topMargin: 22
        spacing: 10
        opacity: 1
        Repeater {
            model: 3
            Rectangle {
                width: 10; height: 10; radius: 5; color: "#A79BFF"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 180 }
                    NumberAnimation { to: 0.25; duration: 360 }
                    NumberAnimation { to: 1; duration: 360 }
                    PauseAnimation { duration: (2 - index) * 180 }
                }
            }
        }
    }

    // Barra de carga: sigue desde donde la dejó el arranque (Plymouth llega al 70%)
    Item {
        id: progress
        width: 280; height: 6
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 175
        Rectangle { anchors.fill: parent; radius: 3; color: "#24FFFFFF" }
        Rectangle {
            id: bar
            height: parent.height; radius: 3
            width: parent.width * Math.min(1, 0.7 + 0.3 * root.stage / 6)
            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#A79BFF" }
                GradientStop { position: 1; color: "#6574F6" }
            }
        }
        // Brillo que late en la punta
        RadialGradient {
            width: 36; height: 36
            x: bar.width - 3 - width / 2; y: parent.height / 2 - height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C89C95FF" }
                GradientStop { position: 0.5; color: "#009C95FF" }
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: progress.y + 24
        text: root.stage >= 5 ? "¡Listo!" : "Casi listo…"
        color: "#E6C9C3FF"
        font.family: "Inter"; font.pixelSize: 15; font.weight: 450
    }

    ParallelAnimation {
        id: intro
        NumberAnimation { target: name; property: "opacity"; to: 1; duration: 300 }
        NumberAnimation { target: dots; property: "opacity"; to: 1; duration: 300 }
    }
    ParallelAnimation {
        id: outro
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 550; easing.type: Easing.InOutQuad }
        NumberAnimation { target: mochi; property: "scale"; to: 0.8; duration: 450; easing.type: Easing.InCubic }
    }

    Component.onCompleted: intro.start()
}
