/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.components as PlasmaComponents3

KCM.SimpleKCM {
    id: root

    property alias cfg_use24hFormat: use24hFormatCheck.checked
    property alias cfg_showSeconds: showSecondsCheck.checked
    property alias cfg_showDate: showDateCheck.checked
    property alias cfg_showDayOfWeek: showDayOfWeekCheck.checked
    property alias cfg_showWeekNumbers: showWeekNumbersCheck.checked
    property alias cfg_showDoNotDisturb: showDoNotDisturbCheck.checked
    property alias cfg_notificationLimit: notificationLimitSpin.value
    property alias cfg_showNotificationHistory: showNotificationHistoryCheck.checked
    property alias cfg_showNotificationJobs: showNotificationJobsCheck.checked
    property alias cfg_showLowPriorityNotifications: showLowPriorityNotificationsCheck.checked
    property string cfg_dateFormat
    property alias cfg_customDateFormat: customDateFormatField.text
    property int cfg_textAlignment
    property string cfg_fontFamily: Plasmoid.configuration.fontFamily
    property alias cfg_timeFontSizePt: timeFontSizeSpin.value
    property alias cfg_dateFontSizePt: dateFontSizeSpin.value
    property alias cfg_boldTime: boldTimeCheck.checked
    property alias cfg_useCustomTextColor: customColorCheck.checked
    property color cfg_textColor: Plasmoid.configuration.textColor

    Kirigami.FormLayout {
        anchors.fill: parent

        PlasmaComponents3.CheckBox {
            id: use24hFormatCheck
            Kirigami.FormData.label: i18n("Time:")
            text: i18n("Use 24-hour format")
        }

        PlasmaComponents3.CheckBox {
            id: showSecondsCheck
            Kirigami.FormData.label: ""
            text: i18n("Show seconds")
        }

        PlasmaComponents3.CheckBox {
            id: showDateCheck
            Kirigami.FormData.label: i18n("Date:")
            text: i18n("Show the date below the time")
        }

        PlasmaComponents3.CheckBox {
            id: showDayOfWeekCheck
            Kirigami.FormData.label: ""
            text: i18n("Show day of week")
        }

        QQC2.ComboBox {
            id: dateFormatCombo

            Kirigami.FormData.label: i18n("Date format:")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Short (locale)"), "value": "short" },
                { "text": i18n("ISO (2026-09-27)"), "value": "isoDate" },
                { "text": i18n("Long (locale)"), "value": "longDate" },
                { "text": i18n("Custom"), "value": "custom" },
            ]

            Component.onCompleted: currentIndex = indexOfValue(root.cfg_dateFormat)
            onActivated: root.cfg_dateFormat = currentValue
        }

        QQC2.TextField {
            id: customDateFormatField

            Kirigami.FormData.label: i18n("Custom format:")
            visible: root.cfg_dateFormat === "custom"
            placeholderText: "dd.MM.yyyy"
            onTextEdited: root.cfg_customDateFormat = text
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.ComboBox {
            id: alignmentCombo

            Kirigami.FormData.label: i18n("Position:")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Right (like Windows 11)"), "value": 0 },
                { "text": i18n("Center"), "value": 1 },
                { "text": i18n("Left"), "value": 2 },
            ]

            Component.onCompleted: currentIndex = indexOfValue(root.cfg_textAlignment)
            onActivated: root.cfg_textAlignment = currentValue
        }

        PlasmaComponents3.ComboBox {
            id: familyCombo

            Kirigami.FormData.label: i18n("Font family:")

            readonly property var families: [""].concat(Qt.fontFamilies())
            model: families
            currentIndex: Math.max(0, families.indexOf(root.cfg_fontFamily))
            onActivated: root.cfg_fontFamily = families[currentIndex]
            displayText: currentIndex === 0 ? i18n("Default (from Plasma theme)") : currentText
        }

        PlasmaComponents3.SpinBox {
            id: timeFontSizeSpin

            Kirigami.FormData.label: i18n("Time font size:")
            from: 0
            to: 96
            stepSize: 1
            editable: true
            textFromValue: (value, locale) => value === 0 ? i18n("Automatic") : value + " pt"
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        PlasmaComponents3.SpinBox {
            id: dateFontSizeSpin

            Kirigami.FormData.label: i18n("Date font size:")
            from: 0
            to: 96
            stepSize: 1
            editable: true
            textFromValue: (value, locale) => value === 0 ? i18n("Automatic") : value + " pt"
            valueFromText: (text, locale) => parseInt(text) || 0
        }

        PlasmaComponents3.CheckBox {
            id: boldTimeCheck
            text: i18n("Draw the time in bold")
        }

        PlasmaComponents3.CheckBox {
            id: customColorCheck
            text: i18n("Custom text color")
        }

        Row {
            Kirigami.FormData.label: i18n("Text color:")
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 2
                height: Kirigami.Units.gridUnit
                color: root.cfg_textColor
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents3.Button {
                text: i18n("Choose…")
                enabled: root.cfg_useCustomTextColor
                onClicked: colorDialog.open()
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        PlasmaComponents3.CheckBox {
            id: showWeekNumbersCheck
            Kirigami.FormData.label: i18n("Calendar:")
            text: i18n("Show week numbers")
        }

        PlasmaComponents3.SpinBox {
            id: notificationLimitSpin

            Kirigami.FormData.label: i18n("Popup:")
            from: 1
            to: 200
            stepSize: 1
            editable: true
            textFromValue: (value, locale) => i18np("%1 notification", "%1 notifications", value)
            valueFromText: (text, locale) => parseInt(text) || 1
        }

        PlasmaComponents3.CheckBox {
            id: showNotificationHistoryCheck
            Kirigami.FormData.label: ""
            text: i18n("Keep expired and dismissed notifications (history)")
        }

        PlasmaComponents3.CheckBox {
            id: showLowPriorityNotificationsCheck
            Kirigami.FormData.label: ""
            text: i18n("Show low priority notifications")
        }

        PlasmaComponents3.CheckBox {
            id: showNotificationJobsCheck
            Kirigami.FormData.label: ""
            text: i18n("Show jobs (file transfers, downloads)")
        }

        PlasmaComponents3.CheckBox {
            id: showDoNotDisturbCheck
            Kirigami.FormData.label: ""
            text: i18n("Show “Do not disturb” switch")
        }
    }

    ColorDialog {
        id: colorDialog
        title: i18n("Text color")
        selectedColor: root.cfg_textColor
        onAccepted: root.cfg_textColor = selectedColor
    }
}
