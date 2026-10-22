import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Personalización › Widgets: los widgets de Coucou para el escritorio (org.coucou.*, en
// /usr/share/plasma/plasmoids). Un clic en "Agregar" lo pone en el escritorio de la pantalla
// principal; después se mueven y se agrandan como cualquier widget de Plasma, y cada uno tiene su
// configuración (clic derecho › Configurar). Arriba, un color para todos de una vez.
// Todo pasa por los scripts de Plasma (qdbus6 … evaluateScript), con backend.launch.
ScrollView {
    id: root
    contentWidth: availableWidth

    readonly property real pageW: Math.max(260, Math.min(root.availableWidth - 32, 1000))
    readonly property int cols: Math.max(1, Math.floor((pageW + 12) / 236))
    readonly property real cardW: (pageW - 12 * (cols - 1)) / cols
    readonly property bool narrow: pageW < 620
    property string aviso: ""

    // id, nombre, qué hace, su dibujo y sus colores (los del diseño original)
    readonly property var widgets: [
        { id: "musica", nombre: "Música", desc: "Lo que suena: carátula, avance y controles", glifo: "♪", ancho: 380, alto: 180, de: "#2C2C30", a: "#141416" },
        { id: "animo", nombre: "¿Cómo estás hoy?", desc: "Una imagen que te pregunta cómo estás", glifo: "😊", ancho: 180, alto: 180, de: "#7A5236", a: "#3A2418" },
        { id: "temporizador", nombre: "Temporizador", desc: "Reloj de arena: clic empieza, la rueda cambia el tiempo", glifo: "⏳", ancho: 180, alto: 180, de: "#063D22", a: "#021A0E" },
        { id: "mascota", nombre: "Mascota pixel", desc: "Un dinosaurio: dale de comer y sube de nivel", glifo: "🦖", ancho: 180, alto: 180, de: "#141414", a: "#000000" },
        { id: "clima", nombre: "Clima pixel", desc: "Temperatura y próximos días, con paisaje de pixeles", glifo: "☀", ancho: 180, alto: 180, de: "#A66636", a: "#3A2412" },
        { id: "decidir", nombre: "Sí o No", desc: "Una ruleta que decide por ti", glifo: "🎲", ancho: 180, alto: 180, de: "#E53935", a: "#A61B1B" },
        { id: "almacenamiento", nombre: "Almacenamiento", desc: "Cuánto ocupa el disco y cuánto queda libre", glifo: "💽", ancho: 180, alto: 180, de: "#7B4FD8", a: "#6E8BE8" },
        { id: "volumen", nombre: "Volumen", desc: "Arrastra el arco; silenciar y cambiar de salida", glifo: "🔊", ancho: 180, alto: 180, de: "#24465A", a: "#173040" },
        { id: "rendimiento", nombre: "Rendimiento", desc: "Procesador, memoria, temperatura y batería", glifo: "⚡", ancho: 180, alto: 180, de: "#6B2BEA", a: "#8E2DE2" },
        { id: "relojes", nombre: "Relojes del mundo", desc: "La hora en tres lugares, con su nombre", glifo: "🌍", ancho: 380, alto: 180, de: "#26262B", a: "#121215" },
        { id: "conexiones", nombre: "Conexiones", desc: "Wi-Fi, Bluetooth y modo avión con un clic", glifo: "📶", ancho: 180, alto: 180, de: "#26262B", a: "#121215" }
    ]
    readonly property var colores: [
        { id: "coucou", nombre: "Coucou", muestra: win.accent },
        { id: "original", nombre: "Como en el diseño", muestra: "#E53935" },
        { id: "oscuro", nombre: "Oscuro", muestra: "#1C1C20" }, { id: "claro", nombre: "Claro", muestra: "#F4F2FA" },
        { id: "violeta", nombre: "Violeta", muestra: "#7B3FE4" }, { id: "azul", nombre: "Azul", muestra: "#2563EB" },
        { id: "verde", nombre: "Verde", muestra: "#0B5C33" }, { id: "rojo", nombre: "Rojo", muestra: "#E53935" },
        { id: "naranja", nombre: "Naranja", muestra: "#F97316" }, { id: "rosa", nombre: "Rosa", muestra: "#EC4899" }
    ]

    function plasma(script) {
        backend.launch("qdbus6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", script])
    }
    function agregar(w) {
        // En el escritorio de la pantalla principal, cerca de arriba a la izquierda y corrido según
        // cuántos de Coucou ya hay, para que no queden uno encima del otro
        plasma('var d = desktops(), D = d[0];' +
               'for (var i = 0; i < d.length; i++) if (d[i].screen === 0) D = d[i];' +
               'var n = D.widgets().filter(function (x) { return String(x.type).indexOf("org.coucou.") === 0 }).length;' +
               'D.addWidget("org.coucou.' + w.id + '", 80 + (n % 5) * 200, 100 + Math.floor(n / 5) * 200, ' + w.ancho + ', ' + w.alto + ');')
        aviso = "«" + w.nombre + "» está en el escritorio. Para moverlo o cambiarle el tamaño, usa «Acomodar en el escritorio»."
        avisoTimer.restart()
    }
    function colorATodos(c) {
        plasma('var d = desktops();' +
               'for (var i = 0; i < d.length; i++) { var w = d[i].widgets();' +
               '  for (var j = 0; j < w.length; j++) if (String(w[j].type).indexOf("org.coucou.") === 0 && w[j].type !== "org.coucou.clima") {' +
               '    w[j].currentConfigGroup = ["General"]; w[j].writeConfig("estilo", "' + c.id + '"); w[j].reloadConfig() } }')
        aviso = "Los widgets de Coucou del escritorio quedaron en «" + c.nombre + "»."
        avisoTimer.restart()
    }
    function quitarTodos() {
        plasma('var d = desktops();' +
               'for (var i = 0; i < d.length; i++) { var w = d[i].widgets();' +
               '  for (var j = 0; j < w.length; j++) if (String(w[j].type).indexOf("org.coucou.") === 0) w[j].remove() }')
        confirmar = false
        aviso = "Se quitaron los widgets de Coucou del escritorio."
        avisoTimer.restart()
    }
    property bool confirmar: false
    Timer { id: avisoTimer; interval: 6000; onTriggered: root.aviso = "" }

    component Section: ColumnLayout {
        id: sec
        property string title
        property string text
        Layout.fillWidth: true
        Layout.topMargin: 18
        spacing: 2
        Label { text: sec.title; font.pixelSize: 16; font.weight: Font.DemiBold; color: win.text }
        Label { Layout.fillWidth: true; visible: sec.text !== ""; text: sec.text; color: win.subtext; wrapMode: Text.WordWrap; font.pixelSize: 12 }
    }

    ColumnLayout {
        width: root.pageW
        x: Math.max(8, (root.availableWidth - width) / 2 - 8)
        spacing: 6

        PageHeader {
            Layout.topMargin: 4
            Layout.bottomMargin: 6
            parts: [{ title: "Personalización" }, { title: "Widgets" }]
        }

        Label {
            Layout.fillWidth: true
            text: "Agrega los que quieras al escritorio. Después los acomodas a tu gusto: muévelos y cambia su tamaño desde los bordes con «Acomodar en el escritorio» (lo de adentro se ajusta solo). Cada uno tiene su color y sus opciones con clic derecho › Configurar."
            color: win.subtext; wrapMode: Text.WordWrap; font.pixelSize: 12
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8
            Button { text: "Acomodar en el escritorio"; icon.name: "transform-move"; highlighted: true
                     onClicked: backend.launch("qdbus6", ["org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.editMode", "true"]) }
            Button { text: "Quitar todos"; icon.name: "edit-delete"; flat: true; onClicked: root.confirmar = true }
        }
        // Avisos y confirmación
        Rectangle {
            visible: root.aviso !== "" || root.confirmar
            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: av.implicitHeight + 24
            radius: 8
            color: win.dark ? "#2A2550" : "#EEEBFD"
            border.width: 1; border.color: win.dark ? "#3D3770" : "#D9D3FA"
            GridLayout {
                id: av
                anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 12; bottomMargin: 12 }
                columns: root.narrow ? 1 : 2
                Label {
                    Layout.fillWidth: true
                    text: root.confirmar ? "¿Quitar todos los widgets de Coucou del escritorio? Su configuración se pierde." : root.aviso
                    color: win.text; wrapMode: Text.WordWrap; font.pixelSize: 12
                }
                RowLayout {
                    visible: root.confirmar
                    Button { text: "Quitar"; highlighted: true; onClicked: root.quitarTodos() }
                    Button { text: "Cancelar"; flat: true; onClicked: root.confirmar = false }
                }
            }
        }

        // Un color para todos ─────────────────────────────────────────────────
        Section {
            title: "Color de todos los widgets"
            text: "«Coucou» sigue tu color de énfasis y el modo claro u oscuro. Se aplica a los que ya están en el escritorio (el clima tiene su paisaje propio)."
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            Repeater {
                model: root.colores
                delegate: Rectangle {
                    required property var modelData
                    width: chip.implicitWidth + 40; height: 36; radius: 18
                    color: cm.containsMouse ? win.cardHover : win.cardBg
                    border.color: win.cardBorder
                    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9; color: modelData.muestra
                                border.width: 1; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.4) }
                    Label { id: chip; x: 34; anchors.verticalCenter: parent.verticalCenter; text: modelData.nombre; color: win.text; font.pixelSize: 12 }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.colorATodos(modelData) }
                }
            }
        }

        // La galería ──────────────────────────────────────────────────────────
        Section { title: "Widgets de Coucou"; text: "" }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 30
            spacing: 12
            Repeater {
                model: root.widgets
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: root.cardW; height: 200
                    radius: 8
                    color: hov.hovered ? win.cardHover : win.cardBg
                    border.color: win.cardBorder
                    Behavior on color { ColorAnimation { duration: 100 } }
                    // La muestra: sus colores y su dibujo (ancho si el widget es ancho)
                    Item {
                        x: 8; y: 8; width: parent.width - 16; height: 104
                        Rectangle {
                            anchors.centerIn: parent
                            height: 88
                            width: card.modelData.ancho > card.modelData.alto ? Math.min(parent.width - 8, 176) : 88
                            radius: 18
                            gradient: Gradient {
                                GradientStop { position: 0; color: card.modelData.de }
                                GradientStop { position: 1; color: card.modelData.a }
                            }
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
                            Label { anchors.centerIn: parent; text: card.modelData.glifo; font.pixelSize: 38; color: "#FFFFFF" }
                        }
                    }
                    ColumnLayout {
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 118 }
                        spacing: 2
                        Label { Layout.fillWidth: true; text: card.modelData.nombre; color: win.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; text: card.modelData.desc; color: win.subtext; font.pixelSize: 11; elide: Text.ElideRight; maximumLineCount: 1 }
                    }
                    Button {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
                        text: "Agregar al escritorio"
                        icon.name: "list-add"
                        flat: !hov.hovered
                        onClicked: root.agregar(card.modelData)
                    }
                    HoverHandler { id: hov }
                }
            }
        }
    }
}
