import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.notification
import org.coucou.widgets as C

// Coucou: Temporizador. Un reloj de arena: la arena de arriba es el tiempo que queda.
//   clic: empezar / pausar        doble clic: volver a empezar
//   rueda del ratón (parado): más o menos tiempo (de a 10 s hasta 1 min, después de a 1 min)
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property int total: Plasmoid.configuration.segundos
    property real queda: total                 // segundos
    property bool corriendo: false
    property real fin: 0                       // ms (cuándo termina, mientras corre)
    readonly property real fraccion: total > 0 ? Math.max(0, Math.min(1, queda / total)) : 0

    function texto(s) {
        s = Math.ceil(s)
        if (s >= 3600) return Math.floor(s / 3600) + ":" + String(Math.floor(s % 3600 / 60)).padStart(2, "0") + " h"
        if (s >= 60) return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
        return s + " s"
    }
    function alternar() {
        if (corriendo) { corriendo = false; return }
        if (queda <= 0) queda = total
        fin = Date.now() + queda * 1000
        corriendo = true
    }
    function reiniciar() { corriendo = false; queda = total }
    function cambiar(d) {
        if (corriendo) return
        var paso = total < 60 || (total === 60 && d < 0) ? 10 : 60
        var n = Math.max(10, Math.min(24 * 3600, total + d * paso))
        Plasmoid.configuration.segundos = n
        queda = n
    }
    onTotalChanged: if (!corriendo) queda = total

    Timer {
        interval: 100; repeat: true; running: root.corriendo
        onTriggered: {
            root.queda = Math.max(0, (root.fin - Date.now()) / 1000)
            if (root.queda <= 0) {
                root.corriendo = false
                if (Plasmoid.configuration.avisar) aviso.sendEvent()
                listo.restart()
            }
        }
    }
    Notification {
        id: aviso
        componentName: "plasma_workspace"
        eventId: "notification"
        title: "Temporizador"
        text: "¡Se terminó el tiempo! (" + root.texto(root.total) + ")"
        iconName: "chronometer"
    }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#063D22", abajo: "#021A0E", acento: "#16E07A", manchas: ["#0B5C33", "#03130A"], texto: "#16E07A" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            // El reloj de arena
            C.Lienzo {
                id: reloj
                k: e.k
                x: 30; y: 22; width: 110; height: 126
                property real f: root.fraccion
                property color acento: t.colorAcento
                property color vidrio: Qt.alpha(t.colorAcento, t.claro ? 0.16 : 0.13)
                onFChanged: repintar()
                onAcentoChanged: repintar()
                onDibujar: g => {
                    var w = width, h = height, mid = h / 2, cuello = w * 0.09
                    // Una mitad del reloj: de arriba (y0) al cuello (y1)
                    function mitad(y0, y1) {
                        var arriba = y0 < y1
                        g.beginPath()
                        g.moveTo(w * 0.04, y0)
                        g.lineTo(w * 0.96, y0)
                        g.bezierCurveTo(w * 0.96, arriba ? y0 + h * 0.2 : y0 - h * 0.2, w / 2 + cuello, y1, w / 2 + cuello * 0.5, y1)
                        g.lineTo(w / 2 - cuello * 0.5, y1)
                        g.bezierCurveTo(w / 2 - cuello, y1, w * 0.04, arriba ? y0 + h * 0.2 : y0 - h * 0.2, w * 0.04, y0)
                        g.closePath()
                    }
                    // El vidrio
                    g.fillStyle = vidrio
                    mitad(0, mid); g.fill()
                    mitad(h, mid); g.fill()
                    // La arena de arriba: lo que queda (se vacía desde arriba)
                    g.save(); mitad(0, mid); g.clip()
                    g.fillStyle = acento
                    g.fillRect(0, mid * (1 - f), w, mid * f + 1)
                    g.restore()
                    // La de abajo: lo que pasó (se llena desde abajo)
                    g.save(); mitad(h, mid); g.clip()
                    g.fillStyle = Qt.alpha(acento, 0.35)
                    g.fillRect(0, h - mid * (1 - f), w, mid * (1 - f))
                    g.restore()
                    // El hilo de arena que cae
                    if (root.corriendo && f > 0) { g.fillStyle = acento; g.fillRect(w / 2 - 1.5, mid - 2, 3, mid * 0.5) }
                }
                Connections { target: root; function onCorriendoChanged() { reloj.repintar() } }
            }
            C.Texto {
                anchors.horizontalCenter: reloj.horizontalCenter
                y: 112
                text: root.texto(root.queda)
                color: t.colorAcento
                font.pixelSize: root.queda >= 3600 ? 18 : 24
                font.weight: Font.Bold
                                SequentialAnimation on opacity {
                    id: listo; running: false; loops: 3
                    NumberAnimation { to: 0.2; duration: 220 } NumberAnimation { to: 1; duration: 220 }
                }
            }
            C.Texto {
                anchors.horizontalCenter: reloj.horizontalCenter
                y: 150
                text: root.corriendo ? "" : (root.queda < root.total && root.queda > 0 ? "En pausa" : "Clic para empezar")
                color: Qt.alpha(t.colorAcento, 0.6)
                font.pixelSize: 9;             }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.alternar()
            onDoubleClicked: root.reiniciar()
            onWheel: wheel => root.cambiar(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
