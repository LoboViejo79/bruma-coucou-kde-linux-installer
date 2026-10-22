import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "¿Cómo quieres abrir este archivo?" del Explorador de Windows 11
ApplicationWindow {
    id: win
    width: 460
    height: 620
    minimumWidth: 380
    minimumHeight: 420
    visible: true
    title: "Abrir con"
    flags: Qt.Dialog

    readonly property bool dark: openWith.dark
    readonly property color accent: openWith.accent
    readonly property color bg: dark ? "#202020" : "#F3F3F3"
    readonly property color panel: dark ? "#2B2B2B" : "#FBFBFB"
    readonly property color line: dark ? "#3A3A3A" : "#E5E5E5"
    readonly property color hoverBg: dark ? "#323232" : "#EDEDED"
    readonly property color selectedBg: dark ? "#383838" : "#E6E6E6"
    readonly property color text: dark ? "#FFFFFF" : "#1A1A1A"
    readonly property color subtext: dark ? "#C5C5C5" : "#5F5F5F"

    // Seleccionada: la app actual o, si no hay, la primera sugerida
    property string selectedId: openWith.current.id || (openWith.suggested.length ? openWith.suggested[0].id : "")
    property bool showMore: openWith.suggested.length === 0 && !openWith.current.id
    property var browsed: []      // apps elegidas con "Buscar otra aplicación"
    property bool busy: false

    function launch(always) {
        if (!selectedId || busy)
            return
        busy = true
        openWith.open(selectedId, always)
    }

    font.family: "Selawik"
    palette.window: bg
    palette.windowText: text
    palette.accent: accent
    palette.highlight: accent
    color: bg

    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequences: ["Return", "Enter"]; onActivated: win.launch(false) }

    Connections {
        target: openWith
        function onFailed(message) { win.busy = false; error.text = message; error.visible = true }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Cabecera: pregunta y archivo
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            Layout.bottomMargin: 16
            spacing: 14
            Label {
                text: openWith.title
                color: win.text
                font.pixelSize: 20
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 12
                Image {
                    source: "image://icon/" + openWith.fileIcon
                    sourceSize: Qt.size(32, 32)
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Label { text: openWith.fileName; color: win.text; font.pixelSize: 14; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    Label { text: openWith.typeName; color: win.subtext; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: win.line }

        // Lista de aplicaciones
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 2

                Item { Layout.preferredHeight: 10 }

                Label {
                    visible: !!openWith.current.id
                    text: "Mantener el uso de esta aplicación"
                    color: win.subtext; font.pixelSize: 12
                    Layout.leftMargin: 24; Layout.topMargin: 4; Layout.bottomMargin: 4
                }
                AppRow {
                    visible: !!openWith.current.id
                    app: openWith.current
                    selected: win.selectedId === app.id
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                    onPicked: win.selectedId = app.id
                    onActivated: { win.selectedId = app.id; win.launch(false) }
                }

                Label {
                    visible: openWith.suggested.length > 0 || win.browsed.length > 0
                    text: "Otras opciones"
                    color: win.subtext; font.pixelSize: 12
                    Layout.leftMargin: 24; Layout.topMargin: 12; Layout.bottomMargin: 4
                }
                Repeater {
                    model: win.browsed.concat(openWith.suggested)
                    AppRow {
                        app: modelData
                        selected: win.selectedId === modelData.id
                        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                        onPicked: win.selectedId = modelData.id
                        onActivated: { win.selectedId = modelData.id; win.launch(false) }
                    }
                }

                // Más aplicaciones (todas las instaladas)
                Rectangle {
                    visible: openWith.others.length > 0
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 6
                    implicitHeight: 40
                    radius: 4
                    color: moreMouse.containsMouse ? win.hoverBg : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        Label { text: win.showMore ? "Menos aplicaciones" : "Más aplicaciones"; color: win.accent; font.pixelSize: 14; Layout.fillWidth: true }
                        Label { text: win.showMore ? "⌃" : "⌄"; color: win.accent; font.pixelSize: 14 }
                    }
                    MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.showMore = !win.showMore }
                }
                Repeater {
                    model: win.showMore ? openWith.others : []
                    AppRow {
                        app: modelData
                        selected: win.selectedId === modelData.id
                        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
                        onPicked: win.selectedId = modelData.id
                        onActivated: { win.selectedId = modelData.id; win.launch(false) }
                    }
                }

                // Buscar otra aplicación en este equipo
                Rectangle {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.topMargin: 6
                    implicitHeight: 40
                    radius: 4
                    color: browseMouse.containsMouse ? win.hoverBg : "transparent"
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        text: "Buscar otra aplicación en este equipo"
                        color: win.accent; font.pixelSize: 14
                    }
                    MouseArea {
                        id: browseMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            const e = openWith.browse()
                            if (e.id) {
                                win.browsed = [e].concat(win.browsed)
                                win.selectedId = e.id
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 12 }
            }
        }

        Label {
            id: error
            visible: false
            color: win.dark ? "#FF99A4" : "#C42B1C"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.topMargin: 6
        }

        // Botones: "Siempre" deja la app como predeterminada para este tipo de archivo
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 76
            color: win.panel
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: win.line }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 24
                spacing: 8
                Button {
                    text: "Siempre"
                    highlighted: true
                    enabled: !!win.selectedId && !win.busy
                    Layout.fillWidth: true
                    onClicked: win.launch(true)
                }
                Button {
                    text: "Solo una vez"
                    enabled: !!win.selectedId && !win.busy
                    Layout.fillWidth: true
                    onClicked: win.launch(false)
                }
            }
        }
    }
}
