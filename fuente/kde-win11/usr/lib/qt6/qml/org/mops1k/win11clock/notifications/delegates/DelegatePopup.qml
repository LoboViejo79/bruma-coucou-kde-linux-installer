/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

// kde-win11: notificación emergente con el diseño de Windows 11
//   ┌──────────────────────────────────────────┐
//   │ [▪] Nombre de la app              ···  ✕ │  ← los botones aparecen al pasar el ratón
//   │ ┌────┐ Título en negrita                 │
//   │ │ 48 │ Texto del mensaje, en gris claro, │
//   │ └────┘ hasta varias líneas               │
//   │ [   Acción 1   ] [   Acción 2   ]        │
//   └──────────────────────────────────────────┘
// Sin barra de tiempo restante ni cabecera separada, como en Windows.

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons

import org.kde.notificationmanager as NotificationManager
import org.mops1k.win11clock.notifications as Notifications

import "../components" as Components


BaseDelegate {
    id: delegateRoot

    // El ratón está sobre la notificación: muestra ··· y ✕ (lo pone NotificationPopup)
    property bool popupHovered: false

    Layout.preferredWidth: (footerLoader.item as Item)?.implicitWidth ?? -1

    body: bodyLabel
    icon: icon
    footer: footerLoader.item as Item
    columns: 2

    rowSpacing: 0
    columnSpacing: Kirigami.Units.largeSpacing

    Accessible.role: Accessible.Notification

    readonly property bool __critical: modelInterface.urgency === NotificationManager.Notifications.CriticalUrgency

    // --- Cabecera: icono pequeño + nombre de la app, botones a la derecha ---------
    RowLayout {
        id: heading
        Layout.fillWidth: true
        Layout.row: 0
        Layout.columnSpan: 2
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: delegateRoot.modelInterface.applicationIconSource
            visible: valid
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: delegateRoot.modelInterface.applicationName
                  + (delegateRoot.modelInterface.originName ? " · " + delegateRoot.modelInterface.originName : "")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
            opacity: 0.8
        }

        // Aviso importante (urgencia crítica): punto de color, sin la franja lateral de KDE
        Rectangle {
            visible: delegateRoot.__critical
            implicitWidth: Kirigami.Units.smallSpacing * 2
            implicitHeight: implicitWidth
            radius: width / 2
            color: Kirigami.Theme.neutralTextColor
        }

        Row {
            id: headingButtons
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            // Como en Windows: ocultos hasta pasar el ratón (siguen respondiendo al teclado y lector de pantalla)
            opacity: delegateRoot.popupHovered || configureButton.activeFocus || dismissButton.activeFocus || closeButton.activeFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

            PlasmaComponents3.ToolButton {
                id: configureButton
                visible: delegateRoot.modelInterface.configurable
                icon.name: "view-more-horizontal-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: delegateRoot.modelInterface.configureActionLabel || i18nd("plasma_applet_org.kde.plasma.notifications", "Configure")
                onClicked: delegateRoot.modelInterface.configureClicked()
                PlasmaComponents3.ToolTip { text: configureButton.text }
            }

            PlasmaComponents3.ToolButton {
                id: dismissButton
                visible: delegateRoot.modelInterface.dismissable
                icon.name: delegateRoot.modelInterface.dismissed ? "window-restore-symbolic" : "window-minimize-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: delegateRoot.modelInterface.dismissed
                    ? i18ndc("plasma_applet_org.kde.plasma.notifications", "Opposite of minimize", "Restore")
                    : i18nd("plasma_applet_org.kde.plasma.notifications", "Minimize")
                onClicked: delegateRoot.modelInterface.dismissClicked()
                PlasmaComponents3.ToolTip { text: dismissButton.text }
            }

            PlasmaComponents3.ToolButton {
                id: closeButton
                visible: delegateRoot.modelInterface.closable
                icon.name: "window-close-symbolic"
                display: PlasmaComponents3.AbstractButton.IconOnly
                text: delegateRoot.modelInterface.closeButtonToolTip || i18nd("plasma_applet_org.kde.plasma.notifications", "Close")
                onClicked: delegateRoot.modelInterface.closeClicked()
                PlasmaComponents3.ToolTip { text: closeButton.text }
            }
        }
    }

    // --- Imagen grande a la izquierda (foto del remitente, portada, icono…) --------
    Components.Icon {
        id: icon
        Layout.row: 1
        Layout.column: 0
        Layout.rowSpan: 2
        Layout.topMargin: Kirigami.Units.smallSpacing / 2
        modelInterface: delegateRoot.modelInterface
    }

    // --- Título y texto ------------------------------------------------------------
    Components.Summary {
        id: summary
        Layout.fillWidth: true
        Layout.row: 1
        Layout.column: icon.visible ? 1 : 0
        Layout.columnSpan: icon.visible ? 1 : 2
        font.weight: Font.DemiBold
        modelInterface: delegateRoot.modelInterface

        KQuickControlsAddons.MouseEventListener {
            anchors.fill: parent
            visible: delegateRoot.modelInterface.hasDefaultAction && !delegateRoot.hasBodyText
            onClicked: delegateRoot.modelInterface.defaultActionInvoked();
        }
    }

    KQuickControlsAddons.MouseEventListener {
        Layout.topMargin: summary.visible ? Kirigami.Units.smallSpacing / 2 : 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.row: summary.visible ? 2 : 1
        Layout.column: icon.visible ? 1 : 0
        Layout.columnSpan: icon.visible ? 1 : 2
        Layout.maximumHeight: Kirigami.Units.gridUnit * delegateRoot.modelInterface.maximumLineCount
        // The body doesn't need to influence the implicit width in any way, this avoids a binding loop
        implicitWidth: -1
        implicitHeight: scroll.implicitHeight
        visible: delegateRoot.hasBodyText
        onClicked: {
            if (delegateRoot.modelInterface.hasDefaultAction && !delegateRoot.hoveredLink) {
                delegateRoot.modelInterface.defaultActionInvoked();
            }
        }
        PlasmaComponents3.ScrollView {
            id: scroll
            anchors.fill: parent
            contentWidth: bodyLabel.width

            // This avoids a binding loop
            PlasmaComponents3.ScrollBar.vertical.visible: delegateRoot.modelInterface.maximumLineCount > 0 && bodyLabel.implicitHeight > parent.Layout.maximumHeight
            PlasmaComponents3.ScrollBar.horizontal.visible: false

            Components.Body {
                id: bodyLabel
                width: scroll.width - scroll.PlasmaComponents3.ScrollBar.vertical.width
                // Texto secundario, algo más tenue que el título, como en Windows
                opacity: 0.8
                modelInterface: delegateRoot.modelInterface
                Accessible.ignored: true // ignore HTML body in favor of Accessible.description on delegateRoot
            }
        }
    }

    // --- Botones de acción, respuesta, miniaturas o progreso de una tarea --------------
    Components.FooterLoader {
        id: footerLoader
        Layout.fillWidth: true
        Layout.row: 3
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.topMargin: visible ? Kirigami.Units.largeSpacing : 0
        modelInterface: delegateRoot.modelInterface
        iconContainerItem: icon
    }
}
