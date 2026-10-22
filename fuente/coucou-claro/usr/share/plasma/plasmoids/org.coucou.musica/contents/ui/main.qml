import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.coucou.widgets as C

// Coucou: Música. Lo que está sonando en cualquier reproductor (Spotify, Firefox, VLC…): sus
// carátulas arriba (un clic elige el reproductor), artista, canción, el avance y los controles.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Mpris.Mpris2Model { id: mpris }
    readonly property var p: mpris.currentPlayer
    readonly property bool hay: p !== null && p !== undefined
    readonly property bool sonando: hay && p.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real largo: hay ? p.length : 0          // microsegundos
    property real pos: hay ? p.position : 0

    // La posición del reproductor no avanza sola: se pide cada segundo mientras suena
    Timer {
        interval: 1000; repeat: true; running: root.sonando
        triggeredOnStart: true
        onTriggered: { root.p.updatePosition(); root.pos = root.p.position }
    }
    Connections { target: root.hay ? root.p : null; function onPositionChanged() { root.pos = root.p.position } }

    function hora(us) {
        var s = Math.max(0, Math.floor(us / 1e6))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 360; Layout.preferredHeight: 170
        Layout.minimumWidth: 180; Layout.minimumHeight: 85
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#2C2C30", abajo: "#141416", acento: "#FFFFFF", manchas: ["#4A4A52", "#1C1C20"], texto: "#FFFFFF" })
        imagen: Plasmoid.configuration.caratulaDeFondo && root.hay ? (root.p.artUrl || "") : ""
        oscurecer: 0.6

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 360; altoBase: 170

            // Panel de vidrio: carátulas, canción y avance
            Rectangle {
                id: panel
                x: 14; y: 14; width: 222; height: 142
                radius: 22
                color: t.colorVidrio
                border.width: 1; border.color: t.colorVidrioBorde

                // Las carátulas de los reproductores abiertos (la del que manda, primero)
                Row {
                    id: tapas
                    x: 12; y: 12
                    spacing: 8
                    clip: true
                    width: parent.width - 12
                    Repeater {
                        model: mpris
                        delegate: Rectangle {
                            id: tapa
                            required property var model
                            required property int index
                            visible: !model.isMultiplexer
                            width: 54; height: 54; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.08)
                            clip: true
                            readonly property bool actual: mpris.currentIndex === index
                            opacity: actual ? 1 : 0.5
                            Image {
                                anchors.fill: parent
                                source: tapa.model.container ? (tapa.model.container.artUrl || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(108, 108)
                                visible: status === Image.Ready
                            }
                            C.Texto {
                                anchors.centerIn: parent
                                visible: !(tapa.model.container && tapa.model.container.artUrl)
                                text: "♪"; color: t.colorTexto2; font.pixelSize: 22
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mpris.currentIndex = tapa.index }
                        }
                    }
                    // Nada sonando
                    Rectangle {
                        visible: !root.hay
                        width: 54; height: 54; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.08)
                        C.Texto { anchors.centerIn: parent; text: "♪"; color: t.colorTexto2; font.pixelSize: 22 }
                    }
                }

                C.Texto {
                    id: artista
                    x: 14; y: 76; width: parent.width - 60
                    text: root.hay ? (root.p.artist || root.p.identity) : "Nada sonando"
                    color: t.colorTexto2; font.pixelSize: 11; font.family: "Inter"
                    elide: Text.ElideRight
                }
                C.Texto {
                    x: 14; y: 91; width: parent.width - 60
                    text: root.hay ? (root.p.track || "—") : "Abre música para verla aquí"
                    color: t.colorTexto; font.pixelSize: 15; font.weight: Font.DemiBold; font.family: "Inter"
                    elide: Text.ElideRight
                }
                // El reproductor (abre su ventana)
                C.Vidrio { k: e.k;
                    x: parent.width - 42; y: 78; width: 30; height: 30
                    radius: 15
                    icono: root.hay ? (root.p.iconName || "audio-headphones") : "audio-headphones"
                    tamIcono: 16
                    tinta: t.colorTexto
                    relleno: Qt.rgba(1, 1, 1, 0.18)
                    activo: root.hay && root.p.canRaise
                    onClic: root.p.Raise()
                }

                // Avance
                Rectangle {
                    id: barra
                    x: 14; y: 116; width: parent.width - 28; height: 4; radius: 2
                    color: Qt.alpha(t.colorTexto, 0.18)
                    Rectangle {
                        width: root.largo > 0 ? parent.width * Math.min(1, root.pos / root.largo) : 0
                        height: parent.height; radius: 2; color: t.colorTexto
                        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        enabled: root.hay && root.p.canSeek && root.largo > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => {
                            var destino = root.largo * Math.max(0, Math.min(1, (mouse.x - 6) / barra.width))
                            root.p.Seek(destino - root.pos)
                            root.pos = destino
                        }
                    }
                }
                C.Texto { x: 14; y: 124; text: root.hora(root.pos); color: t.colorTexto2; font.pixelSize: 10; font.family: "Inter" }
                C.Texto { x: parent.width - 14 - width; y: 124; text: root.hora(root.largo); color: t.colorTexto2; font.pixelSize: 10; font.family: "Inter" }
            }

            // Controles: abrir, reproducir/pausa, anterior, siguiente
            Grid {
                x: 246; y: 14
                columns: 2; spacing: 8
                C.Vidrio { k: e.k
                           width: 46; height: 67; icono: "list-add-symbolic"; tinta: t.colorTexto; relleno: t.colorVidrio
                           activo: root.hay && root.p.canRaise; onClic: root.p.Raise() }
                C.Vidrio { k: e.k
                           width: 46; height: 67; icono: root.sonando ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                           tinta: t.colorTexto; relleno: t.colorVidrio; activo: root.hay; onClic: root.p.PlayPause() }
                C.Vidrio { k: e.k
                           width: 46; height: 67; icono: "media-skip-backward-symbolic"; tinta: t.colorTexto; relleno: t.colorVidrio
                           activo: root.hay && root.p.canGoPrevious; onClic: root.p.Previous() }
                C.Vidrio { k: e.k
                           width: 46; height: 67; icono: "media-skip-forward-symbolic"; tinta: t.colorTexto; relleno: t.colorVidrio
                           activo: root.hay && root.p.canGoNext; onClic: root.p.Next() }
            }
        }
    }
}
