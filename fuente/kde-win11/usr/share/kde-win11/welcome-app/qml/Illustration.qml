import QtQuick

// Ilustración de la columna izquierda (como los dibujos de la instalación de Windows 11):
// halo suave del color de énfasis, una tarjeta con degradado y el icono, y unos círculos flotantes.
Item {
    id: root
    property string glyph: "rocket"
    property string image: ""          // icono del tema en lugar del glifo (p. ej. el logo de CachyOS)
    property color accent: win.accent
    width: 260
    height: 260

    Rectangle {
        anchors.centerIn: parent
        width: root.width; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(root.accent, win.dark ? 0.22 : 0.16) }
            GradientStop { position: 1; color: Qt.alpha(root.accent, 0.02) }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: root.width * 0.72; height: width; radius: width / 2
        color: Qt.alpha(root.accent, win.dark ? 0.12 : 0.10)
    }
    // Sombra de la tarjeta
    Rectangle {
        x: tile.x + 4; y: tile.y + 10
        width: tile.width; height: tile.height; radius: tile.radius
        color: Qt.rgba(0, 0, 0, win.dark ? 0.35 : 0.12)
    }
    Rectangle {
        id: tile
        anchors.centerIn: parent
        width: root.width * 0.44; height: width; radius: 22
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.accent, 1.35) }
            GradientStop { position: 1; color: Qt.darker(root.accent, 1.15) }
        }
        Rectangle {   // brillo superior
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.height / 2; radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.10)
        }
        FluentIcon {
            visible: root.image === ""
            anchors.centerIn: parent
            name: root.glyph
            size: parent.width * 0.5
            stroke: 1.4
            color: "white"
        }
        Image {
            visible: root.image !== ""
            anchors.centerIn: parent
            source: root.image ? "image://icon/" + root.image : ""
            sourceSize: Qt.size(parent.width * 0.62, parent.width * 0.62)
        }
    }
    // Círculos decorativos
    Rectangle { x: root.width * 0.12; y: root.height * 0.20; width: 18; height: 18; radius: 9; color: Qt.alpha(root.accent, 0.55) }
    Rectangle { x: root.width * 0.80; y: root.height * 0.30; width: 12; height: 12; radius: 6; color: Qt.alpha(root.accent, 0.40) }
    Rectangle { x: root.width * 0.74; y: root.height * 0.78; width: 24; height: 24; radius: 12; color: Qt.alpha(root.accent, 0.30) }
    Rectangle { x: root.width * 0.18; y: root.height * 0.74; width: 8; height: 8; radius: 4; color: Qt.alpha(root.accent, 0.60) }
}
