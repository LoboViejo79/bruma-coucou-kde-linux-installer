/*
    SPDX-FileCopyrightText: 2018-2019 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2024 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickAddons

Kirigami.Icon {
    id: iconItem
    Layout.alignment: Qt.AlignTop

    property ModelInterface modelInterface
    readonly property bool dragging: (jobIconLoader.item as JobIconItem)?.dragging ?? false

    // image из notificationmanager — QImage, Kirigami.Icon его не рисует:
    // такое превью показывается отдельным QImageItem.
    readonly property bool hasImageData: typeof modelInterface.icon === "object" && modelInterface.icon !== null

    implicitWidth: Kirigami.Units.iconSizes.large
    implicitHeight: Kirigami.Units.iconSizes.large

    source: !hasImageData && modelInterface.icon !== modelInterface.applicationIconSource ? modelInterface.icon : null
    // don't show two identical icons
    visible: valid || hasImageData || ((jobIconLoader.item as JobIconItem)?.shown ?? false)

    smooth: true

    Loader {
        anchors.fill: parent
        active: iconItem.hasImageData
        sourceComponent: KQuickAddons.QImageItem {
            image: iconItem.modelInterface.icon
            fillMode: KQuickAddons.QImageItem.PreserveAspectFit
            smooth: true
        }
    }

    Loader {
        id: jobIconLoader
        anchors.fill: parent
        active: iconItem.modelInterface.jobDetails?.effectiveDestUrl ?? false
        sourceComponent: JobIconItem {
            modelInterface: iconItem.modelInterface
        }
    }
}

