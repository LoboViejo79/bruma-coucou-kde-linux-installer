import QtQuick
import org.coucou.widgets as W
import ".."

// Vista del Centro de control: Modo juego. El interruptor lo enciende o apaga; debajo, qué pausa
// (lo guarda /usr/lib/coucou/modo-juego en ~/.config/coucou/modo-juego.conf).
Item {
    id: v
    property var sis; property var tema
    signal volver()
    readonly property real altoDeseado: 700
    // clave, nombre, detalle, ícono (las claves son las de modo-juego). La barra, el escritorio y
    // tus apps no se tocan: solo lo de fondo, y al salir vuelve todo.
    readonly property var cierra: [
        ["voz", "Los avisos por voz", "", "audio-speakers-symbolic"],
        ["avisos", "Avisos de actualizaciones y copias", "Revisar actualizaciones, instantáneas", "update-none-symbolic"],
        ["estadisticas", "Las estadísticas del sistema", "Las que usan los widgets de rendimiento", "office-chart-line-symbolic"],
        ["indexador", "El indexador de archivos", "Baloo, si está encendido", "edit-find-symbolic"],
        ["telefono", "La conexión con el teléfono", "KDE Connect: avisos y archivos del celular", "smartphone-symbolic"],
        ["portapapeles", "El historial del portapapeles", "Copiar y pegar sigue andando; no se guarda el historial", "edit-paste-symbolic"],
        ["accesibilidad", "Las ayudas de accesibilidad", "Teclas especiales y avisos del teclado (kaccess)", "preferences-desktop-accessibility-symbolic"]
    ]
    readonly property var ajusta: [
        ["limpiar", "Limpiar la memoria", "La caché y las vistas previas que quedaron abiertas sin uso", "edit-clear-all-symbolic"],
        ["comprimir", "Comprimir lo de segundo plano", "La barra y el escritorio pasan a la memoria comprimida: mucha menos RAM (tardan un instante la primera vez)", "memory-symbolic"],
        ["rendimiento", "Procesador y video al máximo", "Perfil Rendimiento y la tarjeta de video a toda velocidad; al salir, como estaban", "power-profile-performance-symbolic"],
        ["nomolestar", "No molestar", "Sin avisos mientras juegas", "notifications-disabled-symbolic"],
        ["pantalla", "Que la pantalla no se apague", "Para jugar con el mando sin tocar el teclado", "video-display-symbolic"]
    ]
    Component.onCompleted: sis.leerJuego()

    component Opcion: Fila {
        property var o
        width: parent.width; tema: v.tema
        icono: o[3]; titulo: o[1]; detalle: o[2]
        marcada: v.sis.juego.opciones[o[0]] !== false
        onClic: v.sis.opcionJuego(o[0], !marcada)
    }

    Encabezado {
        id: enc; width: parent.width; tema: v.tema
        icono: "applications-games-symbolic"; titulo: "Modo juego"
        conInterruptor: true; encendido: v.sis.modoJuego
        onAlternar: v.sis.alternarJuego()
        onVolver: v.volver()
    }
    Flickable {
        anchors { top: enc.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: contenido.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: contenido
            width: parent.width
            spacing: 8
            Rectangle {
                width: parent.width; height: 84; radius: 22
                color: v.tema.vidrio
                W.Texto { x: 18; y: 12; text: v.sis.juego.libre + " MB"; color: v.tema.texto; font.pixelSize: 30; font.weight: Font.Bold }
                W.Texto {
                    x: 18; y: 52; width: parent.width - 36; elide: Text.ElideRight
                    text: v.sis.modoJuego ? "de RAM libre · el modo juego liberó " + v.sis.juego.liberado + " MB"
                                          : "de RAM libre ahora · la barra y tus apps no se tocan"
                    color: v.tema.texto2; font.pixelSize: 12
                }
            }
            // Activo: qué dejó de andar, para que se sepa que es por el modo juego
            Rectangle {
                visible: v.sis.modoJuego && !!v.sis.juego.aviso
                width: parent.width; height: avisoJuego.implicitHeight + 24; radius: 18
                color: Qt.alpha(v.tema.acento, 0.16)
                border.color: Qt.alpha(v.tema.acento, 0.45)
                W.Texto {
                    id: avisoJuego
                    x: 16; y: 12; width: parent.width - 32
                    wrapMode: Text.WordWrap
                    text: v.sis.juego.aviso || ""
                    color: v.tema.texto; font.pixelSize: 12
                }
            }
            W.Texto { topPadding: 6; text: "Qué se pausa mientras juegas"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater { model: v.cierra; Opcion { required property var modelData; o: modelData } }
            W.Texto { topPadding: 6; text: "Qué hace"; color: v.tema.texto2; font.pixelSize: 12; font.weight: Font.DemiBold }
            Repeater { model: v.ajusta; Opcion { required property var modelData; o: modelData } }
            W.Texto {
                width: parent.width; wrapMode: Text.WordWrap; topPadding: 4
                text: (v.sis.modoJuego ? "Lo que cambies aquí vale la próxima vez. " : "")
                      + "Al salir del modo juego todo vuelve a como estaba. Es el mismo modo juego que el de la ventana de Juegos de la barra."
                color: v.tema.texto2; font.pixelSize: 12
            }
        }
    }
}
