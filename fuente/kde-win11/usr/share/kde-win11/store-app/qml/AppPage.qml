import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Ficha de una app: cabecera con botón principal, capturas, descripción, novedades e información
ScrollView {
    id: page
    property var app: ({})               // datos mínimos (de una tarjeta o de lo instalado)
    readonly property string appId: app.app_id || app.id || ""
    property var info: null              // appstream completo
    property var sizes: null             // /summary: tamaños de descarga e instalación
    property int totalInstalls: 0
    property string error: ""

    readonly property var installed: store.installed[appId.toLowerCase()]
    // De dónde se puede instalar además de Flathub, y lo elegido ("" = el recomendado)
    readonly property var sources: store.sources[appId]
    readonly property bool hasNative: !!sources && (!!sources.repo || !!sources.aur)
    property string chosen: ""
    readonly property string source: chosen || (sources && sources.preferred) || "flathub"
    readonly property var job: store.jobs[appId]
    readonly property string name: (info && info.name) || app.name || appId
    // El de Flathub antes que el del tema para las nativas (el tema puede no tenerlo)
    readonly property string iconUrl: (installed && installed.installation !== "native" && installed.icon) || (info && info.icon) || app.icon
                                      || (installed && installed.icon) || F.iconFor(appId)
    readonly property var shots: info && info.screenshots ? info.screenshots : []
    readonly property var release: info && info.releases && info.releases.length ? info.releases[0] : null

    contentWidth: availableWidth
    contentHeight: column.implicitHeight
    clip: true

    Component.onCompleted: {
        F.details(appId, function (d, err) {
            if (d) info = d; else error = err
            store.findSources(appId, d && d.urls ? d.urls.homepage || "" : "")
        })
        F.summary(appId, function (d) { sizes = d })
        F.stats(appId, function (d) { if (d) totalInstalls = d.installs_total || 0 })
    }

    component Card: Rectangle {
        default property alias content: inner.data
        property int pad: 24
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + pad * 2
        radius: 8
        color: win.cardBg
        border.color: win.cardBorder
        ColumnLayout {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: parent.pad
            spacing: 12
        }
    }
    component Heading: Label {
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: win.text
    }
    component InfoItem: ColumnLayout {
        property string label
        property string value
        property string link
        visible: value !== ""
        spacing: 2
        Layout.preferredWidth: 220
        Label { text: parent.label; color: win.subtext; font.pixelSize: 12 }
        Label {
            Layout.fillWidth: true
            text: parent.link ? "<a href=\"" + parent.link + "\">" + parent.value + "</a>" : parent.value
            textFormat: parent.link ? Text.StyledText : Text.PlainText
            linkColor: win.accent
            color: win.text
            font.pixelSize: 14
            wrapMode: Text.Wrap
            onLinkActivated: function (l) { store.openUrl(l) }
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }

    // Fondo de la cabecera: el icono muy reducido y ampliado da un degradado con sus colores
    Item {
        width: page.availableWidth
        height: 360
        Image {
            anchors.fill: parent
            source: page.iconUrl
            sourceSize: Qt.size(6, 6)
            fillMode: Image.Stretch
            smooth: true
            opacity: win.dark ? 0.45 : 0.35
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(win.layer.r, win.layer.g, win.layer.b, 0.35) }
                GradientStop { position: 1.0; color: win.layer }
            }
        }
    }

    ColumnLayout {
        id: column
        width: page.availableWidth
        spacing: 16

        // ---------- Cabecera ----------
        Card {
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            Layout.topMargin: 24
            pad: 28
            color: Qt.rgba(win.cardBg.r, win.cardBg.g, win.cardBg.b, 0.72)

            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                Image {
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112
                    Layout.alignment: Qt.AlignTop
                    source: page.iconUrl
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        Layout.fillWidth: true
                        text: page.name
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: win.text
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        spacing: 6
                        Label {
                            text: (page.info && page.info.developer_name) || page.app.developer_name || ""
                            color: win.accent
                            font.pixelSize: 14
                        }
                        FluentIcon {
                            visible: !!(page.info && page.info.metadata && page.info.metadata["flathub::verification::verified"] === "true") || !!page.app.verification_verified
                            name: "verified"
                            filled: true
                            size: 16
                            color: win.accent
                            detailColor: "white"
                            ToolTip.visible: verHover.hovered
                            ToolTip.text: "Desarrollador verificado"
                            HoverHandler { id: verHover }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        text: (page.info && page.info.summary) || page.app.summary || ""
                        color: win.subtext
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.topMargin: 8
                        spacing: 24
                        Label {
                            visible: page.totalInstalls > 0
                            text: F.formatCount(page.totalInstalls) + " descargas"
                            color: win.subtext
                            font.pixelSize: 12
                        }
                        Label {
                            text: F.categoryName(page.app.main_categories || (page.info && page.info.categories))
                            color: win.subtext
                            font.pixelSize: 12
                        }
                        Label {
                            visible: page.info && page.info.is_free_license === false
                            text: "Software privativo"
                            color: win.subtext
                            font.pixelSize: 12
                        }
                    }
                    RowLayout {
                        Layout.topMargin: 16
                        spacing: 8
                        ActionButton {
                            appId: page.appId
                            appName: page.name
                            source: page.source
                        }
                        Button {
                            visible: !!page.installed && !page.job && !page.installed.copies
                            text: "Desinstalar"
                            onClicked: confirmUninstall.open()
                        }
                        Label {
                            readonly property var av: store.availability[page.appId]
                            visible: !page.installed && !page.job && page.source === "flathub" && (!!page.sizes || (!!av && av.state === "ok"))
                            // El tamaño real incluye los componentes (runtimes) que aún no tengas
                            text: av && av.state === "ok" && av.size > 0 ? "Ocupará " + store.formatSize(av.size)
                                  : av && av.state === "ok" ? "Listo para instalar"
                                  : page.sizes ? "Descarga de " + store.formatSize(page.sizes.download_size) : ""
                            color: win.subtext
                            font.pixelSize: 12
                            Layout.leftMargin: 8
                        }
                    }

                    // De dónde vino (ya instalada)
                    Label {
                        visible: !!page.installed && !page.job
                        Layout.topMargin: 6
                        text: page.installed ? "Instalada desde " + page.installed.originLabel
                                               + (page.installed.pkg ? "  ·  paquete " + page.installed.pkg : "") : ""
                        color: win.subtext
                        font.pixelSize: 12
                    }

                    // De dónde instalarla: Flathub o nativa (CachyOS / Arch o AUR)
                    ColumnLayout {
                        visible: !page.installed && !page.job
                        Layout.topMargin: 12
                        Layout.fillWidth: true
                        spacing: 6
                        Label {
                            visible: !page.sources || page.sources.state === "checking"
                            text: "Buscando si también hay versión nativa…"
                            color: win.subtext
                            font.pixelSize: 12
                        }
                        RowLayout {
                            visible: page.hasNative
                            spacing: 6
                            Label { text: "Instalar desde:"; color: win.text; font.pixelSize: 13; Layout.rightMargin: 4 }
                            Repeater {
                                model: [{ id: "flathub", title: "Flathub" },
                                        { id: "repo", title: "CachyOS / Arch" },
                                        { id: "aur", title: "AUR" }].filter(function (o) {
                                            return o.id === "flathub" || (page.sources && !!page.sources[o.id]) })
                                delegate: Button {
                                    required property var modelData
                                    checkable: true
                                    checked: page.source === modelData.id
                                    highlighted: checked
                                    flat: !checked
                                    font.pixelSize: 13
                                    text: modelData.title + (page.sources && page.sources.preferred === modelData.id ? "  (recomendado)" : "")
                                    onClicked: page.chosen = modelData.id
                                }
                            }
                        }
                        Label {
                            visible: page.hasNative
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            color: win.subtext
                            font.pixelSize: 12
                            readonly property var r: page.sources && page.sources.repo
                            readonly property var a: page.sources && page.sources.aur
                            text: page.source === "repo" && r
                                  ? "Paquete del sistema: " + r.pkg + " " + r.version + ", de los repositorios oficiales (" + r.repo + "). Pide tu contraseña y se actualiza junto con el sistema."
                                  : page.source === "aur" && a
                                  ? "Paquete de la comunidad: " + a.pkg + " " + a.version + ". Se arma en tu equipo a partir de la receta del AUR; pide tu contraseña y se actualiza junto con el sistema."
                                  : "Aislada del resto del sistema (Flatpak), solo para tu usuario y sin contraseña. Se actualiza desde la tienda."
                        }
                    }
                }
            }
        }

        // ---------- Varias copias (Flathub de usuario y del equipo, nativa): se pelean ----------
        Rectangle {
            id: dupBox
            readonly property var copies: page.installed && page.installed.copies ? page.installed.copies : []
            visible: copies.length > 1 && !page.job
            Layout.fillWidth: true
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            implicitHeight: dupCol.implicitHeight + 24
            radius: 8
            color: win.dark ? "#433519" : "#FFF4CE"
            border.color: win.dark ? "#5C4A1F" : "#F2DC9B"
            ColumnLayout {
                id: dupCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                RowLayout {
                    spacing: 12
                    Label { text: "⚠"; font.pixelSize: 18; color: win.dark ? "#FCE100" : "#9D5D00" }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: win.text
                        text: page.name + " está instalada " + (dupBox.copies.length === 2 ? "dos" : dupBox.copies.length) + " veces: desde "
                              + dupBox.copies.map(function (c) { return c.label }).join(" y desde ")
                              + ". Las copias se pelean (se abren dos veces, usan lo mismo a la vez). Dejá una sola:"
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: dupBox.copies
                        delegate: Button {
                            required property var modelData
                            text: "Quitar la de " + modelData.label + (modelData.pkg ? " (" + modelData.pkg + ")" : "")
                            onClicked: store.uninstall(page.appId, modelData.source)
                        }
                    }
                }
            }
        }

        // ---------- Avisos ----------
        Rectangle {
            readonly property var av: store.availability[page.appId]
            readonly property bool eol: !!(page.info && page.info.is_eol)
            readonly property bool broken: !page.installed && page.source === "flathub" && !!av && av.state === "error"
            visible: eol || broken
            Layout.fillWidth: true
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            implicitHeight: warnRow.implicitHeight + 24
            radius: 8
            color: win.dark ? "#433519" : "#FFF4CE"
            border.color: win.dark ? "#5C4A1F" : "#F2DC9B"
            RowLayout {
                id: warnRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                Label { text: "⚠"; font.pixelSize: 18; color: win.dark ? "#FCE100" : "#9D5D00" }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: win.text
                    text: parent.parent.broken ? "No se puede instalar ahora: " + parent.parent.av.message
                          : "El desarrollador ya no mantiene esta aplicación. Puede dejar de funcionar o no recibir actualizaciones de seguridad."
                }
            }
        }

        // ---------- Capturas ----------
        ColumnLayout {
            visible: page.shots.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            spacing: 10
            Heading { text: "Capturas de pantalla" }
            ListView {
                id: shotList
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                model: page.shots
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar {}
                delegate: Rectangle {
                    height: 248
                    width: shot.status === Image.Ready ? Math.min(560, shot.implicitWidth * height / Math.max(1, shot.implicitHeight)) : 440
                    radius: 8
                    clip: true
                    color: win.cardBg
                    border.color: win.cardBorder
                    Image {
                        id: shot
                        anchors.fill: parent
                        anchors.margins: 1
                        source: F.screenshot(modelData, 624)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    BusyIndicator { anchors.centerIn: parent; running: shot.status === Image.Loading }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { viewer.index = index; viewer.open() }
                    }
                }
            }
        }

        // ---------- Descripción ----------
        Card {
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            visible: !!(page.info && page.info.description)
            Heading { text: "Descripción" }
            Label {
                id: desc
                property bool expanded: false
                Layout.fillWidth: true
                text: page.info ? page.info.description : ""
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: win.text
                font.pixelSize: 14
                lineHeight: 1.15
                maximumLineCount: expanded ? 1000 : 8
                elide: Text.ElideRight
            }
            ToolButton {
                visible: desc.truncated || desc.expanded
                text: desc.expanded ? "Mostrar menos" : "Mostrar más"
                flat: true
                onClicked: desc.expanded = !desc.expanded
            }
        }

        // ---------- Novedades ----------
        Card {
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            visible: !!page.release
            Heading { text: "Novedades en esta versión" }
            Label {
                text: page.release ? "Versión " + page.release.version + (page.release.timestamp ? " · " + F.formatDate(page.release.timestamp) : "") : ""
                color: win.subtext
                font.pixelSize: 13
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: page.release && page.release.description ? page.release.description : ""
                textFormat: Text.RichText
                wrapMode: Text.Wrap
                color: win.text
                font.pixelSize: 14
            }
        }

        // ---------- Información adicional ----------
        Card {
            Layout.leftMargin: 32
            Layout.rightMargin: 32
            Heading { text: "Información adicional" }
            Flow {
                Layout.fillWidth: true
                spacing: 24
                InfoItem { label: "Publicado por"; value: (page.info && page.info.developer_name) || "" }
                InfoItem { label: "Versión"; value: page.installed ? page.installed.version : page.release ? page.release.version : "" }
                InfoItem { label: "Tamaño instalado"; value: page.installed ? store.formatSize(page.installed.size) : page.sizes ? store.formatSize(page.sizes.installed_size) : "" }
                InfoItem { label: "Licencia"; value: (page.info && page.info.project_license) ? page.info.project_license.replace(/LicenseRef-proprietary.*/, "Privativa") : "" }
                InfoItem { label: "Sitio web"; value: page.info && page.info.urls && page.info.urls.homepage ? "Abrir sitio web" : ""; link: page.info && page.info.urls ? page.info.urls.homepage || "" : "" }
                InfoItem { label: "Soporte"; value: page.info && page.info.urls && page.info.urls.bugtracker ? "Informar de un problema" : ""; link: page.info && page.info.urls ? page.info.urls.bugtracker || "" : "" }
                InfoItem { label: "Identificador"; value: page.appId }
                InfoItem { label: "Instalada desde"; value: page.installed ? page.installed.originLabel : "" }
                InfoItem { label: "Paquete"; value: page.installed && page.installed.pkg ? page.installed.pkg : "" }
            }
        }

        Label {
            Layout.leftMargin: 32
            visible: page.error !== "" && !page.info
            text: page.error
            color: win.subtext
        }

        Item { Layout.preferredHeight: 16 }
    }

    // ---------- Visor de capturas ----------
    Popup {
        id: viewer
        property int index: 0
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        background: Rectangle { color: Qt.rgba(0, 0, 0, 0.88) }
        Image {
            anchors.fill: parent
            anchors.margins: 60
            source: viewer.visible ? F.screenshot(page.shots[viewer.index], 1600) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            BusyIndicator { anchors.centerIn: parent; running: parent.status === Image.Loading }
        }
        RoundButton {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            visible: viewer.index > 0
            icon.source: "image://icon/go-previous"
            onClicked: viewer.index--
        }
        RoundButton {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            visible: viewer.index < page.shots.length - 1
            icon.source: "image://icon/go-next"
            onClicked: viewer.index++
        }
        RoundButton {
            anchors.right: parent.right; anchors.top: parent.top
            icon.source: "image://icon/window-close"
            onClicked: viewer.close()
        }
    }

    Dialog {
        id: confirmUninstall
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "¿Desinstalar " + page.name + "?"
        Label {
            text: "Se quitará la aplicación" + (page.installed && page.installed.installation === "native" ? " (pide tu contraseña)" : "")
                  + ". Tu configuración se conserva por si la vuelves a instalar."
            wrapMode: Text.Wrap
            width: 360
        }
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: store.uninstall(page.appId)
        Component.onCompleted: standardButton(Dialog.Ok).text = "Desinstalar"
    }
}
