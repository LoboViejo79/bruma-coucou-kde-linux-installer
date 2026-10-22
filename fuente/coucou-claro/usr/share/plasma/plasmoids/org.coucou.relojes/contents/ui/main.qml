import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.coucou.widgets as C

// Coucou: Relojes del mundo. La hora en tres lugares, cada una sobre los colores de la bandera
// de ese país (difuminados) y con el nombre de quién está ahí.
PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    // "Max|Europe/Kyiv|🧑,Eva|America/New_York|👩,Yuki|Asia/Tokyo|👧"
    readonly property var lugares: Plasmoid.configuration.lugares.split(",").map(function (x) {
        var p = x.split("|")
        return { nombre: (p[0] || "").trim(), zona: (p[1] || "").trim(), cara: (p[2] || "").trim() }
    }).filter(function (l) { return l.zona !== "" }).slice(0, 4)

    // La hora de cada zona sale del motor "time" de Plasma (sabe de horarios de verano)
    P5Support.DataSource {
        id: horas
        engine: "time"
        connectedSources: root.lugares.map(function (l) { return l.zona })
        interval: 30000
        intervalAlignment: P5Support.Types.AlignToMinute
    }
    function hora(zona) {
        var d = horas.data[zona]
        if (!d || d["Offset"] === undefined) return null
        var ahora = new Date()
        return new Date(ahora.getTime() + ahora.getTimezoneOffset() * 60000 + d["Offset"] * 1000)
    }

    // Colores de bandera por zona (franjas; "v" = verticales, "c" = círculo al centro)
    readonly property var banderas: ({
        "Europe/Kyiv": ["#0057B7", "#FFD700"], "Europe/Kiev": ["#0057B7", "#FFD700"],
        "America/New_York": ["#B22234", "#FFFFFF", "#3C3B6E"], "America/Chicago": ["#B22234", "#FFFFFF", "#3C3B6E"],
        "America/Denver": ["#B22234", "#FFFFFF", "#3C3B6E"], "America/Los_Angeles": ["#B22234", "#FFFFFF", "#3C3B6E"],
        "Asia/Tokyo": ["c", "#FFFFFF", "#BC002D"], "Asia/Seoul": ["c", "#FFFFFF", "#CD2E3A"],
        "America/Argentina/Buenos_Aires": ["#74ACDF", "#FFFFFF", "#74ACDF"], "America/Buenos_Aires": ["#74ACDF", "#FFFFFF", "#74ACDF"],
        "America/Argentina/Cordoba": ["#74ACDF", "#FFFFFF", "#74ACDF"], "America/Montevideo": ["#0038A8", "#FFFFFF", "#0038A8"],
        "America/Santiago": ["#FFFFFF", "#D52B1E"], "America/Lima": ["v", "#D91023", "#FFFFFF", "#D91023"],
        "America/Bogota": ["#FCD116", "#003893", "#CE1126"], "America/Caracas": ["#FFCC00", "#00247D", "#CF142B"],
        "America/Mexico_City": ["v", "#006847", "#FFFFFF", "#CE1126"], "America/Sao_Paulo": ["#009C3B", "#FFDF00", "#009C3B"],
        "Europe/Madrid": ["#AA151B", "#F1BF00", "#AA151B"], "Europe/Paris": ["v", "#0055A4", "#FFFFFF", "#EF4135"],
        "Europe/Rome": ["v", "#009246", "#FFFFFF", "#CE2B37"], "Europe/Berlin": ["#000000", "#DD0000", "#FFCE00"],
        "Europe/London": ["#012169", "#FFFFFF", "#C8102E"], "Europe/Lisbon": ["v", "#006600", "#FF0000"],
        "Europe/Moscow": ["#FFFFFF", "#0039A6", "#D52B1E"], "Asia/Shanghai": ["#DE2910", "#FFDE00", "#DE2910"],
        "Asia/Kolkata": ["#FF9933", "#FFFFFF", "#138808"], "Australia/Sydney": ["#012169", "#FFFFFF", "#E4002B"]
    })

    fullRepresentation: C.Tarjeta {
        id: t
        Layout.preferredWidth: 360; Layout.preferredHeight: 170
        Layout.minimumWidth: 180; Layout.minimumHeight: 85
        estilo: Plasmoid.configuration.estilo
        original: ({ arriba: "#26262B", abajo: "#121215", acento: "#FFFFFF", manchas: ["#33333B", "#18181C"], texto: "#FFFFFF" })

        C.Escala {
            id: e
            anchors.fill: parent
            anchoBase: 360; altoBase: 170

            Row {
                anchors.centerIn: parent
                spacing: 14
                Repeater {
                    model: root.lugares
                    Column {
                        id: col
                        required property var modelData
                        readonly property var h: root.hora(modelData.zona)
                        readonly property var bandera: root.banderas[modelData.zona] || []
                        spacing: 8
                        // El reloj: la bandera difuminada, las marcas de las horas y la hora
                        Item {
                            width: 100; height: 100
                            Item {
                                id: fondoBandera
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    blurEnabled: true; blurMax: 32; blur: 0.8
                                    autoPaddingEnabled: false      // si no, el círculo de la máscara se estira al margen del difuminado
                                    brightness: -0.38; saturation: -0.1
                                    maskEnabled: true; maskSource: redondo
                                    maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
                                }
                                readonly property bool vertical: col.bandera[0] === "v"
                                readonly property bool circulo: col.bandera[0] === "c"
                                readonly property var franjas: col.bandera.filter(function (c) { return c !== "v" && c !== "c" })
                                Rectangle { anchors.fill: parent; color: col.bandera.length ? fondoBandera.franjas[0] : t.colorAcento }
                                Repeater {
                                    model: fondoBandera.circulo ? 0 : fondoBandera.franjas.length
                                    Rectangle {
                                        required property int index
                                        color: fondoBandera.franjas[index]
                                        x: fondoBandera.vertical ? index * 100 / fondoBandera.franjas.length : 0
                                        y: fondoBandera.vertical ? 0 : index * 100 / fondoBandera.franjas.length
                                        width: fondoBandera.vertical ? 100 / fondoBandera.franjas.length + 1 : 100
                                        height: fondoBandera.vertical ? 100 : 100 / fondoBandera.franjas.length + 1
                                    }
                                }
                                Rectangle { visible: fondoBandera.circulo; anchors.centerIn: parent; width: 44; height: 44; radius: 22; color: fondoBandera.franjas[1] || "#FFFFFF" }
                            }
                            Rectangle { id: redondo; anchors.fill: parent; radius: 50; visible: false; layer.enabled: true }
                            Rectangle { anchors.fill: parent; radius: 50; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.08) }
                            // Las marcas de las horas
                            Repeater {
                                model: 12
                                Rectangle {
                                    required property int index
                                    readonly property real a: index * Math.PI / 6
                                    readonly property bool esta: col.h && (col.h.getHours() % 12) === index
                                    width: esta ? 4 : 2.5; height: width; radius: width / 2
                                    x: 50 + 43 * Math.sin(a) - width / 2
                                    y: 50 - 43 * Math.cos(a) - height / 2
                                    color: Qt.rgba(1, 1, 1, esta ? 0.95 : 0.35)
                                }
                            }
                            Row {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 2
                                spacing: 3
                                Repeater {
                                    model: 2
                                    Column {
                                        required property int index
                                        spacing: 2
                                        Rectangle {
                                            width: 32; height: 26; radius: 6
                                            color: Qt.rgba(1, 1, 1, index === 0 ? 0.16 : 0.10)
                                            C.Texto {
                                                anchors.centerIn: parent
                                                text: col.h ? String(index === 0 ? col.h.getHours() : col.h.getMinutes()).padStart(2, "0") : "--"
                                                color: index === 0 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.75)
                                                font.pixelSize: 17; font.weight: Font.Medium
                                            }
                                        }
                                        C.Texto {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: index === 0 ? "HR" : "MIN"
                                            color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 7
                                        }
                                    }
                                }
                            }
                        }
                        // El nombre, con su carita
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: nombreFila.implicitWidth + 16; height: 24; radius: 12
                            color: t.colorVidrio
                            Row {
                                id: nombreFila
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    visible: col.modelData.cara !== ""
                                    width: 18; height: 18; radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                    C.Texto { anchors.centerIn: parent; text: col.modelData.cara; font.pixelSize: 11 }
                                }
                                C.Texto {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: col.modelData.nombre || col.modelData.zona.split("/").pop().replace(/_/g, " ")
                                    color: t.colorTexto; font.pixelSize: 12; font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
