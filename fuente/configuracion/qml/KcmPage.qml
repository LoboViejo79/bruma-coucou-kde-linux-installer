import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Muestra un módulo de KDE (KCM en QML) dentro de la ventana, como las páginas de Configuración de Windows.
// Abajo, siempre, los botones de Windows: Restablecer, Cancelar, Aplicar y Aceptar. Al salir de la
// página, lo que se haya cambiado también se aplica.
Item {
    id: root
    property string kcm
    property var module: null
    property bool failed: false
    // Algunos módulos se marcan "con cambios" nada más abrirse: solo cuenta tras tocar algo
    property bool touched: false
    // Recién abierto, el módulo todavía se acomoda: lo que cambie solo no es del usuario
    property bool settled: false
    // Aviso corto después de Aplicar
    property bool justApplied: false
    readonly property bool dirty: !!module && module.needsSave

    // Las listas desplegables de los módulos de KDE: con el estilo de esta app se abrían
    // angostas y vacías. Cada una toma el ancho de su campo.
    property var fixed: []
    function fixCombos(item, depth) {
        if (!item || depth > 40) return
        if (item.popup !== undefined && item.indexOfValue !== undefined && item.popup && fixed.indexOf(item) < 0) {
            fixed.push(item)
            var c = item
            c.popup.width = Qt.binding(function () { return Math.max(c.width, c.popup.implicitWidth) })
        }
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) fixCombos(kids[i], depth + 1)
    }
    function saved() {
        // Los iconos elegidos en la página de KDE quedan como elección de Coucou (si no, el
        // motor de colores los cambiaba al pasar a claro u oscuro)
        if (kcm === "kcm_icons") backend.launch("/usr/lib/coucou/coucou-iconos", ["adopt"])
    }
    function apply() {
        if (!module || !module.needsSave) return
        module.save()
        saved()
        touched = false
        justApplied = true
        appliedTimer.restart()
    }
    Timer { id: settleTimer; interval: 1200; onTriggered: root.settled = true }
    Timer { id: appliedTimer; interval: 2200; onTriggered: root.justApplied = false }
    // Un clic o una tecla en cualquier parte (también en las listas desplegables, que se abren
    // fuera de la página)
    Connections {
        target: backend
        function onUserInput() {
            if (!root.visible || !root.settled) return
            root.touched = true
            if (stack.currentItem) root.fixCombos(stack.currentItem, 0)
        }
    }

    function unload() {
        if (!module) return
        if (module.needsSave && touched) { module.save(); saved() }
        stack.clear(StackView.Immediate)
        backend.unloadKcm(module)
        module = null
    }
    function load() {
        unload()
        failed = false
        touched = false
        settled = false
        justApplied = false
        settleTimer.restart()
        if (!kcm) return
        module = backend.loadKcm(kcm, root)
        if (!module || !module.mainUi) {
            failed = true
            backend.openKcm(kcm)        // se abre en ventana aparte como último recurso
            return
        }
        pushPage(module.mainUi, StackView.Immediate)
        fixed = []
        Qt.callLater(function () { root.fixCombos(module.mainUi, 0) })
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

        // Abajo, siempre: los botones de KDE, con el diseño de esta ventana
        Rectangle {
            readonly property bool hasDefaults: !!root.module && (root.module.buttons & 2) && !root.module.representsDefaults
            readonly property string help: root.module ? backend.kcmHelp(root.kcm) : ""
            visible: !!root.module && !root.failed
            Layout.fillWidth: true
            Layout.topMargin: 8
            implicitHeight: 58
            radius: 8
            color: win.cardBg
            border.color: win.cardBorder
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Button {
                    visible: parent.parent.help !== ""
                    flat: true
                    text: "Ayuda"
                    icon.name: "help-contents"
                    onClicked: backend.openHelp(parent.parent.help)
                }
                Button {
                    visible: parent.parent.hasDefaults
                    flat: true
                    text: "Predeterminados"
                    icon.name: "edit-reset"
                    ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "Volver a los valores que trae KDE"
                    onClicked: { root.touched = true; root.module.defaults() }
                }
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    text: root.justApplied ? "✓ Cambios aplicados" : (root.dirty && root.touched ? "Tienes cambios sin aplicar" : "")
                    color: root.justApplied ? win.accent : win.subtext
                    elide: Text.ElideRight
                }
                Button {
                    text: "Deshacer"
                    enabled: root.dirty && root.touched
                    ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "Volver a como estaba guardado"
                    onClicked: { root.module.load(); root.touched = false }
                }
                Button {
                    text: "Cancelar"
                    ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "Descartar los cambios y volver"
                    onClicked: {
                        if (root.module && root.module.needsSave) root.module.load()
                        root.touched = false
                        win.back()
                    }
                }
                Button {
                    text: "Aplicar"
                    enabled: root.dirty
                    onClicked: root.apply()
                }
                Button {
                    highlighted: true
                    text: "Aceptar"
                    ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "Aplicar y volver"
                    onClicked: {
                        root.apply()
                        win.back()
                    }
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
