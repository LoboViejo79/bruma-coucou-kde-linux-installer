import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors
import org.coucou.widgets as C

// Coucou: Almacenamiento. Cuánto ocupa el disco (todos los discos montados): el porcentaje en la
// píldora, lo usado en grande y el total y lo libre abajo. Un clic abre el explorador.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Sensors.Sensor { id: usado; sensorId: "disk/all/used"; updateRateLimit: 30000 }
    Sensors.Sensor { id: total; sensorId: "disk/all/total"; updateRateLimit: 30000 }
    readonly property real u: usado.value || 0          // bytes
    readonly property real tot: Math.max(1, total.value || 0)
    readonly property real fraccion: Math.max(0, Math.min(1, u / tot))

    // 212345678901 → ["198", "GB"] (en GB; en TB desde 1000 GB)
    function tam(b) {
        var gb = b / 1073741824
        if (gb >= 1000) return [(gb / 1024).toLocaleString(Qt.locale(), "f", 1), "TB"]
        return [Math.round(gb).toLocaleString(Qt.locale(), "f", 0), "GB"]
    }

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#7B4FD8", abajo: "#6E8BE8", acento: "#6A3FC8", manchas: ["#E58ACB", "#3B4FCF"], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            // El porcentaje usado: una píldora blanca que crece sobre una pista de vidrio
            Rectangle {
                id: pista
                x: 16; y: 18; width: 138; height: 44
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.22)
                Rectangle {
                    width: Math.max(pista.height * 1.9, pista.width * root.fraccion)
                    height: parent.height; radius: height / 2
                    color: t.claro ? t.colorAcento : "#FFFFFF"
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    C.Texto {
                        anchors.centerIn: parent
                        text: Math.round(root.fraccion * 100) + "%"
                        color: t.claro ? "#FFFFFF" : (root.fraccion >= 0.9 ? "#E5484D" : (t.estilo === "original" ? "#6A3FC8" : t.colorAcento))
                        font.pixelSize: 21; font.weight: Font.Black; font.italic: true
                    }
                }
            }
            // Lo usado (se achica si no entra)
            Item {
                x: 16; y: 76; width: 138; height: 44
                Row {
                    scale: Math.min(1, parent.width / implicitWidth)
                    transformOrigin: Item.Left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    C.Texto {
                        id: grande
                        text: root.tam(root.u)[0]
                        color: t.colorTexto
                        font.pixelSize: 34; font.weight: Font.Black; font.italic: true
                    }
                    C.Texto {
                        anchors.baseline: grande.baseline
                        text: root.tam(root.u)[1] + " usados"
                        color: t.colorTexto2
                        font.pixelSize: 15; font.weight: Font.Black; font.italic: true
                    }
                }
            }
            C.Texto {
                x: 16; y: 124; width: 138
                text: "/ " + root.tam(root.tot).join(" ") + " · " + root.tam(root.tot - root.u).join(" ") + " libres"
                color: t.colorTexto2
                font.pixelSize: 12; font.weight: Font.Bold; font.italic: true
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 8
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("file:///")
        }
    }
}
