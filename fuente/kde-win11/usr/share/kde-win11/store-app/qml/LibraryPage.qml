import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Biblioteca: descargas en curso, actualizaciones y apps instaladas
ScrollView {
    id: page
    contentWidth: availableWidth
    clip: true
    // "downloads": actualizaciones y descargas en curso · "library": apps instaladas
    property string mode: "library"

    readonly property var jobIds: Object.keys(store.jobs)
    // Las de Flathub y las nativas que instaló la tienda (o de apps.conf); no las del sistema como Dolphin
    readonly property var apps: Object.keys(store.installed).map(function (k) { return store.installed[k] })
                                .filter(function (a) { return a.installation !== "native" || a.listed })
                                .sort(function (a, b) { return a.name.localeCompare(b.name) })
    readonly property var updatable: apps.filter(function (a) { return store.updates.indexOf(a.id) >= 0 })

    component Row_: Rectangle {
        id: row
        property var app
        property bool showUpdate: false
        Layout.fillWidth: true
        implicitHeight: 64
        radius: 6
        color: rowArea.containsMouse ? win.cardHover : win.cardBg
        border.color: win.cardBorder
        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: win.openApp(row.app)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 14
            Image {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                source: row.app.icon || "image://icon/application-x-executable"
                sourceSize: Qt.size(72, 72)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: row.app.name; color: win.text; font.pixelSize: 14; elide: Text.ElideRight }
                Label {
                    Layout.fillWidth: true
                    text: [row.app.version ? "Versión " + row.app.version : "", store.formatSize(row.app.size),
                           row.app.originLabel || "",
                           row.app.copies ? "⚠ instalada " + row.app.copies.length + " veces" : ""].filter(Boolean).join("  ·  ")
                    color: row.app.copies ? (win.dark ? "#FCE100" : "#9D5D00") : win.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            ActionButton {
                compact: true
                appId: row.app.id
                appName: row.app.name
            }
            ToolButton {
                visible: !store.jobs[row.app.id]
                icon.source: "image://icon/overflow-menu"
                icon.width: 16; icon.height: 16
                flat: true
                onClicked: menu.popup()
                Menu {
                    id: menu
                    MenuItem { text: "Ver en la Store"; onTriggered: win.openApp(row.app) }
                    MenuItem {
                        text: row.app.copies ? "Quitar copias repetidas…" : "Desinstalar"
                        onTriggered: row.app.copies ? win.openApp(row.app)
                                     : store.uninstall(row.app.id, row.app.installation === "native" ? "native" : "flatpak")
                    }
                }
            }
        }
    }

    ColumnLayout {
        width: page.availableWidth - 52
        x: 32
        spacing: 12

        Label {
            Layout.topMargin: 24
            text: page.mode === "downloads" ? "Descargas" : "Biblioteca"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            color: win.text
        }

        // ---------- Actualizaciones ----------
        Rectangle {
            visible: page.mode === "downloads"
            Layout.fillWidth: true
            implicitHeight: upd.implicitHeight + 40
            radius: 8
            color: win.cardBg
            border.color: win.cardBorder
            RowLayout {
                id: upd
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                Image {
                    source: "image://icon/system-software-update"
                    sourceSize: Qt.size(64, 64)
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: store.checkingUpdates ? "Buscando actualizaciones…"
                              : page.updatable.length + store.componentUpdates > 0
                                ? (page.updatable.length ? page.updatable.length + (page.updatable.length === 1 ? " aplicación tiene" : " aplicaciones tienen") + " actualizaciones"
                                                          : "Hay actualizaciones de componentes")
                                : "Todo está al día"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: win.text
                    }
                    Label {
                        text: (store.componentUpdates ? store.componentUpdates + " componentes del sistema (runtimes) también se actualizarán.  " : "")
                              + (store.lastCheck ? "Última comprobación: hoy a las " + store.lastCheck : "")
                        color: win.subtext
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
                Button {
                    text: "Buscar actualizaciones"
                    enabled: !store.checkingUpdates
                    onClicked: store.checkUpdates()
                }
                Button {
                    visible: page.updatable.length + store.componentUpdates > 0 && !store.jobs["*"]
                    highlighted: true
                    text: "Actualizar todo"
                    onClicked: store.updateAll()
                }
            }
        }

        // ---------- Tareas en curso ----------
        Label {
            visible: page.mode === "downloads" && page.jobIds.length > 0
            Layout.topMargin: 12
            text: "Descargas e instalaciones"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: win.text
        }
        Repeater {
            model: page.mode === "downloads" ? page.jobIds : []
            Rectangle {
                readonly property var job: store.jobs[modelData]
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 6
                color: win.cardBg
                border.color: win.cardBorder
                visible: !!job
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 14
                    Label {
                        Layout.preferredWidth: 220
                        text: parent.parent.job ? parent.parent.job.name : ""
                        color: win.text
                        elide: Text.ElideRight
                    }
                    Label {
                        text: !parent.parent.job ? "" : ({ install: "Instalando", update: "Actualizando", updateall: "Actualizando", uninstall: "Desinstalando" })[parent.parent.job.action]
                        color: win.subtext
                        font.pixelSize: 12
                    }
                    ActionButton {
                        Layout.fillWidth: true
                        compact: true
                        appId: modelData
                    }
                }
            }
        }

        // Apps con actualización pendiente
        Label {
            visible: page.mode === "downloads" && page.updatable.length > 0
            Layout.topMargin: 12
            text: "Actualizaciones disponibles"
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: win.text
        }
        Repeater {
            model: page.mode === "downloads" ? page.updatable : []
            Row_ { app: modelData }
        }
        Label {
            visible: page.mode === "downloads" && page.jobIds.length === 0 && page.updatable.length === 0 && !store.checkingUpdates
            Layout.topMargin: 12
            text: "No hay descargas en curso."
            color: win.subtext
        }

        // ---------- Instaladas ----------
        RowLayout {
            visible: page.mode === "library"
            Layout.topMargin: 12
            Layout.fillWidth: true
            Label {
                text: "Aplicaciones instaladas"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: win.text
            }
            Label {
                text: "(" + page.apps.length + ")"
                color: win.subtext
            }
            Item { Layout.fillWidth: true }
            TextField {
                id: filter
                placeholderText: "Filtrar"
                Layout.preferredWidth: 220
            }
        }
        Repeater {
            model: page.mode !== "library" ? [] : page.apps.filter(function (a) {
                return filter.text === "" || a.name.toLowerCase().indexOf(filter.text.toLowerCase()) >= 0
            })
            Row_ { app: modelData }
        }
        Label {
            visible: page.mode === "library" && page.apps.length === 0
            Layout.topMargin: 12
            text: "Aún no has instalado nada desde la Store. Las apps que obtengas aparecerán aquí."
            color: win.subtext
        }
        Item { Layout.preferredHeight: 24 }
    }
}
