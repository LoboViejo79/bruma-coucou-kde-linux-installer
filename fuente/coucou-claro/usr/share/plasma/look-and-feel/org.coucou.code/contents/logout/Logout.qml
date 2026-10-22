/*
    Coucou Code: apagar, reiniciar, suspender y cerrar sesión, al estilo del
    iPhone. El escritorio se oscurece y quedan cuatro botones redondos de
    vidrio con su nombre debajo; "Cancelar" o Escape vuelven. Si Plasma pidió
    una acción concreta (Apagar, Reiniciar…), cuenta los segundos y la hace.
    Las señales son las del diálogo de Plasma (ksmserver-logout-greeter).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions
import Qt5Compat.GraphicalEffects
import "timer.js" as AutoTriggerTimer

Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    readonly property string font: "Inter"
    property real timeout: 30
    property real remainingTime: root.timeout
    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    property bool shown: false

    property var currentAction: {
        switch (sdtype) {
        case ShutdownType.ShutdownTypeReboot:
            return () => softwareUpdatePending ? rebootUpdateRequested() : rebootRequested();
        case ShutdownType.ShutdownTypeHalt:
            return () => softwareUpdatePending ? haltUpdateRequested() : haltRequested();
        default:
            return () => logoutRequested();
        }
    }

    KCoreAddons.KUser { id: kuser }

    QQC2.Action { onTriggered: root.cancelRequested(); shortcut: "Escape" }

    onRemainingTimeChanged: if (remainingTime <= 0) (currentAction)()

    Timer {
        id: countDownTimer
        running: !showAllOptions
        repeat: true
        interval: 1000
        onTriggered: remainingTime--
        Component.onCompleted: AutoTriggerTimer.addCancelAutoTriggerCallback(function () { countDownTimer.running = false })
    }

    // El escritorio, oscurecido
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#E0141233" }
            GradientStop { position: 1; color: "#F00A0920" }
        }
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }

    Column {
        anchors.centerIn: parent
        spacing: 26
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        // Foto (o Mochi) y nombre
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#33FFFFFF" }
            Image {
                id: face
                property bool photo: String(kuser.faceIconUrl) !== "" && status !== Image.Error
                anchors.fill: parent
                anchors.margins: photo ? 0 : 13
                source: String(kuser.faceIconUrl) !== "" ? kuser.faceIconUrl : "mochi.png"
                onStatusChanged: if (status === Image.Error) source = "mochi.png"
                fillMode: Image.PreserveAspectCrop
                layer.enabled: photo
                layer.effect: OpacityMask { maskSource: Rectangle { width: face.width; height: face.height; radius: width / 2 } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: countDownTimer.running ? countdownText() : (kuser.fullName || kuser.loginName)
            color: "#FFFFFF"; font.family: root.font; font.pixelSize: 19; font.weight: Font.DemiBold
            function countdownText() {
                const s = Math.max(0, Math.round(root.remainingTime))
                switch (sdtype) {
                case ShutdownType.ShutdownTypeReboot: return "Reiniciando en " + s + " s"
                case ShutdownType.ShutdownTypeNone: return "Cerrando la sesión en " + s + " s"
                default: return "Apagando en " + s + " s"
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 34
            Repeater {
                model: [
                    { glyph: "☾", label: "Suspender", act: "sleep", show: spdMethods.SuspendState && root.showAllOptions },
                    { glyph: "↻", label: "Reiniciar", act: "reboot", show: maysd && (sdtype === ShutdownType.ShutdownTypeReboot || root.showAllOptions) },
                    { glyph: "⏻", label: "Apagar", act: "halt", show: maysd && (sdtype === ShutdownType.ShutdownTypeHalt || root.showAllOptions) },
                    { glyph: "⇥", label: "Cerrar sesión", act: "logout", show: canLogout && (sdtype === ShutdownType.ShutdownTypeNone || root.showAllOptions) }
                ]
                delegate: Column {
                    visible: modelData.show
                    spacing: 10
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 76; height: 76; radius: 38
                        color: m.pressed ? "#66FFFFFF" : (m.containsMouse || activeFocus ? "#47FFFFFF" : "#2BFFFFFF")
                        scale: m.pressed ? 0.92 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: modelData.glyph; color: "#FFFFFF"; font.pixelSize: 28 }
                        MouseArea {
                            id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.act === "sleep") root.suspendRequested(2)
                                else if (modelData.act === "reboot") softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested()
                                else if (modelData.act === "halt") softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested()
                                else root.logoutRequested()
                            }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: "#EEFFFFFF"; font.family: root.font; font.pixelSize: 13; font.weight: Font.Medium
                    }
                }
            }
        }

        // Cancelar
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 140; height: 40; radius: 20
            color: c.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
            Text { anchors.centerIn: parent; text: "Cancelar"; color: "#FFFFFF"; font.family: root.font; font.pixelSize: 14; font.weight: Font.Medium }
            MouseArea { id: c; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelRequested() }
        }
    }

    Keys.onPressed: AutoTriggerTimer.cancelAutoTrigger()
    Component.onCompleted: { root.shown = true; root.forceActiveFocus() }
}
