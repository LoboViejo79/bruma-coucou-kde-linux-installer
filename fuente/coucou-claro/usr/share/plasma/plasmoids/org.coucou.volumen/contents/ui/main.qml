import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.volume
import org.coucou.widgets as C

// Coucou: Volumen. El del sonido de ahora (la salida predeterminada).
//   arrastrar el arco o la rueda del ratón: subir o bajar     botón izquierdo: silenciar
//   botón derecho: pasar a la otra salida (parlantes, auriculares…)
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var sink: PreferredDevice.sink
    readonly property real normal: 65536
    readonly property real maximo: Plasmoid.configuration.maximo / 100
    readonly property real nivel: sink ? sink.volume / normal : 0           // 1 = 100 %
    readonly property bool mudo: sink ? sink.muted : false
    function poner(v) {
        if (!sink) return
        v = Math.max(0, Math.min(maximo, v))
        sink.volume = Math.round(v * normal)
        if (sink.muted && v > 0) sink.muted = false
    }

    // Las salidas, para pasar de una a otra
    SinkModel { id: salidas }
    Instantiator { id: lista; model: salidas; delegate: QtObject { required property var model; readonly property var obj: model.PulseObject } }
    function siguienteSalida() {
        var n = lista.count
        if (n < 2) return
        var i = 0
        for (var j = 0; j < n; j++) if (lista.objectAt(j).obj === sink) i = j
        lista.objectAt((i + 1) % n).obj.default = true
        nombre.restart()
    }
    Timer { id: nombre; interval: 2200 }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#24465A", abajo: "#173040", acento: "#3FA8E0", manchas: ["#2E5A70", "#18364A"], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            C.Vidrio {
                k: e.k
                x: 14; y: 14; width: 30; height: 30; radius: 15
                icono: root.mudo ? "audio-volume-muted-symbolic" : "object-select-symbolic"
                tinta: root.mudo ? "#FFFFFF" : "#5FD38A"
                relleno: root.mudo ? "#E5484D" : Qt.rgba(1, 1, 1, 0.08)
                tamIcono: 15
                onClic: if (root.sink) root.sink.muted = !root.sink.muted
            }
            C.Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                width: 82; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                text: nombre.running && root.sink ? root.sink.description : "Volumen"
                color: t.colorTexto2; font.pixelSize: 12
            }
            C.Vidrio {
                k: e.k
                x: 126; y: 14; width: 30; height: 30; radius: 15
                icono: "view-refresh-symbolic"
                tinta: "#FFFFFF"
                relleno: t.colorAcento
                tamIcono: 15
                activo: lista.count > 1
                onClic: root.siguienteSalida()
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 48
                C.Texto {
                    id: num
                    text: Math.round(root.nivel * 100)
                    color: root.mudo ? t.colorTexto2 : t.colorTexto
                    font.pixelSize: 40; font.weight: Font.Bold
                }
                C.Texto {
                    anchors.baseline: num.baseline
                    text: "%"; color: t.colorTexto2
                    font.pixelSize: 20; font.weight: Font.DemiBold
                }
            }

            // El arco: de la izquierda a la derecha pasando por abajo (de 160° a 20°)
            C.Lienzo {
                id: arco
                k: e.k
                x: 0; y: 0; width: 170; height: 170
                readonly property real cx: 85
                readonly property real cy: 92
                readonly property real r: 60
                readonly property real v: Math.min(1, root.nivel / Math.max(1, root.maximo))
                property color acento: t.colorAcento
                property bool mudo: root.mudo
                onVChanged: repintar()
                onAcentoChanged: repintar()
                onMudoChanged: repintar()
                function ang(x) { return (160 - 140 * x) * Math.PI / 180 }
                onDibujar: g => {
                    g.lineCap = "round"
                    g.lineWidth = 12
                    g.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
                    g.beginPath(); g.arc(cx, cy, r, ang(0), ang(1), true); g.stroke()
                    g.strokeStyle = mudo ? Qt.rgba(1, 1, 1, 0.3) : acento
                    if (v > 0.002) { g.beginPath(); g.arc(cx, cy, r, ang(0), ang(v), true); g.stroke() }
                    // La perilla
                    var a = ang(v), px = cx + r * Math.cos(a), py = cy + r * Math.sin(a)
                    g.fillStyle = "#FFFFFF"
                    g.beginPath(); g.arc(px, py, 7, 0, 2 * Math.PI); g.fill()
                    g.fillStyle = mudo ? "#888888" : acento
                    g.beginPath(); g.arc(px, py, 3, 0, 2 * Math.PI); g.fill()
                }
            }
            MouseArea {
                x: 10; y: 70; width: 150; height: 96
                cursorShape: Qt.PointingHandCursor
                function mover(mx, my) {
                    var a = Math.atan2(my + y - arco.cy, mx + x - arco.cx) * 180 / Math.PI
                    if (a < -90) a += 360
                    var f = Math.max(0, Math.min(1, (160 - a) / 140))
                    root.poner(f * root.maximo)
                }
                onPressed: mouse => mover(mouse.x, mouse.y)
                onPositionChanged: mouse => { if (pressed) mover(mouse.x, mouse.y) }
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.poner(root.nivel + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
}
