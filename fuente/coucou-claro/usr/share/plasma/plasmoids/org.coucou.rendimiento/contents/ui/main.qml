import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import org.coucou.widgets as C

// Coucou: Rendimiento. El número grande es lo elegido en la configuración (el procesador, si no);
// abajo, cuatro barras: procesador, memoria, temperatura y batería (o gráficos, sin batería).
// Los datos son los del Monitor del sistema de KDE. Un clic lo abre.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1500 }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 3000 }
    Sensors.Sensor { id: temp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: 3000 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/all/usage"; updateRateLimit: 1500 }
    P5Support.DataSource { id: energia; engine: "powermanagement"; connectedSources: ["Battery", "AC Adapter"] }
    readonly property bool hayBateria: energia.data["Battery"] ? energia.data["Battery"]["Has Battery"] === true : false
    readonly property real bateria: hayBateria ? energia.data["Battery"]["Percent"] : 0
    readonly property bool cargando: energia.data["AC Adapter"] ? energia.data["AC Adapter"]["Plugged in"] === true : false

    function num(s) { return s && s.value !== undefined && !isNaN(s.value) ? s.value : 0 }
    // Lo que se muestra: [nombre, valor 0-100, texto]
    readonly property var datos: ({
        cpu: { titulo: "Procesador", corto: "CPU", v: num(cpu), texto: Math.round(num(cpu)) + "%" },
        ram: { titulo: "Memoria", corto: "RAM", v: num(ram), texto: Math.round(num(ram)) + "%" },
        temp: { titulo: "Temperatura", corto: "TEMP", v: Math.min(100, num(temp)), texto: Math.round(num(temp)) + "°" },
        bat: { titulo: cargando ? "Batería (cargando)" : "Batería", corto: "BAT", v: bateria, texto: Math.round(bateria) + "%" },
        gpu: { titulo: "Gráficos", corto: "GPU", v: num(gpu), texto: Math.round(num(gpu)) + "%" }
    })
    readonly property string principal: datos[Plasmoid.configuration.principal] ? Plasmoid.configuration.principal : "cpu"
    readonly property var barras: ["cpu", "ram", "temp", hayBateria ? "bat" : "gpu"]

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 170; Layout.preferredHeight: 170
        Layout.minimumWidth: 90; Layout.minimumHeight: 90
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#6B2BEA", abajo: "#8E2DE2", acento: "#FFFFFF", manchas: ["#4FD8F5", "#C14FE8"], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 170; altoBase: 170

            Row {
                x: 16; y: 15
                spacing: 7
                Rectangle {
                    width: 18; height: 18; radius: 5
                    color: Qt.rgba(1, 1, 1, 0.85)
                    C.Texto { anchors.centerIn: parent; text: "⚡"; font.pixelSize: 11; color: t.p.arriba }
                }
                C.Texto { text: "Rendimiento"; color: t.colorTexto; font.pixelSize: 14; font.weight: Font.Medium }
            }
            C.Texto { x: 16; y: 48; text: root.datos[root.principal].titulo + ":"; color: t.colorTexto2; font.pixelSize: 14 }
            C.Texto {
                x: 14; y: 62; width: 142
                text: root.datos[root.principal].texto
                color: t.colorTexto
                font.pixelSize: 46; font.weight: Font.Bold
                fontSizeMode: Text.HorizontalFit; minimumPixelSize: 16
            }
            // Las cuatro barras
            Row {
                x: 16; y: 124
                spacing: 6
                Repeater {
                    model: root.barras
                    Column {
                        required property string modelData
                        readonly property var d: root.datos[modelData]
                        spacing: 4
                        C.Texto { text: d.corto; color: t.colorTexto; font.pixelSize: 10; opacity: modelData === root.principal ? 1 : 0.65 }
                        Rectangle {
                            width: 30; height: 6; radius: 3
                            color: Qt.rgba(1, 1, 1, 0.25)
                            Rectangle {
                                height: parent.height; radius: 3
                                color: d.v >= 90 ? "#FF6B6B" : (t.claro ? t.colorAcento : "#FFFFFF")
                                width: parent.width * Math.max(0, Math.min(1, d.v / 100))
                                Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally("applications:org.kde.plasma-systemmonitor.desktop")
        }
    }
}
