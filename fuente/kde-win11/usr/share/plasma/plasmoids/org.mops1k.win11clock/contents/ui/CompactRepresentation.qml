/*
    SPDX-FileCopyrightText: 2026 mops1k

    SPDX-License-Identifier: GPL-3.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Компактное представление часов в панели: время сверху, дата снизу —
// как блок часов в панели задач Windows 11 (по умолчанию прижат к правому
// краю апплета, выравнивание настраивается).
//
// Размер в панели задаётся через Layout.* (панель укладывает компакт
// в Layout и implicitWidth сам по себе не использует) — так же, как это
// делает системный digitalclock.
MouseArea {
    id: root

    required property string timeText
    required property string dateText
    required property bool showDate
    required property bool dndEnabled


    hoverEnabled: true
    activeFocusOnTab: true

    // Размеры шрифтов по умолчанию: время крупнее, дата мельче.
    readonly property int autoTimeSize: Math.max(Kirigami.Theme.defaultFont.pixelSize, Math.round(Kirigami.Units.gridUnit * 0.8))
    readonly property int autoDateSize: Math.max(Kirigami.Theme.smallFont.pixelSize, Math.round(Kirigami.Units.gridUnit * 0.65))

    readonly property string textFontFamily: Plasmoid.configuration.fontFamily.length > 0
        ? Plasmoid.configuration.fontFamily
        : Kirigami.Theme.defaultFont.family
    readonly property color textColor: Plasmoid.configuration.useCustomTextColor
        ? Plasmoid.configuration.textColor
        : Kirigami.Theme.textColor
    readonly property int alignment: Plasmoid.configuration.textAlignment
    readonly property int labelAlignment: root.alignment === 0
        ? Qt.AlignRight
        : (root.alignment === 2 ? Qt.AlignLeft : Qt.AlignHCenter)

    // Отступы содержимого внутри апплета: справа больше, чтобы блок часов
    // и значок «Не беспокоить» не прилипали к краю панели.
    readonly property int leftPadding: Kirigami.Units.smallSpacing * 2
    readonly property int rightPadding: Kirigami.Units.smallSpacing * 3

    readonly property real contentWidth: layout.implicitWidth + root.leftPadding + root.rightPadding
    readonly property real contentHeight: layout.implicitHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Accessible.name: root.showDate ? root.timeText + ", " + root.dateText : root.timeText
    Accessible.role: Accessible.Button

    states: [
        State {
            name: "horizontalPanel"
            when: Plasmoid.formFactor === PlasmaCore.Types.Horizontal

            PropertyChanges {
                root.Layout.fillHeight: true
                root.Layout.fillWidth: false
                root.Layout.minimumWidth: root.contentWidth
                root.Layout.maximumWidth: root.contentWidth
            }
        },
        State {
            name: "verticalPanel"
            when: Plasmoid.formFactor === PlasmaCore.Types.Vertical

            PropertyChanges {
                root.Layout.fillWidth: true
                root.Layout.fillHeight: false
                root.Layout.minimumHeight: root.contentHeight
                root.Layout.maximumHeight: root.contentHeight
            }
        }
    ]

    // Обёртка — обычный Item: у ColumnLayout собственная геометрия, и
    // заданные ему x/y не применялись. Внутри текст уже центрируется.
    Item {
        id: content

        readonly property real textWidth: layout.implicitWidth
        readonly property real textHeight: layout.implicitHeight

        width: textWidth
        height: textHeight
        y: Math.round((root.height - height) / 2)
        x: {
            switch (root.alignment) {
            case 0:
                // вплотную к правому краю апплета с учётом отступа
                return Math.max(0, root.width - width - root.rightPadding);
            case 2:
                return root.leftPadding;
            default:
                return Math.round((root.width - width) / 2);
            }
        }

        RowLayout {
            id: layout

            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                id: clockLayout

                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                PlasmaComponents3.Label {
                    // Строки выравниваются друг относительно друга так же,
                    // как весь блок в апплете: иначе время «висит» по центру
                    // над более широкой датой.
                    Layout.alignment: root.labelAlignment

                    text: root.timeText
                    color: root.textColor
                    font.family: root.textFontFamily
                    font.pixelSize: Plasmoid.configuration.timeFontSizePt > 0 ? Plasmoid.configuration.timeFontSizePt : root.autoTimeSize
                    font.bold: Plasmoid.configuration.boldTime
                }

                PlasmaComponents3.Label {
                    Layout.alignment: root.labelAlignment

                    visible: root.showDate
                    text: root.dateText
                    color: root.textColor
                    opacity: 1 // kde-win11: fecha en blanco, como la hora (Windows 11)
                    font.family: root.textFontFamily
                    font.pixelSize: Plasmoid.configuration.dateFontSizePt > 0 ? Plasmoid.configuration.dateFontSizePt : root.autoDateSize
                }
            }

            // Значок «Не беспокоить» справа от часов — колокольчик с буквой z,
            // как в Windows 11. Появляется только при включённом режиме.
            Item {
                id: dndIndicator

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.round(root.autoDateSize * 1.5)
                Layout.preferredHeight: Math.round(root.autoDateSize * 1.5)
                // kde-win11: la campana se ve siempre, como en Windows 11; la «z» solo con No molestar
                visible: true

                Kirigami.Icon {
                    anchors.fill: parent
                    source: "notifications-symbolic"
                    color: root.textColor
                    isMask: true
                }

                PlasmaComponents3.Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -Math.round(root.autoDateSize * 0.15)
                    anchors.bottomMargin: -Math.round(root.autoDateSize * 0.1)
                    text: "z"
                    visible: root.dndEnabled
                    color: root.textColor
                    font.pixelSize: Math.round(root.autoDateSize * 0.85)
                    font.bold: true
                }
            }
        }
    }
}
