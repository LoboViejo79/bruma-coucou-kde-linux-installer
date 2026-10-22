import QtQuick
import org.kde.plasma.private.volume as Vol
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: Sonido. Por dónde sale (parlantes, auriculares…), el volumen de cada
// app que suena y el micrófono.
Item {
    id: v
    property var sis; property var tema
    signal volver()
    readonly property real altoDeseado: 600

    Vol.SinkModel { id: salidas }
    Vol.SourceModel { id: entradas }
    Vol.SinkInputModel { id: apps }

    Encabezado { id: enc; width: parent.width; icono: "audio-volume-high-symbolic"; tema: v.tema; titulo: "Sonido"; onVolver: v.volver() }
    Flickable {
        anchors { top: enc.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: col.implicitHeight
        clip: true
        Column {
            id: col
            width: parent.width
            spacing: 8
            W.Texto { text: "Salida"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater {
                model: salidas
                Fila {
                    required property var model
                    readonly property var o: model.PulseObject
                    width: col.width; tema: v.tema
                    icono: /headphone|headset|auricular/i.test(o.description + o.name) ? "audio-headphones-symbolic" : "audio-speakers-symbolic"
                    titulo: o.description
                    detalle: o.default ? "En uso · " + Math.round(o.volume / 655.36) + "%" : ""
                    marcada: o.default
                    onClic: o.default = true
                }
            }
            W.Texto { visible: apps.count > 0; topPadding: 8; text: "Apps"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater {
                model: apps
                Item {
                    required property var model
                    readonly property var o: model.PulseObject
                    width: col.width; height: 70
                    W.Texto { x: 4; text: (o.client && o.client.name) || o.name; color: v.tema.texto; font.pixelSize: 13; width: parent.width - 8; elide: Text.ElideRight }
                    Deslizador {
                        y: 24; width: parent.width; height: 40
                        tema: v.tema
                        icono: o.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                        valor: o.volume / 65536
                        apagado: o.muted
                        onMover: x => o.volume = Math.round(x * 65536)
                        onTocarIcono: o.muted = !o.muted
                    }
                }
            }
            W.Texto { topPadding: 8; text: "Micrófono"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater {
                model: entradas
                Fila {
                    required property var model
                    readonly property var o: model.PulseObject
                    width: col.width; tema: v.tema
                    icono: o.muted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"
                    titulo: o.description
                    detalle: o.default ? (o.muted ? "En uso · silenciado" : "En uso") : ""
                    marcada: o.default
                    accion: o.default ? (o.muted ? "Activar" : "Silenciar") : ""
                    onClic: o.default = true
                    onAccionar: o.muted = !o.muted
                }
            }
        }
    }
}
