import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.coucou.widgets as W
import ".."

// Bloque del Centro de control: la música. Toma la forma que entra en su lugar:
//   chica (menos de 100 px de alto o 250 de ancho): la carátula, la canción y reproducir/pausa
//   compacta (hasta 140 de alto): canción, salida y anterior / reproducir / siguiente
//   ancha (mucho más ancha que alta): la carátula a la izquierda; canción, avance y controles al lado
//   grande: carátula de fondo, salida de audio, canción, avance y todos los controles
// La carátula no pasa de 220 px; el texto y los controles no crecen (se reparte el espacio).
Item {
    id: b
    property var sis; property var tema; property int ancho: 2; property int alto: 2
    signal abrir(string vista)
    readonly property var p: sis.player
    readonly property bool hay: !!p
    property real pos: p ? p.position : 0
    readonly property real largo: p ? p.length : 0
    Timer { interval: 1000; repeat: true; running: b.sis.sonando; triggeredOnStart: true; onTriggered: if (b.p) { b.p.updatePosition(); b.pos = b.p.position } }
    function hora(us) { var s = Math.max(0, Math.floor(us / 1e6)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    readonly property string arte: p ? (p.artUrl || "") : ""
    readonly property string forma: height < 100 || width < 250 ? "chica" : (height < 140 ? "compacta" : (width >= height * 2.2 ? "ancha" : "grande"))

    // Fondo: la carátula difuminada (o vidrio)
    Item {
        id: fondo
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: mascara; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Rectangle { anchors.fill: parent; color: b.tema.vidrio }
        Image {
            anchors.fill: parent
            visible: b.arte !== "" && b.forma !== "chica"
            source: b.arte
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 400
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 40; blur: 0.6; brightness: -0.25 }
        }
    }
    Rectangle { id: mascara; anchors.fill: parent; radius: Math.min(30, height / 2); visible: false; layer.enabled: true }

    component Control: Item {
        id: c
        property string icono
        property real tam: 26
        property bool activo: true
        property bool resaltado: false
        signal clic()
        width: tam + 16; height: tam + 16
        opacity: activo ? 1 : 0.35
        Kirigami.Icon {
            anchors.centerIn: parent
            width: c.tam; height: c.tam
            source: c.icono; isMask: true
            color: c.resaltado ? b.tema.acento : b.tema.texto
            scale: cm.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
        MouseArea { id: cm; anchors.fill: parent; enabled: c.activo; cursorShape: Qt.PointingHandCursor; onClicked: c.clic() }
    }
    // La salida de audio (abre Sonido)
    component Salida: Rectangle {
        width: Math.min(salidaTxt.implicitWidth + 38, b.width * 0.55); height: 30; radius: 15
        color: sm.containsMouse ? b.tema.vidrioFuerte : Qt.rgba(0, 0, 0, 0.18)
        Kirigami.Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; source: "audio-speakers-symbolic"; isMask: true; color: b.tema.texto }
        W.Texto { id: salidaTxt; x: 30; width: parent.width - 38; anchors.verticalCenter: parent.verticalCenter
                  text: b.sis.sink ? b.sis.sink.description : "Salida"; color: b.tema.texto; font.pixelSize: 12; elide: Text.ElideRight }
        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.abrir("sonido") }
    }

    // ── Grande ──
    Item {
        anchors.fill: parent; anchors.margins: 20
        visible: b.forma === "grande"
        Salida { id: sal; x: 0; y: 0 }
        W.Texto { anchors { right: parent.right; verticalCenter: sal.verticalCenter }
                  text: b.p ? b.p.identity : ""; color: b.tema.texto2; font.pixelSize: 12 }
        Column {
            y: 44; width: parent.width
            W.Texto { width: parent.width; text: b.p ? (b.p.track || "—") : "Nada sonando"; color: b.tema.texto; font.pixelSize: 20; font.weight: Font.DemiBold; elide: Text.ElideRight }
            W.Texto { width: parent.width; text: b.p ? (b.p.artist || "") : "Abre música para controlarla aquí"; color: b.tema.texto2; font.pixelSize: 13; elide: Text.ElideRight }
        }
        // El avance, con su perilla
        Item {
            id: av
            y: parent.height - 86; width: parent.width; height: 22
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.18) }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: b.largo > 0 ? parent.width * Math.min(1, b.pos / b.largo) : 0; height: 8; radius: 4
                color: b.tema.relleno
            }
            Rectangle {
                visible: b.largo > 0
                x: (b.largo > 0 ? parent.width * Math.min(1, b.pos / b.largo) : 0) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20; radius: 10; color: "#FFFFFF"
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!b.p && b.p.canSeek && b.largo > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => { var d = b.largo * Math.max(0, Math.min(1, mouse.x / width)); b.p.Seek(d - b.pos); b.pos = d }
            }
        }
        W.Texto { y: av.y + 24; text: b.hora(b.pos); color: b.tema.texto2; font.pixelSize: 11 }
        W.Texto { y: av.y + 24; anchors.right: parent.right; text: b.hora(b.largo); color: b.tema.texto2; font.pixelSize: 11 }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            spacing: Math.min(22, parent.width / 14)
            Control { icono: "media-playlist-shuffle-symbolic"; tam: 20; activo: b.hay; resaltado: !!b.p && b.p.shuffle
                      anchors.verticalCenter: parent.verticalCenter; onClic: if (b.p) b.p.shuffle = !b.p.shuffle }
            Control { icono: "media-skip-backward-symbolic"; activo: !!b.p && b.p.canGoPrevious; onClic: if (b.p) b.p.Previous() }
            Control { icono: b.sis.sonando ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; tam: 30; activo: b.hay; onClic: if (b.p) b.p.PlayPause() }
            Control { icono: "media-skip-forward-symbolic"; activo: !!b.p && b.p.canGoNext; onClic: if (b.p) b.p.Next() }
            Control { icono: "media-playlist-repeat-symbolic"; tam: 20; activo: b.hay; resaltado: !!b.p && b.p.loopStatus !== 0
                      anchors.verticalCenter: parent.verticalCenter; onClic: if (b.p) b.p.loopStatus = (b.p.loopStatus + 1) % 3 }
        }
    }
    // ── Compacto ──
    Item {
        anchors.fill: parent; anchors.margins: 16
        visible: b.forma === "compacta"
        Kirigami.Icon { x: 2; y: 6; width: 16; height: 16; source: "media-playback-start-symbolic"; isMask: true; color: b.tema.texto }
        W.Texto { x: 24; y: 4; width: parent.width - sal2.width - 32; text: b.p ? (b.p.track || b.p.identity) : "Música"; color: b.tema.texto
                  font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
        Salida { id: sal2; anchors.right: parent.right; y: 0 }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            spacing: 26
            Control { icono: "media-skip-backward-symbolic"; tam: 22; activo: !!b.p && b.p.canGoPrevious; onClic: if (b.p) b.p.Previous() }
            Control { icono: b.sis.sonando ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; tam: 24; activo: b.hay; onClic: if (b.p) b.p.PlayPause() }
            Control { icono: "media-skip-forward-symbolic"; tam: 22; activo: !!b.p && b.p.canGoNext; onClic: if (b.p) b.p.Next() }
        }
    }
    // ── Medio ancho ──
    Item {
        anchors.fill: parent; anchors.margins: 12
        visible: b.forma === "chica"
        Rectangle {
            id: tapa
            visible: parent.width > 130
            width: Math.min(parent.height, 72); height: width; radius: 16; clip: true
            anchors.verticalCenter: parent.verticalCenter
            color: b.tema.vidrioFuerte
            Image { anchors.fill: parent; source: b.arte; fillMode: Image.PreserveAspectCrop; sourceSize.width: 120; visible: status === Image.Ready }
            Control { anchors.centerIn: parent; icono: b.sis.sonando ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; tam: 22
                      activo: b.hay; onClic: if (b.p) b.p.PlayPause() }
        }
        Column {
            anchors { left: tapa.visible ? tapa.right : parent.left; leftMargin: tapa.visible ? 10 : 0; right: parent.right; verticalCenter: parent.verticalCenter }
            W.Texto { width: parent.width; text: b.p ? (b.p.track || "—") : "Música"; color: b.tema.texto; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
            W.Texto { width: parent.width; text: b.p ? (b.p.artist || b.p.identity) : "Nada sonando"; color: b.tema.texto2; font.pixelSize: 11; elide: Text.ElideRight }
        }
    }
    // ── Ancha ──
    Item {
        anchors.fill: parent; anchors.margins: 14
        visible: b.forma === "ancha"
        Rectangle {
            id: tapaAncha
            width: Math.min(parent.height, 220); height: width; radius: 18; clip: true
            anchors.verticalCenter: parent.verticalCenter
            color: b.tema.vidrioFuerte
            Image { anchors.fill: parent; source: b.arte; fillMode: Image.PreserveAspectCrop; sourceSize.width: 240; visible: status === Image.Ready }
            Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.36; height: width; visible: b.arte === ""
                            source: "media-playback-start-symbolic"; isMask: true; color: b.tema.texto2 }
        }
        Item {
            id: lado
            anchors { left: tapaAncha.right; leftMargin: 16; right: parent.right; top: parent.top; bottom: parent.bottom }
            Column {
                width: parent.width - salidaAncha.width - 8
                W.Texto { width: parent.width; text: b.p ? (b.p.track || "—") : "Nada sonando"; color: b.tema.texto
                          font.pixelSize: Math.min(20, Math.max(15, lado.height / 9)); font.weight: Font.DemiBold; elide: Text.ElideRight }
                W.Texto { width: parent.width; text: b.p ? (b.p.artist || b.p.identity) : "Abre música para controlarla aquí"; color: b.tema.texto2; font.pixelSize: 13; elide: Text.ElideRight }
            }
            // La salida (abre Sonido), como un botón
            Rectangle {
                id: salidaAncha
                anchors.right: parent.right
                width: 32; height: 32; radius: 16
                color: smA.containsMouse ? b.tema.vidrioFuerte : Qt.rgba(0, 0, 0, 0.18)
                Kirigami.Icon { anchors.centerIn: parent; width: 16; height: 16; source: "audio-speakers-symbolic"; isMask: true; color: b.tema.texto }
                MouseArea { id: smA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.abrir("sonido") }
            }
            // El avance
            Item {
                id: avA
                y: controlesA.y - height - 4; width: parent.width; height: 18
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.18) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 6; radius: 3; color: b.tema.relleno
                            width: b.largo > 0 ? parent.width * Math.min(1, b.pos / b.largo) : 0 }
                MouseArea {
                    anchors.fill: parent
                    enabled: !!b.p && b.p.canSeek && b.largo > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => { var d = b.largo * Math.max(0, Math.min(1, mouse.x / width)); b.p.Seek(d - b.pos); b.pos = d }
                }
            }
            Row {
                id: controlesA
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: Math.min(18, parent.width / 16)
                Control { icono: "media-playlist-shuffle-symbolic"; tam: 18; visible: lado.width > 260; activo: b.hay; resaltado: !!b.p && b.p.shuffle
                          anchors.verticalCenter: parent.verticalCenter; onClic: if (b.p) b.p.shuffle = !b.p.shuffle }
                Control { icono: "media-skip-backward-symbolic"; tam: 22; activo: !!b.p && b.p.canGoPrevious; onClic: if (b.p) b.p.Previous() }
                Control { icono: b.sis.sonando ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; tam: 26; activo: b.hay; onClic: if (b.p) b.p.PlayPause() }
                Control { icono: "media-skip-forward-symbolic"; tam: 22; activo: !!b.p && b.p.canGoNext; onClic: if (b.p) b.p.Next() }
                Control { icono: "media-playlist-repeat-symbolic"; tam: 18; visible: lado.width > 260; activo: b.hay; resaltado: !!b.p && b.p.loopStatus !== 0
                          anchors.verticalCenter: parent.verticalCenter; onClic: if (b.p) b.p.loopStatus = (b.p.loopStatus + 1) % 3 }
            }
        }
    }
}
