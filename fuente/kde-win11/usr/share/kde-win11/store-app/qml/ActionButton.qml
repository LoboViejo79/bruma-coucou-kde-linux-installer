import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Botón principal de una app: Obtener → progreso → Abrir / Actualizar
Item {
    id: root
    property string appId
    property string appName
    property bool compact: false
    // De dónde instalar: flathub | repo | aur; vacío = el recomendado para la app (o Flathub)
    property string source: ""
    readonly property var sources: store.sources[appId]
    readonly property string effectiveSource: source || (sources && sources.preferred) || "flathub"

    readonly property var job: store.jobs[appId]
    readonly property var installed: store.installed[appId.toLowerCase()]
    readonly property bool hasUpdate: store.updates.indexOf(appId) >= 0
    // Comprobación previa (sin descargar): si no se puede instalar, no se ofrece "Obtener"
    readonly property var avail: store.availability[appId]
    readonly property bool unavailable: !installed && effectiveSource === "flathub" && !!avail && avail.state === "error"
    onAppIdChanged: if (appId && !installed) store.check(appId)
    Component.onCompleted: if (appId && !installed) store.check(appId)

    implicitWidth: job ? (compact ? 150 : 220) : button.implicitWidth
    implicitHeight: compact ? 32 : 36

    Button {
        id: button
        visible: !root.job
        anchors.fill: parent
        highlighted: (!root.installed && !root.unavailable) || root.hasUpdate
        enabled: !root.unavailable
        text: root.unavailable ? "No disponible" : !root.installed ? "Obtener" : root.hasUpdate ? "Actualizar" : "Abrir"
        ToolTip.visible: root.unavailable && hovered
        ToolTip.text: root.unavailable ? root.avail.message : ""
        font.pixelSize: 14
        leftPadding: root.compact ? 18 : 30
        rightPadding: root.compact ? 18 : 30
        onClicked: {
            if (!root.installed) store.install(root.appId, root.appName, root.source)
            else if (root.hasUpdate) store.update(root.appId)
            else store.launch(root.appId)
        }
    }

    RowLayout {
        visible: !!root.job
        anchors.fill: parent
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Label {
                Layout.fillWidth: true
                text: root.job ? (root.job.state === "queued" ? "En cola"
                                  : root.job.status + (root.job.progress > 0 ? "  " + root.job.progress + " %" : "")) : ""
                font.pixelSize: 12
                color: win.subtext
                elide: Text.ElideRight
            }
            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 100
                value: root.job ? root.job.progress : 0
                indeterminate: !root.job || root.job.state === "queued" || root.job.progress === 0
            }
        }
        ToolButton {
            icon.source: "image://icon/dialog-cancel"
            icon.width: 14; icon.height: 14
            flat: true
            ToolTip.visible: hovered
            ToolTip.text: "Cancelar"
            onClicked: store.cancel(root.appId)
        }
    }
}
