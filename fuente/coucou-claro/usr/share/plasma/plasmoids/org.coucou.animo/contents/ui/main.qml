import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.coucou.widgets as C

// Coucou: ¿Cómo estás hoy? Una tarjeta con una imagen (la tuya, o el fondo de Coucou) que te
// pregunta cómo estás. Un clic muestra cinco caritas; la elegida queda hasta el día siguiente.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    readonly property var caras: ["😄", "🙂", "😐", "😕", "😢"]
    readonly property var respuestas: ["…¡qué bueno!", "…me alegro", "…un día más", "…ánimo, ya pasa", "…mañana será mejor"]
    function hoy() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
    property bool eligiendo: false
    readonly property int eleccion: Plasmoid.configuration.dia === hoy() ? Plasmoid.configuration.eleccion : -1
    function elegir(i) {
        Plasmoid.configuration.eleccion = i
        Plasmoid.configuration.dia = hoy()
        eligiendo = false
    }
    // A medianoche vuelve a preguntar
    property string diaVisto: hoy()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: root.diaVisto = root.hoy() }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#7A5236", abajo: "#3A2418", acento: "#FFFFFF", manchas: ["#C99A6A", "#5A3A26"], texto: "#FFFFFF" })
        imagen: Plasmoid.configuration.imagen !== "" ? Plasmoid.configuration.imagen : "file:///usr/share/wallpapers/coucou/fondo.png"
        desenfoque: Plasmoid.configuration.imagen !== "" ? 0 : 0.35
        oscurecer: 0.5

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.eligiendo ? 34 : 70
                width: 150
                spacing: 2
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                C.Texto {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.eleccion >= 0 ? root.caras[root.eleccion] : Plasmoid.configuration.pregunta
                    color: "#FFFFFF"
                    font.pixelSize: root.eleccion >= 0 ? 44 : 22
                    font.weight: Font.Black
                    wrapMode: Text.WordWrap
                    lineHeight: 0.92
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
                }
                C.Texto {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.eleccion >= 0 ? root.respuestas[root.eleccion] : (root.eligiendo ? "" : "Toca para responder")
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.pixelSize: 15; font.weight: Font.Bold
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.3)
                }
            }

            // Las caritas para elegir
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 112
                spacing: 3
                opacity: root.eligiendo ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Repeater {
                    model: root.caras
                    Rectangle {
                        required property string modelData
                        required property int index
                        width: 29; height: 29; radius: 14.5
                        color: m.containsMouse ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.22)
                        scale: m.containsMouse ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 110 } }
                        C.Texto { anchors.centerIn: parent; text: modelData; font.pixelSize: 17 }
                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.elegir(index) }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.eligiendo = !root.eligiendo
        }
    }
}
