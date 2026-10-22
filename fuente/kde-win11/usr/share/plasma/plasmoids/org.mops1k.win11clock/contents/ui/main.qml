/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.clock
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.mops1k.win11clock.notifications as Notifications

PlasmoidItem {
    id: root

    readonly property bool inPanel: [
        PlasmaCore.Types.TopEdge,
        PlasmaCore.Types.RightEdge,
        PlasmaCore.Types.BottomEdge,
        PlasmaCore.Types.LeftEdge,
    ].includes(Plasmoid.location)

    // Часы: системная зона, секунды — по настройке.
    Clock {
        id: clock
        trackSeconds: root.showSeconds
    }

    // Настройки сервера уведомлений: нужны для режима «Не беспокоить».
    NotificationManager.Settings {
        id: notificationSettings
    }

    // Список уведомлений для поповера. По умолчанию это история, как у
    // системного апплета уведомлений: закрытые и истёкшие уведомления
    // остаются в списке, уведомления, пришедшие в режиме «Не беспокоить»,
    // тоже видны.
    NotificationManager.Notifications {
        id: notificationModel

        limit: Math.max(1, Plasmoid.configuration.notificationLimit)
        showExpired: Plasmoid.configuration.showNotificationHistory
        showDismissed: Plasmoid.configuration.showNotificationHistory
        showJobs: Plasmoid.configuration.showNotificationJobs
        showAddedDuringInhibition: true
        ignoreBlacklistDuringInhibition: true
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: {
            let urgencies = NotificationManager.Notifications.CriticalUrgency
                | NotificationManager.Notifications.NormalUrgency;
            if (Plasmoid.configuration.showLowPriorityNotifications) {
                urgencies |= NotificationManager.Notifications.LowUrgency;
            }
            return urgencies;
        }
    }

    readonly property bool showSeconds: Plasmoid.configuration.showSeconds

    // «Не беспокоить» включён, если сервер уведомлений inhibited
    // (это же состояние показывает системный апплет уведомлений).
    readonly property bool dndEnabled: NotificationManager.Server.valid && NotificationManager.Server.inhibited

    // Форматирование времени: 24ч/12ч + секунды по настройкам.
    function formatTime(dateTime: date): string {
        const pattern = (Plasmoid.configuration.use24hFormat ? "HH:mm" : "h:mm AP")
            + (Plasmoid.configuration.showSeconds ? ":ss" : "");
        return Qt.formatTime(dateTime, pattern);
    }

    // Форматирование даты: короткий/ISO/длинный/свой формат.
    function formatDate(dateTime: date): string {
        let text;
        switch (Plasmoid.configuration.dateFormat) {
        case "isoDate":
            text = Qt.formatDate(dateTime, Qt.ISODate);
            break;
        case "longDate":
            text = Qt.formatDate(dateTime, Qt.locale(), Locale.LongFormat);
            break;
        case "custom":
            text = Qt.locale().toString(dateTime, Plasmoid.configuration.customDateFormat);
            break;
        default:
            text = Qt.formatDate(dateTime, Qt.locale(), Locale.ShortFormat);
            break;
        }

        if (Plasmoid.configuration.showDayOfWeek) {
            return Qt.formatDate(dateTime, "ddd") + ", " + text;
        }
        return text;
    }

    // Включение «Не беспокоить» на год вперёд — так же, как это делает
    // системный апплет уведомлений («пока не выключишь»).
    function setDoNotDisturb(enabled: bool): void {
        if (!NotificationManager.Server.valid) {
            return;
        }

        if (enabled) {
            const until = new Date();
            until.setFullYear(until.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = until;
        } else {
            notificationSettings.notificationsInhibitedUntil = undefined;
            notificationSettings.revokeApplicationInhibitions();
            notificationSettings.screensMirrored = false;
        }
        notificationSettings.save();
    }

    // «Очистить все»: очищаем историю уведомлений (как системный апплет).
    function clearAllNotifications(): void {
        notificationModel.clear(NotificationManager.Notifications.ClearExpired);
    }

    Plasmoid.title: i18n("Clock")
    toolTipMainText: root.formatTime(clock.dateTime)
    toolTipSubText: Plasmoid.configuration.showDate ? root.formatDate(clock.dateTime) : ""

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    Plasmoid.status: notificationModel.unreadNotificationsCount > 0
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    compactRepresentation: CompactRepresentation {
        timeText: root.formatTime(clock.dateTime)
        dateText: root.formatDate(clock.dateTime)
        showDate: Plasmoid.configuration.showDate
        dndEnabled: root.dndEnabled

        property bool wasExpanded: false
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded
    }

    fullRepresentation: CalendarPopup {
        notificationsModel: notificationModel
        dndEnabled: root.dndEnabled
        showDoNotDisturb: Plasmoid.configuration.showDoNotDisturb
        currentDate: clock.dateTime
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        showWeekNumbers: Plasmoid.configuration.showWeekNumbers
        popupAvailableHeight: Plasmoid.containment.availableScreenRect.height

        onClearAllRequested: root.clearAllNotifications()
        onDoNotDisturbRequested: enabled => root.setDoNotDisturb(enabled)
    }

    // Всплывающие уведомления (toast) показывает вендоренный модуль
    // org.mops1k.win11clock.notifications: его синглтон Globals сам создаёт
    // Instantiator попапов и позиционирует их по настройке KCM popupPosition.
    // Апплет отдаёт ему себя, чтобы Globals знал visualParent (компакт-
    // представление в панели) и containment для расчёта геометрии экрана.
    Component.onCompleted: Notifications.Globals.adopt(root)
    Component.onDestruction: Notifications.Globals.forget()


}
