import QtQuick
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: agregar un control (los bloques que no están en el panel)
Item {
    id: v
    property var tema; property var sis
    property var tipos: ({})
    property var presentes: []
    signal volver()
    signal elegir(string tipo)
    readonly property var faltan: Object.keys(tipos).filter(function (t) { return presentes.indexOf(t) < 0 })
    readonly property real altoDeseado: 120 + Math.max(1, faltan.length) * 66

    Encabezado { id: enc; width: parent.width; tema: v.tema; titulo: "Agregar un control"; onVolver: v.volver() }
    W.Texto {
        visible: v.faltan.length === 0
        anchors { top: enc.bottom; topMargin: 24; horizontalCenter: parent.horizontalCenter }
        text: "Ya están todos en el panel"; color: v.tema.texto2; font.pixelSize: 14
    }
    Flickable {
        anchors { top: enc.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: contenido.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: contenido
            width: parent.width
            spacing: 8
            Repeater {
                model: v.faltan
                Fila {
                    required property string modelData
                    width: parent.width; tema: v.tema
                    icono: v.tipos[modelData].icono + "-symbolic"
                    titulo: v.tipos[modelData].nombre
                    accion: "Agregar"
                    onAccionar: v.elegir(modelData)
                    onClic: v.elegir(modelData)
                }
            }
        }
    }
}
