/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.coreaddons as KCoreAddons
import org.kde.kquickcontrolsaddons as KQuickAddons
import org.kde.notificationmanager as NotificationManager

// Строка уведомления в поповере: иконка приложения, заголовок, текст,
// относительное время, превью-картинка, прогресс задания и кнопки действий
// (как в системном апплете уведомлений).
PlasmaComponents3.ItemDelegate {
    id: root

    required property var notificationsModel

    required property int index
    required property int type
    required property string summary
    required property string body
    required property string applicationName
    required property string applicationIconName
    required property var iconName
    required property var image
    required property date created
    required property bool closable
    required property bool configurable
    required property string configureActionLabel
    required property bool hasDefaultAction
    required property string defaultActionLabel
    required property list<string> actionNames
    required property list<string> actionLabels
    required property bool hasReplyAction
    required property string replyActionLabel
    required property string replyPlaceholderText
    required property int jobState
    required property int percentage
    required property string jobError
    required property bool suspendable
    required property bool killable

    readonly property bool isJob: root.type === NotificationManager.Notifications.JobType
    readonly property var modelIndex: root.notificationsModel.index(root.index, 0)
    // image из org.kde.notificationmanager — это QImage, а не URL: обычный
    // Image его не отображает, поэтому используется QImageItem.
    readonly property bool hasImage: typeof root.image === "object" && root.image !== null
    readonly property bool hasActions: root.actionLabels.length > 0 || root.hasDefaultAction
        || root.configurable || root.hasReplyAction || root.isJob
    // jobError — код ошибки: 0 значит «ошибки нет», его показывать не нужно.
    readonly property bool hasJobError: {
        const code = String(root.jobError ?? "");
        if (code.length === 0) {
            return false;
        }
        const numeric = Number(code);
        return isNaN(numeric) ? true : numeric !== 0;
    }

    signal dismissRequested()
    signal defaultActionRequested()

    width: ListView.view ? ListView.view.width : implicitWidth
    hoverEnabled: true

    // KNotification отдаёт тело как HTML-документ: убираем XML-декларацию
    // и внешние <html>, чтобы StyledText показал содержимое, а не теги.
    function cleanText(text: string): string {
        let result = String(text ?? "");
        result = result.replace(/^<\?xml[^>]*\?>\s*/i, "");
        result = result.replace(/^<html[^>]*>/i, "").replace(/<\/html>\s*$/i, "");
        return result;
    }

    onClicked: {
        if (root.hasDefaultAction) {
            root.defaultActionRequested();
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: root.applicationIconName || root.iconName || "dialog-information"
                animated: false
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: root.cleanText(root.summary)
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.StyledText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.cleanText(root.body)
                    opacity: 0.8
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: {
                        const ago = KCoreAddons.Format.formatRelativeDateTime(root.created, Locale.ShortFormat);
                        return root.applicationName ? root.applicationName + " · " + ago : ago;
                    }
                }
            }

            PlasmaComponents3.ToolButton {
                Layout.alignment: Qt.AlignTop
                visible: root.closable
                icon.name: "window-close"
                text: i18n("Dismiss")
                display: PlasmaComponents3.AbstractButton.IconOnly
                onClicked: root.dismissRequested()

                PlasmaComponents3.ToolTip {
                    text: parent.text
                }
            }
        }

        // Превью-картинка (скриншоты, обложки и т.п.)
        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: root.hasImage ? Kirigami.Units.gridUnit * 8 : 0
            visible: root.hasImage
            active: root.hasImage
            sourceComponent: KQuickAddons.QImageItem {
                image: root.image
                fillMode: KQuickAddons.QImageItem.PreserveAspectFit
                smooth: true
            }
        }

        // Задание: прогресс, процент и ошибка
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.isJob
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: Math.max(0, root.percentage)
                }

                PlasmaComponents3.Label {
                    text: i18nc("@info:progress percentage of a running job", "%1%", Math.round(root.percentage))
                    font: Kirigami.Theme.smallFont
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: root.hasJobError
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
                text: root.jobError
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Кнопки действий уведомления и задания
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: root.hasActions

            Repeater {
                model: root.actionLabels

                PlasmaComponents3.Button {
                    required property int index
                    required property string modelData

                    text: modelData
                    onClicked: root.notificationsModel.invokeAction(root.modelIndex, root.actionNames[index],
                        NotificationManager.Notifications.Close)
                }
            }

            PlasmaComponents3.Button {
                visible: root.hasDefaultAction && !root.isJob
                text: root.defaultActionLabel || i18n("Open")
                onClicked: root.defaultActionRequested()
            }

            PlasmaComponents3.Button {
                visible: root.configurable
                text: root.configureActionLabel || i18n("Details")
                onClicked: root.notificationsModel.configure(root.modelIndex)
            }

            PlasmaComponents3.Button {
                visible: root.isJob && root.suspendable
                text: root.jobState === NotificationManager.Notifications.JobStateSuspended
                    ? i18n("Resume") : i18n("Pause")
                onClicked: {
                    if (root.jobState === NotificationManager.Notifications.JobStateSuspended) {
                        root.notificationsModel.resumeJob(root.modelIndex);
                    } else {
                        root.notificationsModel.suspendJob(root.modelIndex);
                    }
                }
            }

            PlasmaComponents3.Button {
                visible: root.isJob && root.killable
                text: i18n("Cancel")
                onClicked: root.notificationsModel.killJob(root.modelIndex)
            }
        }

        // Ответ на уведомление (мессенджеры)
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasReplyAction

            PlasmaComponents3.TextField {
                id: replyField

                Layout.fillWidth: true
                placeholderText: root.replyPlaceholderText || i18n("Reply…")
            }

            PlasmaComponents3.Button {
                text: root.replyActionLabel || i18n("Send")
                enabled: replyField.text.length > 0
                onClicked: {
                    root.notificationsModel.reply(root.modelIndex, replyField.text,
                        NotificationManager.Notifications.Close);
                    replyField.text = "";
                }
            }
        }
    }
}
