import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.coucou.widgets as C

// Coucou: Sí o No. Una ruleta que elige por ti entre las opciones (Sí, No… las que quieras).
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var opciones: {
        var o = Plasmoid.configuration.opciones.split(",").map(function (s) { return s.trim() }).filter(function (s) { return s !== "" })
        return o.length ? o : ["Sí", "No"]
    }
    property real giro: 0                      // posición del rodillo, en filas (puede tener decimales)
    readonly property int n: opciones.length
    function opcion(i) { return opciones[((Math.round(i) % n) + n) % n] }
    function girar() {
        if (anim.running) return
        var vueltas = 3 + Math.floor(Math.random() * 3)
        var destino = Math.round(giro) + vueltas * n + Math.floor(Math.random() * n)
        anim.from = giro; anim.to = destino
        anim.duration = 1100 + vueltas * 120
        anim.start()
    }
    NumberAnimation { id: anim; target: root; property: "giro"; easing.type: Easing.OutCubic }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#E53935", abajo: "#A61B1B", acento: "#FFFFFF", manchas: ["#FF6B5B", "#8E1414"], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            // El rodillo: la opción elegida grande, la de arriba y la de abajo asomando
            Rectangle {
                id: ventana
                x: 14; y: 14; width: 142; height: 96
                radius: 16
                color: t.claro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.13)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                readonly property real fila: 46
                Repeater {
                    model: 5
                    C.Texto {
                        required property int index
                        readonly property real i: Math.floor(root.giro) + index - 2
                        readonly property real d: i - root.giro            // distancia al centro, en filas
                        width: ventana.width
                        horizontalAlignment: Text.AlignHCenter
                        y: ventana.height / 2 - height / 2 + d * ventana.fila
                        text: root.opcion(i)
                        color: t.colorTexto
                        opacity: Math.max(0, 1 - Math.abs(d) * 0.72)
                        scale: 1 - Math.min(0.35, Math.abs(d) * 0.25)
                        font.pixelSize: 40
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                }
            }

            // Girar
            Rectangle {
                id: boton
                x: 14; y: 122; width: 142; height: 34
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0; color: t.claro ? t.colorAcento : "#FFFFFF" }
                    GradientStop { position: 1; color: t.claro ? Qt.darker(t.colorAcento, 1.1) : "#ECE9EE" }
                }
                scale: m.pressed ? 0.96 : 1
                Behavior on scale { NumberAnimation { duration: 100 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    C.Texto {
                        text: "↻"
                        color: t.claro ? "#FFFFFF" : t.p.arriba
                        font.pixelSize: 17; font.weight: Font.Bold
                        rotation: anim.running ? 360 * (root.giro % 1) : 0
                    }
                    C.Texto { text: "Girar"; color: t.claro ? "#FFFFFF" : t.p.arriba; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                MouseArea { id: m; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.girar() }
            }
        }
    }
}
