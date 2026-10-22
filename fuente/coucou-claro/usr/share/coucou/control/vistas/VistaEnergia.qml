import QtQuick
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: Energía. La batería y el perfil (ahorro, equilibrado, rendimiento).
Item {
    id: v
    property var sis; property var tema
    signal volver()
    readonly property real altoDeseado: 470
    readonly property var info: ({
        "power-saver": { icono: "power-profile-power-saver-symbolic", detalle: "Dura más la batería; va un poco más lento" },
        "balanced": { icono: "power-profile-balanced-symbolic", detalle: "Lo normal" },
        "performance": { icono: "power-profile-performance-symbolic", detalle: "Lo más rápido; gasta más y calienta más" }
    })

    Encabezado { id: enc; width: parent.width; icono: "power-profile-balanced-symbolic"; tema: v.tema; titulo: "Energía"; onVolver: v.volver() }
    Flickable {
        anchors { top: enc.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: contenido.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: contenido
            width: parent.width
            spacing: 8
            // La batería
            Rectangle {
                visible: v.sis.hayBateria
                width: parent.width; height: 84; radius: 22
                color: v.tema.vidrio
                W.Texto { x: 18; y: 12; text: v.sis.bateria + "%"; color: v.tema.texto; font.pixelSize: 30; font.weight: Font.Bold }
                W.Texto { x: 18; y: 52; text: v.sis.cargando ? "Cargando" : "Con batería"; color: v.tema.texto2; font.pixelSize: 12 }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    width: parent.width * 0.45; height: 14; radius: 7; color: v.tema.vidrioFuerte
                    Rectangle { width: parent.width * v.sis.bateria / 100; height: parent.height; radius: 7
                                color: v.sis.bateria <= 15 && !v.sis.cargando ? "#E5484D" : v.tema.acento }
                }
            }
            W.Texto { topPadding: 6; text: "Perfil de energía"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater {
                model: v.sis.perfiles.profiles || []
                Fila {
                    required property string modelData
                    width: parent.width; tema: v.tema
                    icono: (v.info[modelData] || {}).icono || "speedometer-symbolic"
                    titulo: v.sis.nombresPerfil[modelData] || modelData
                    detalle: (v.info[modelData] || {}).detalle || ""
                    marcada: v.sis.perfil === modelData
                    onClic: v.sis.perfiles.setProfile(modelData)
                }
            }
            Fila {
                width: parent.width; tema: v.tema
                icono: "configure-symbolic"; titulo: "Más opciones de energía"; detalle: "Suspender, apagar la pantalla, brillo…"
                onClic: { v.sis.abrir("systemsettings", ["kcm_powerdevilprofilesconfig"]); Qt.quit() }
            }
        }
    }
}
