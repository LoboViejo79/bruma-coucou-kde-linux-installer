import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Muestra un módulo de KDE (KCM en QML) dentro de la ventana, como las páginas de Configuración de Windows.
// Los cambios se aplican al salir de la página (como en Windows) o con "Aplicar".
Item {
    id: root
    property string kcm
    property var module: null
    property bool failed: false
    // Algunos módulos se marcan "con cambios" nada más abrirse: solo cuenta tras tocar algo
    property bool touched: false

    function unload() {
        if (!module) return
        if (module.needsSave && touched) module.save()
        stack.clear(StackView.Immediate)
        backend.unloadKcm(module)
        module = null
    }
    function load() {
        unload()
        failed = false
        touched = false
        if (!kcm) return
        module = backend.loadKcm(kcm, root)
        if (!module || !module.mainUi) {
            failed = true
            backend.openKcm(kcm)        // se abre en ventana aparte como último recurso
            return
        }
        pushPage(module.mainUi, StackView.Immediate)
    }
    // Algunos módulos traen un ancho fijo: se ajusta siempre al de la vista
    function pushPage(page, op) {
        stack.push(page, {}, op === undefined ? StackView.PushTransition : op)
        page.width = Qt.binding(function () { return stack.width })
        page.height = Qt.binding(function () { return stack.height })
    }
    onKcmChanged: load()
    Component.onCompleted: {
        load()
        win.backHook = function () {
            if (root.module && root.module.depth > 1) { root.module.pop(); return true }
            return false
        }
    }
    Component.onDestruction: {
        win.backHook = null
        unload()
    }

    Connections {
        target: root.module
        ignoreUnknownSignals: true
        function onPagePushed(page) { root.pushPage(page) }
        function onPageRemoved() { if (stack.depth > 1) stack.pop() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.bottomMargin: 8
            parts: win.pathParts
        }

        // Acciones propias del módulo (las que KDE pone en la barra superior de la página)
        RowLayout {
            readonly property var acts: stack.currentItem && stack.currentItem.actions ? stack.currentItem.actions : []
            visible: acts.length > 0
            Layout.fillWidth: true
            Layout.bottomMargin: 6
            spacing: 6
            Repeater {
                model: parent.acts
                Button {
                    visible: modelData.visible !== false
                    enabled: modelData.enabled !== false
                    text: modelData.text || ""
                    icon.name: modelData.icon ? modelData.icon.name : ""
                    flat: true
                    onClicked: modelData.trigger()
                }
            }
            Item { Layout.fillWidth: true }
        }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            // Detecta interacción sin quitarle el evento al módulo
            PointHandler { onActiveChanged: if (active) root.touched = true }
            Keys.onPressed: root.touched = true
            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
                    NumberAnimation { property: "x"; from: 40; to: 0; duration: 250; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
            popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 } }
            popExit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        }

        // Barra de cambios pendientes
        Rectangle {
            readonly property bool hasDefaults: !!root.module && (root.module.buttons & 2) && !root.module.representsDefaults
            visible: !!root.module && root.module.needsSave && root.touched
            Layout.fillWidth: true
            Layout.rightMargin: 36
            implicitHeight: 60
            radius: 6
            color: win.cardBg
            border.color: win.cardBorder
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 12
                spacing: 8
                Label {
                    Layout.fillWidth: true
                    text: root.module && root.module.needsSave ? "Tienes cambios sin aplicar" : ""
                    color: win.subtext
                }
                Button {
                    visible: parent.parent.hasDefaults
                    text: "Restablecer valores predeterminados"
                    onClicked: root.module.defaults()
                }
                Button {
                    visible: !!root.module && root.module.needsSave
                    text: "Descartar"
                    onClicked: root.module.load()
                }
                Button {
                    visible: !!root.module && root.module.needsSave
                    highlighted: true
                    text: "Aplicar"
                    onClicked: root.module.save()
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.failed
        text: "Esta página se abrió en una ventana aparte."
        color: win.subtext
    }
}
