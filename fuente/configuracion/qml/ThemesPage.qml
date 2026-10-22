import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Pages.js" as P

// Personalización > Temas: galería de temas globales con su vista previa (un clic
// lo aplica, solo el aspecto: los paneles no se tocan), el tema "Coucou Code"
// que pone todo en la interfaz de Coucou, y accesos a cada parte del tema.
ScrollView {
    id: root
    property var items: []
    contentWidth: availableWidth

    readonly property string coucouAccent: "#6574F6"
    property var themes: backend.lookAndFeels()
    property string current: backend.currentLookAndFeel()
    property string applying: ""
    readonly property string coucouId: "org.coucou.code"
    property bool coucouOn: current === coucouId

    Timer {
        interval: 900; repeat: true; running: root.visible
        onTriggered: {
            root.current = backend.currentLookAndFeel()
            if (root.applying === root.current) root.applying = ""
        }
    }
    Timer { id: giveUp; interval: 25000; onTriggered: root.applying = "" }
    // Lo bajado de la tienda aparece enseguida en la galería
    Connections {
        target: backend
        function onStoreClosed(knsrc) { if (knsrc === "lookandfeel") root.themes = backend.lookAndFeels() }
    }

    function applyTheme(id) {
        if (id === current) return
        // Dejar Coucou Code: vuelven la pantalla de bloqueo y el inicio de sesión de antes
        if (coucouOn) win.leaveCoucouCode()
        applying = id
        giveUp.restart()
        backend.applyLookAndFeel(id)
    }
    // Coucou Code cambia todo a la interfaz de Coucou: el tema (pantalla de
    // carga), modo oscuro y violeta, la barra de Coucou, la pantalla de
    // bloqueo y, con la contraseña de administrador, el inicio de sesión.
    property string applyingMode: ""
    function applyCoucou(mode) {
        // Ya con Coucou Code: solo cambia entre claro y oscuro (un solo fundido, sin recargar nada)
        if (coucouOn) {
            if (backend.mode !== mode) backend.setCoucouTheme(mode, backend.accent, backend.transparency)
            return
        }
        applying = coucouId
        applyingMode = mode
        giveUp.restart()
        win.applyCoucouCode(mode)
    }


    // Tarjeta de la galería
    component ThemeCard: Rectangle {
        id: card
        property string title
        property string subtitle
        property bool active
        property bool busy
        property alias preview: previewSlot.data
        signal picked()
        width: 228; height: 196
        radius: 8
        color: hover.containsMouse ? win.cardHover : win.cardBg
        border.width: active ? 2 : 1
        border.color: active ? win.accent : (hover.containsMouse ? (win.dark ? "#4A4A4A" : "#CFCFCF") : win.cardBorder)
        scale: hover.pressed ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        Rectangle {
            id: previewBox
            x: 8; y: 8; width: parent.width - 16; height: 126
            radius: 6; clip: true; color: "#111"
            Item { id: previewSlot; anchors.fill: parent }
            // Tilde de "en uso"
            Rectangle {
                visible: card.active
                anchors { right: parent.right; top: parent.top; margins: 8 }
                width: 22; height: 22; radius: 11; color: win.accent
                Label { anchors.centerIn: parent; text: "✓"; color: "#FFF"; font.pixelSize: 13; font.bold: true }
            }
            Rectangle {
                visible: card.busy
                anchors.fill: parent; color: "#80000000"
                BusyIndicator { anchors.centerIn: parent; running: card.busy; width: 36; height: 36 }
            }
        }
        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: previewBox.bottom; margins: 12; topMargin: 10 }
            spacing: 1
            Label { Layout.fillWidth: true; text: card.title; color: win.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label { Layout.fillWidth: true; text: card.busy ? "Aplicando…" : (card.active ? "En uso" : card.subtitle)
                    color: card.active && !card.busy ? win.accent : win.subtext; font.pixelSize: 11; elide: Text.ElideRight }
        }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
    }

    ColumnLayout {
        width: Math.min(root.availableWidth - 48, 1000)
        x: Math.max(4, (root.availableWidth - width) / 2 - 8)
        spacing: 4

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 12
            parts: [{ title: "Personalización" }, { title: "Temas" }]
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 8
            Button {
                text: "Descargar temas de la tienda de KDE"
                icon.name: "get-hot-new-stuff"
                onClicked: backend.openStore("lookandfeel")
            }
            Item { Layout.fillWidth: true }
        }

        Label { text: "Temas globales"; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text }
        Label {
            Layout.bottomMargin: 10
            text: "Haz clic en un tema para aplicarlo. Cambia colores, estilos, iconos y cursores; tus paneles y apps ancladas no se tocan."
            color: win.subtext; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        Flow {
            Layout.fillWidth: true
            Layout.bottomMargin: 22
            spacing: 12

            // Coucou Code: la interfaz nueva, en oscuro (violeta noche) y en claro (lavanda)
            Repeater {
                model: backend.hasCoucou() ? ["dark", "light"] : []
                ThemeCard {
                    readonly property bool lightCard: modelData === "light"
                    title: lightCard ? "Coucou Code claro" : "Coucou Code"
                    subtitle: lightCard ? "El diseño de Coucou en lavanda y blanco" : "Todo con el diseño de Coucou: barra, bloqueo e inicio"
                    active: root.coucouOn && root.applying === "" && (backend.mode === "light") === lightCard
                    busy: root.applying === root.coucouId && root.applyingMode === modelData
                    onPicked: root.applyCoucou(modelData)
                    preview: [
                        Image { anchors.fill: parent; source: backend.wallpaper; sourceSize.width: 440; fillMode: Image.PreserveAspectCrop; asynchronous: true },
                        Rectangle { anchors.fill: parent; gradient: Gradient {
                            GradientStop { position: 0; color: lightCard ? "#B0F4F2FF" : "#B0141233" }
                            GradientStop { position: 1; color: lightCard ? "#E0E7E2FB" : "#E00A0920" } } },
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 10
                            width: 150; height: 20; radius: 10
                            color: lightCard ? "#E6FFFFFF" : "#D91E1B48"; border.color: lightCard ? "#80C9C2F0" : "#80A79BFF"; border.width: 1
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 6; height: 6; radius: 3; color: lightCard ? "#6D5CF0" : "#D8D4FF"; anchors.verticalCenter: parent.verticalCenter }
                                Rectangle { width: 10; height: 10; radius: 5; color: lightCard ? "#1E1B48" : "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter
                                    Row { anchors.centerIn: parent; spacing: 2
                                        Rectangle { width: 2; height: 3; radius: 1; color: lightCard ? "#FFFFFF" : "#1E1B48" }
                                        Rectangle { width: 2; height: 3; radius: 1; color: lightCard ? "#FFFFFF" : "#1E1B48" } } }
                                Repeater { model: [ "#F6C445", "#E5484D", "#3BA2FF" ]
                                    Rectangle { width: 7; height: 7; radius: 2; color: modelData; anchors.verticalCenter: parent.verticalCenter } }
                                Item { width: 10; height: 1 }
                                Repeater { model: 3; Rectangle { width: 5; height: 5; radius: 2; color: lightCard ? "#6D5CF0" : "#D8D4FF"; anchors.verticalCenter: parent.verticalCenter } }
                            }
                        },
                        Rectangle {
                            x: 34; y: 40; width: parent.width - 68; height: 70; radius: 10
                            color: lightCard ? "#F2FFFFFF" : "#E61B1840"; border.color: "#406574F6"; border.width: 1
                            Rectangle { x: 10; y: 10; width: 44; height: 10; radius: 5; color: "#336574F6"
                                Rectangle { x: 4; y: 3; width: 4; height: 4; radius: 2; color: "#3DDC84" } }
                            Rectangle { anchors.right: parent.right; anchors.rightMargin: 10; y: 12; width: 70; height: 12; radius: 6; color: "#6574F6" }
                            Rectangle { x: 10; y: 44; width: parent.width - 20; height: 16; radius: 8; color: lightCard ? "#EEEBFC" : "#2AFFFFFF"
                                Rectangle { anchors.right: parent.right; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter
                                    width: 12; height: 12; radius: 6; color: lightCard ? "#6574F6" : "#FFFFFF" } }
                        },
                        Label { anchors { left: parent.left; bottom: parent.bottom; margins: 8 } text: "</> Code"
                                color: lightCard ? "#1D1B33" : "#FFFFFF"; font.pixelSize: 11; font.bold: true; opacity: 0.85 }
                    ]
                }
            }

            Repeater {
                model: root.themes.filter(function (t) { return t.id !== root.coucouId })
                delegate: ThemeCard {
                    required property var modelData
                    title: modelData.name
                    subtitle: modelData.author || modelData.id
                    active: root.current === modelData.id && root.applying === "" && !root.coucouOn
                    busy: root.applying === modelData.id
                    onPicked: root.applyTheme(modelData.id)
                    preview: [
                        Image {
                            anchors.fill: parent
                            visible: modelData.preview !== ""
                            source: modelData.preview
                            sourceSize.width: 440
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        },
                        // Windows 11 sin imagen: el logo sobre el azul de Windows
                        Rectangle {
                            anchors.fill: parent
                            visible: modelData.preview === "" && modelData.id.indexOf("win11") >= 0
                            gradient: Gradient {
                                GradientStop { position: 0; color: "#0A2A6B" }
                                GradientStop { position: 1; color: "#1E6FE0" }
                            }
                            Grid {
                                anchors.centerIn: parent; columns: 2; spacing: 3
                                Repeater { model: 4; Rectangle { width: 22; height: 22; radius: 2; color: "#EAF3FF" } }
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: "#E6202020"
                                Row { anchors.centerIn: parent; spacing: 4
                                    Repeater { model: 5; Rectangle { width: 7; height: 7; radius: 2; color: index === 0 ? "#4CC2FF" : "#9A9A9A" } } } }
                        },
                        // Sin imagen: una ventana dibujada en claro u oscuro
                        Rectangle {
                            anchors.fill: parent
                            visible: modelData.preview === "" && modelData.id.indexOf("win11") < 0
                            color: modelData.dark ? "#1F1F1F" : "#E9EDF3"
                            Rectangle { anchors.centerIn: parent; width: 120; height: 70; radius: 6
                                color: modelData.dark ? "#2B2B2B" : "#FFFFFF"
                                Rectangle { x: 10; y: 10; width: 60; height: 7; radius: 3; color: win.accent } }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 14; color: modelData.dark ? "#151515" : "#F7F7F7" }
                        }
                    ]
                }
            }
        }

        Label { text: "Personaliza cada parte"; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text; Layout.bottomMargin: 8 }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 300))
            columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: P.visibleItems(root.items, backend.kcms)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 8
                    color: tileMouse.containsMouse ? win.cardHover : win.cardBg
                    border.color: win.cardBorder
                    Behavior on color { ColorAnimation { duration: 100 } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 14
                        Rectangle {
                            Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 10
                            color: win.dark ? "#363636" : "#EFEFEF"
                            Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(24, 24)
                                    source: "image://icon/" + modelData.icon }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Label { Layout.fillWidth: true; text: modelData.title; color: win.text; font.pixelSize: 13; elide: Text.ElideRight }
                            Label { Layout.fillWidth: true; text: modelData.desc; color: win.subtext; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                        Label { text: "›"; color: win.subtext; font.pixelSize: 18 }
                    }
                    MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: win.activate(modelData) }
                }
            }
        }
    }
}
