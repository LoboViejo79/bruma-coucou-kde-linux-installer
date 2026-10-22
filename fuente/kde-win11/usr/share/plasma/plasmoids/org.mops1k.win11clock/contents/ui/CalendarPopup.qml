/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// Поповер часов в духе Windows 11: уведомления сверху, календарь снизу.
// Переключатель «Не беспокоить» стоит в шапке справа, напротив надписи
// «Уведомления»; «Очистить все» — строкой под шапкой.
//
// Видимость списка считается по ListView.count: модель уведомлений
// асинхронная, а её countChanged не приходит — ListView же отслеживает
// rowsInserted/rowsRemoved сам.
PlasmaExtras.Representation {
    id: root

    required property var notificationsModel
    required property bool dndEnabled
    required property bool showDoNotDisturb
    required property date currentDate
    required property int firstDayOfWeek
    required property bool showWeekNumbers
    // Высота доступной области экрана (без панели) — из containment, потому что
    // Screen.desktopAvailableHeight у откреплённой панели её не учитывает.
    // Имя с префиксом: у Representation уже есть FINAL-свойство availableHeight.
    required property int popupAvailableHeight

    signal clearAllRequested()
    signal doNotDisturbRequested(bool enabled)

    collapseMarginsHint: true

    // Узкий поповер на всю высоту рабочего стола (как в Windows 11).
    // Именно desktopAvailableHeight, а не Screen.height: иначе попап выше
    // доступной области, не помещается над панелью и перекрывает часы.
    Layout.minimumWidth: Kirigami.Units.gridUnit * 15
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
    // Высота всегда от доступной области текущего экрана (без панели) и
    // обновляется при смене экрана/разрешения/положения панели; минимум
    // не может превышать её на низких экранах.
    // implicitHeight/Layout задают размер окна поповера: AppletPopup берёт
    // size hints из mainItem (Layout.preferredHeight имеет приоритет над
    // implicitHeight). Без них окно сжимается по содержимому.
    implicitHeight: root.popupAvailableHeight
    Layout.minimumHeight: root.popupAvailableHeight
    Layout.preferredHeight: root.popupAvailableHeight
    Layout.maximumHeight: root.popupAvailableHeight

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n("Notifications")
                font.bold: true
            }

            PlasmaComponents3.Switch {
                id: dndSwitch

                visible: root.showDoNotDisturb
                text: i18n("Do not disturb")
                icon.name: "notifications-disabled"
                checked: root.dndEnabled
                onClicked: root.doNotDisturbRequested(checked)
            }
        }
    }

    contentItem: ColumnLayout {
        // Окно поповера считает высоту по содержимому: без этого он
        // сжимается до календаря и не доходит до верха экрана.
        implicitHeight: 400 - root.topPadding - root.bottomPadding
        spacing: Kirigami.Units.smallSpacing

        PlasmaCalendar.EventPluginsManager {
            id: eventPluginsManager
        }

        RowLayout {
            Layout.fillWidth: true
            visible: notificationList.count > 0

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents3.Button {
                flat: true
                text: i18n("Clear all")
                icon.name: "edit-clear-all"
                onClicked: root.clearAllRequested()
            }
        }

        // Список уведомлений тянется на всё свободное место, а календарь
        // остаётся фиксированной высоты — иначе его ячейки растягиваются
        // на весь экран.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3

            ListView {
                id: notificationList

                anchors.fill: parent
                visible: count > 0
                clip: true
                spacing: 0
                model: root.notificationsModel

                // Индикатор прокрутки: уведомлений может быть больше, чем
                // помещается в поповере.
                PlasmaComponents3.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                    id: notificationScrollBar
                    policy: PlasmaComponents3.ScrollBar.AsNeeded
                }

                delegate: NotificationItem {
                    notificationsModel: root.notificationsModel

                    // close(), а не expire(): в режиме истории нужно убирать
                    // уведомление из списка, даже если оно уже истекло.
                    onDismissRequested: root.notificationsModel.close(root.notificationsModel.index(index, 0))
                    onDefaultActionRequested: root.notificationsModel.invokeDefaultAction(root.notificationsModel.index(index, 0))
                }
            }

            PlasmaComponents3.Label {
                anchors.centerIn: parent
                visible: notificationList.count === 0
                opacity: 0.6
                text: i18n("No notifications")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        PlasmaCalendar.MonthView {
            id: monthView

            Layout.fillWidth: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 14
            Layout.preferredHeight: Kirigami.Units.gridUnit * 17

            eventPluginsManager: eventPluginsManager
            today: root.currentDate
            firstDayOfWeek: root.firstDayOfWeek
            showWeekNumbers: root.showWeekNumbers
            showDigitalClockHeader: false
            borderOpacity: 0.25
        }
    }
}
