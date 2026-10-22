import QtQuick
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: ajustes del panel (ancho, de qué lado, color, volver a lo de fábrica)
Item {
    id: v
    property var tema; property var sis
    property var ajustes
    signal volver()
    signal restablecer()
    readonly property real altoDeseado: 600

    component Opciones: Column {
        id: op
        property string titulo
        property var opciones: []           // [[valor, nombre]]
        property string valor
        signal elegido(string v)
        width: parent.width
        spacing: 6
        W.Texto { text: op.titulo; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
        Flow {
            width: parent.width; spacing: 6
            Repeater {
                model: op.opciones
                Rectangle {
                    required property var modelData
                    readonly property bool sel: op.valor === modelData[0]
                    width: tx.implicitWidth + 30; height: 36; radius: 18
                    color: sel ? v.tema.acento : (m.containsMouse ? v.tema.vidrioFuerte : v.tema.vidrio)
                    W.Texto { id: tx; anchors.centerIn: parent; text: modelData[1]; color: parent.sel ? v.tema.sobreAcento : v.tema.texto; font.pixelSize: 13 }
                    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: op.elegido(modelData[0]) }
                }
            }
        }
    }

    Encabezado { id: enc; width: parent.width; tema: v.tema; titulo: "Ajustes del panel"; onVolver: v.volver() }
    Flickable {
        anchors { top: enc.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: contenido.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: contenido
            width: parent.width
            spacing: 18
            Opciones { titulo: "Ancho del panel"; valor: v.ajustes.anchoPanel
                       opciones: [["estrecho", "Estrecho · 4 columnas"], ["normal", "Normal · 6 columnas"], ["ancho", "Ancho · 8 columnas"]]
                       onElegido: x => v.ajustes.anchoPanel = x }
            Opciones { titulo: "Lado de la pantalla"; valor: v.ajustes.lado
                       opciones: [["izquierda", "Izquierda"], ["derecha", "Derecha"]]
                       onElegido: x => v.ajustes.lado = x }
            Opciones { titulo: "Color"; valor: v.ajustes.estilo
                       opciones: [["coucou", "Coucou"], ["oscuro", "Oscuro"], ["claro", "Claro"], ["violeta", "Violeta"], ["azul", "Azul"], ["petroleo", "Petróleo"], ["rosa", "Rosa"]]
                       onElegido: x => v.ajustes.estilo = x }
            Fila {
                width: parent.width; tema: v.tema
                icono: "view-refresh-symbolic"; titulo: "Volver al panel de fábrica"; detalle: "Los bloques, su orden y sus tamaños de siempre"
                accion: "Restablecer"
                onAccionar: v.restablecer()
            }
            W.Texto {
                width: parent.width; wrapMode: Text.WordWrap
                text: "Se abre con Meta + C o desde el menú (Centro de control)."
                color: v.tema.texto2; font.pixelSize: 12
            }
        }
    }
}
