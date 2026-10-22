import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Flathub.js" as F

// Tarjeta de app. Vertical en las filas del inicio; "wide" en cuadrículas y resultados.
Item {
    id: root
    property var app: ({})        // resultado de Flathub (app_id, name, icon, summary, ...)
    property bool wide: false
    readonly property string appId: app.app_id || app.id || ""
    readonly property bool isInstalled: !!store.installed[appId.toLowerCase()]
    readonly property var job: store.jobs[appId]
    readonly property bool hovered: area.containsMouse

    width: wide ? 340 : 176
    height: wide ? 108 : 228

    // Sombra al pasar el ratón (elevación de las tarjetas de la Store)
    Rectangle {
        anchors.fill: card
        anchors.topMargin: 4
        anchors.bottomMargin: -4
        radius: 10
        color: Qt.rgba(0, 0, 0, win.dark ? 0.45 : 0.10)
        opacity: root.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 8
        color: root.hovered ? win.cardHover : win.cardBg
        border.color: root.hovered ? win.cardBorderHover : win.cardBorder
        border.width: 1
        y: root.hovered && !root.wide ? -2 : 0
        scale: area.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        // ---- Vertical ----
        ColumnLayout {
            visible: !root.wide
            anchors.fill: parent
            anchors.margins: 16
            spacing: 4
            AppIcon { size: 80; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; Layout.bottomMargin: 14 }
            Label {
                Layout.fillWidth: true
                text: root.app.name || root.appId
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: win.text
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    Layout.fillWidth: true
                    text: F.categoryName(root.app.main_categories)
                    color: win.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            Item { Layout.fillHeight: true }
            Status { Layout.fillWidth: true }
        }

        // ---- Horizontal ----
        RowLayout {
            visible: root.wide
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            AppIcon { size: 64 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    Layout.fillWidth: true
                    text: root.app.name || root.appId
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: win.text
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: root.app.summary || ""
                    font.pixelSize: 12
                    color: win.subtext
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                Status { Layout.fillWidth: true }
            }
        }
    }

    component AppIcon: Item {
        property int size: 64
        width: size; height: size
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        Image {
            id: img
            anchors.fill: parent
            source: root.app.icon || F.iconFor(root.appId)
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            scale: status === Image.Ready ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            visible: img.status !== Image.Ready
            color: win.dark ? "#383838" : "#ECECEC"
            Image {
                anchors.centerIn: parent
                visible: img.status === Image.Error
                source: "image://icon/application-x-executable"
                sourceSize: Qt.size(64, 64)
                width: parent.width * 0.6; height: width
            }
        }
    }

    // Línea inferior: progreso, "Instalado" o "Gratis" + insignia de verificada
    component Status: Item {
        implicitHeight: 20
        ProgressBar {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.job
            from: 0; to: 100
            value: root.job ? root.job.progress : 0
            indeterminate: !root.job || root.job.progress === 0
        }
        RowLayout {
            anchors.fill: parent
            visible: !root.job
            spacing: 5
            FluentIcon {
                visible: root.isInstalled
                name: "check"
                size: 14
                color: win.accent
            }
            Label {
                text: root.isInstalled ? "Instalado" : "Gratis"
                color: root.isInstalled ? win.accent : win.subtext
                font.pixelSize: 12
                font.weight: root.isInstalled ? Font.DemiBold : Font.Normal
            }
            Item { Layout.fillWidth: true }
            FluentIcon {
                visible: !!root.app.verification_verified
                name: "verified"
                filled: true
                size: 15
                color: win.accent
                detailColor: "white"
                HoverHandler { id: vh }
                ToolTip.visible: vh.hovered
                ToolTip.text: "Desarrollador verificado"
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: win.openApp(root.app)
    }
}
