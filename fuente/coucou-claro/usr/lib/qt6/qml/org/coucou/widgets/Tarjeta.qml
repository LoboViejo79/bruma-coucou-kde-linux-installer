import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// Coucou: el fondo de todos los widgets. Un degradé con dos manchas de color difuminadas, un poco de
// grano, un borde que agarra la luz arriba y una sombra suave; o una imagen difuminada.
//
//   Tarjeta {
//       estilo: Plasmoid.configuration.estilo        // "coucou", "original" o un color (ver Paletas)
//       original: { "arriba": "#..", "abajo": "#..", "acento": "#..", "manchas": ["#..", "#.."], "texto": "#fff" }
//       imagen: ""                                    // con imagen: va difuminada de fondo
//   }
//
// "coucou" sigue el énfasis y el modo claro/oscuro de Coucou (los colores de KDE). Lo de adentro va
// en `contenido` (un Item del tamaño de la tarjeta); colorTexto, colorTexto2, colorAcento y
// colorVidrio dicen con qué colores dibujarlo.
Item {
    id: t
    property string estilo: "coucou"
    property var original: ({})
    property string imagen: ""
    property real desenfoque: 1.0           // 0..1, de la imagen de fondo
    property real oscurecer: 0.35           // 0..1, velo sobre la imagen para que se lea el texto
    property bool sombra: true
    property bool grano: true
    property real radio: Math.min(width, height) * 0.14
    default property alias contenido: dentro.data

    readonly property var p: Paletas.resolver(estilo, original, Kirigami.Theme.highlightColor, Kirigami.Theme.backgroundColor)
    readonly property color colorTexto: p.texto
    readonly property color colorTexto2: Qt.alpha(p.texto, 0.62)
    readonly property color colorAcento: p.acento
    readonly property color colorVidrio: p.claro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color colorVidrioBorde: p.claro ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(1, 1, 1, 0.08)
    readonly property bool claro: p.claro

    // La sombra (fuera del recorte)
    RectangularShadow {
        visible: t.sombra
        anchors.fill: fondo
        radius: t.radio
        offset.y: Math.max(2, t.height * 0.025)
        blur: Math.max(10, t.height * 0.08)
        spread: -2
        color: Qt.rgba(0, 0, 0, 0.32)
    }

    Item {
        id: fondo
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mascara
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: t.p.arriba }
                GradientStop { position: 1; color: t.p.abajo }
            }
        }

        // Dos manchas de color difuminadas (el "mesh" de las tarjetas de la foto)
        Item {
            id: manchas
            anchors.fill: parent
            visible: t.imagen === "" && t.p.manchas.length > 0
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1.0 }
            Repeater {
                model: t.p.manchas
                Rectangle {
                    required property var modelData
                    required property int index
                    width: t.width * (index === 0 ? 0.95 : 0.8); height: width; radius: width / 2
                    x: index === 0 ? t.width * 0.45 : -t.width * 0.25
                    y: index === 0 ? -t.height * 0.45 : t.height * 0.45
                    color: modelData
                    opacity: 0.85
                }
            }
        }

        // Imagen de fondo difuminada, con un velo para que se lea lo de arriba
        Image {
            id: img
            anchors.fill: parent
            visible: t.imagen !== ""
            source: t.imagen
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 600
            layer.enabled: visible && t.desenfoque > 0
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: t.desenfoque; saturation: 0.15 }
        }
        Rectangle {
            anchors.fill: parent
            visible: t.imagen !== ""
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, t.oscurecer * 0.4) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, t.oscurecer) }
            }
        }

        Image {
            anchors.fill: parent
            visible: t.grano
            source: "grano.png"
            fillMode: Image.Tile
            opacity: t.p.claro ? 0.05 : 0.07
            smooth: false
        }
    }

    // El borde que agarra la luz: más claro arriba
    Rectangle {
        anchors.fill: parent
        radius: t.radio
        color: "transparent"
        border.width: 1
        border.color: t.p.claro ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.10)
    }

    Rectangle { id: mascara; anchors.fill: parent; radius: t.radio; visible: false; layer.enabled: true }

    Item { id: dentro; anchors.fill: parent }
}
