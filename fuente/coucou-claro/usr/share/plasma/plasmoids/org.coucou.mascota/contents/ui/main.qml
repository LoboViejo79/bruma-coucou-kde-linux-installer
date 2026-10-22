import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.coucou.widgets as C

// Coucou: Mascota pixel. Un dinosaurio de pixeles: el café le da 10 de experiencia y la
// hamburguesa 25; cada 100 sube de nivel. Si pasan más de 8 horas sin comer, se duerme.
// Un clic en él: salta.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property int xp: Plasmoid.configuration.experiencia
    readonly property int nivel: Math.floor(xp / 100) + 1
    property real ahora: Date.now()
    readonly property real ultima: Number(Plasmoid.configuration.ultimaComida) || 0
    readonly property bool dormido: ultima > 0 && ahora - ultima > 8 * 3600 * 1000
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.ahora = Date.now() }

    function comer(cuanto) {
        var antes = nivel
        Plasmoid.configuration.experiencia = xp + cuanto
        Plasmoid.configuration.ultimaComida = String(Date.now())
        ahora = Date.now()
        salto.restart()
        if (nivel > antes) subio.restart()
    }

    // El dinosaurio (20 × 19) y la comida, en pixeles
    readonly property var dino: [
        "..........########..",
        ".........##.#######.",
        ".........##########.",
        ".........##########.",
        ".........#####......",
        ".........########...",
        "#.......#####.......",
        "#......#######......",
        "##....##########....",
        "###..##########.#...",
        "##############......",
        ".#############......",
        "..###########.......",
        "...#########........",
        "....#######.........",
        ".....###.##.........",
        ".....##...#.........",
        ".....#....#.........",
        ".....##...##........"
    ]
    readonly property var dinoDormido: [
        "....................",
        "....................",
        "..........########..",
        ".........#--#######.",
        ".........##########.",
        ".........##########.",
        ".........#####......",
        "#.......########....",
        "#......#####........",
        "##....##########....",
        "###..##########.....",
        "##############......",
        ".#############......",
        "..###########.......",
        "...#########........",
        "....#######.........",
        ".....###.##.........",
        "....####.###........",
        "...................."
    ]
    readonly property var cafe: [
        "...s..s.....",
        "..s..s......",
        "...s..s.....",
        "............",
        ".wwwwwwww...",
        ".wcccccww.w.",
        ".wcccccwwww.",
        ".wwwwwwww.w.",
        ".wwwwwwwww..",
        "..wwwwww....",
        "............"
    ]
    readonly property var hamburguesa: [
        "....bbbb....",
        "..bbbbbbbb..",
        ".bbybbbybbb.",
        ".bbbbbbbbbb.",
        "gggggggggggg",
        ".rrrrrrrrrr.",
        "mmmmmmmmmmmm",
        ".bbbbbbbbbb.",
        "..bbbbbbbb.."
    ]

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#141414", abajo: "#000000", acento: "#FFFFFF", manchas: [], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            // El nivel
            Rectangle {
                x: 14; y: 14
                width: nv.width + 16; height: 24; radius: 12
                color: Qt.rgba(1, 1, 1, 0.16)
                C.PixelTexto { id: nv; k: e.k; anchors.centerIn: parent; px: 1.8; text: root.nivel + " NVL"; color: t.colorTexto }
                SequentialAnimation on scale {
                    id: subio; running: false
                    NumberAnimation { to: 1.25; duration: 140; easing.type: Easing.OutBack } NumberAnimation { to: 1; duration: 220 }
                }
            }
            C.PixelTexto {
                visible: root.dormido
                k: e.k; x: 120; y: 30; px: 2
                text: "Z Z"; color: t.colorTexto2
                SequentialAnimation on y { loops: Animation.Infinite; running: root.dormido
                    NumberAnimation { to: 24; duration: 900 } NumberAnimation { to: 30; duration: 900 } }
            }
            C.PixelArte {
                id: dino
                k: e.k
                x: 40; y: 34
                px: 4.6
                filas: root.dormido ? root.dinoDormido : root.dino
                colores: ({ "#": t.colorTexto, "-": t.claro ? "#FFFFFF" : "#000000" })
                SequentialAnimation on y {
                    id: salto; running: false
                    NumberAnimation { to: 14; duration: 160; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 34; duration: 220; easing.type: Easing.InQuad }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: salto.restart() }
            }

            // La comida
            Repeater {
                model: [ { arte: "cafe", cuanto: 10, nombre: "Café" }, { arte: "hamburguesa", cuanto: 25, nombre: "Hamburguesa" } ]
                Rectangle {
                    id: plato
                    required property var modelData
                    required property int index
                    x: 14 + index * 74; y: 118; width: 68; height: 40; radius: 20
                    color: m.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.18)
                    scale: m.pressed ? 0.93 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    C.PixelArte {
                        k: e.k
                        anchors.centerIn: parent
                        px: 2.4
                        filas: root[plato.modelData.arte]
                        colores: ({ "w": "#9CA3F0", "c": "#5B4636", "s": "#D7D7E8", "b": "#E9A64B", "y": "#FCE7B0",
                                    "g": "#5DBB4F", "r": "#E0483E", "m": "#7A3F22" })
                    }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.comer(plato.modelData.cuanto) }
                }
            }
        }
    }
}
