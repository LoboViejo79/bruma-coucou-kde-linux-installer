import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.coreaddons 1.0 as KCoreAddons
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.plasma.private.sessions

// Pie del menú Inicio estilo Windows 11: usuario a la izquierda;
// Archivos, Configuración y botón de inicio/apagado (con menú) a la derecha.
RowLayout {
    id: footerRow
    spacing: Kirigami.Units.smallSpacing

    signal tabOut

    Keys.onTabPressed: event => {
        event.accepted = true;
        tabOut();
    }

    KCoreAddons.KUser { id: kuser }
    SessionManagement { id: sessionManager }

    // Usuario (foto redonda + nombre)
    AbstractButton {
        id: userButton
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Kirigami.Units.gridUnit
        implicitHeight: Kirigami.Units.gridUnit * 2.2
        implicitWidth: userRow.implicitWidth + Kirigami.Units.largeSpacing * 2
        hoverEnabled: true
        onClicked: executable.exec("kcmshell6 kcm_users")

        background: Rectangle {
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: userButton.hovered ? 0.08 : 0
        }

        contentItem: RowLayout {
            id: userRow
            spacing: Kirigami.Units.largeSpacing

            KirigamiComponents.Avatar {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: kuser.faceIconUrl
                name: kuser.fullName || kuser.loginName
            }

            PlasmaComponents3.Label {
                text: kuser.fullName || kuser.loginName
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
            }
        }
    }

    Item { Layout.fillWidth: true }

    PlasmaComponents3.ToolButton {
        icon.name: "system-file-manager"
        display: AbstractButton.IconOnly
        PlasmaComponents3.ToolTip.text: i18n("Open Files")
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.delay: 600
        onClicked: { executable.exec("dolphin"); root.toggle(); }
    }

    PlasmaComponents3.ToolButton {
        icon.name: "configure"
        display: AbstractButton.IconOnly
        PlasmaComponents3.ToolTip.text: i18n("System Settings")
        PlasmaComponents3.ToolTip.visible: hovered
        PlasmaComponents3.ToolTip.delay: 600
        onClicked: { executable.exec(root.settingsCmd); root.toggle(); }
    }

    PlasmaComponents3.ToolButton {
        id: powerButton
        Layout.rightMargin: Kirigami.Units.gridUnit
        icon.name: "system-shutdown"
        display: AbstractButton.IconOnly
        PlasmaComponents3.ToolTip.text: i18n("Shutdown")
        PlasmaComponents3.ToolTip.visible: hovered && !powerMenu.visible
        PlasmaComponents3.ToolTip.delay: 600
        onClicked: powerMenu.visible ? powerMenu.close() : powerMenu.open()

        PlasmaComponents3.Menu {
            id: powerMenu
            y: -height - Kirigami.Units.smallSpacing
            x: powerButton.width - width

            PlasmaComponents3.MenuItem {
                text: i18n("Lock Screen")
                icon.name: "system-lock-screen"
                visible: sessionManager.canLock
                height: visible ? implicitHeight : 0
                onTriggered: { root.toggle(); sessionManager.lock(); }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Log out")
                icon.name: "system-log-out"
                visible: sessionManager.canLogout
                height: visible ? implicitHeight : 0
                onTriggered: { root.toggle(); sessionManager.requestLogout(); }
            }
            PlasmaComponents3.MenuSeparator {}
            PlasmaComponents3.MenuItem {
                text: i18n("Sleep")
                icon.name: "system-suspend"
                visible: sessionManager.canSuspend && Plasmoid.configuration.showSleepButton
                height: visible ? implicitHeight : 0
                onTriggered: { root.toggle(); sessionManager.suspend(); }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Restart")
                icon.name: "system-reboot"
                visible: sessionManager.canReboot && Plasmoid.configuration.showRestartButton
                height: visible ? implicitHeight : 0
                onTriggered: { root.toggle(); sessionManager.requestReboot(); }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Shutdown")
                icon.name: "system-shutdown"
                visible: sessionManager.canShutdown && Plasmoid.configuration.showShutdownButton
                height: visible ? implicitHeight : 0
                onTriggered: { root.toggle(); sessionManager.requestShutdown(); }
            }
        }
    }
}
