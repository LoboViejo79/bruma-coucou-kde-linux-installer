/*
    SPDX-FileCopyrightText: 2015 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import QtQuick.Layouts 1.1
import "code/tools.js" as Tools

Item {
    id: item

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight
    clip: true

    enabled: !model.disabled

    property int iconSize
    property bool showLabel: true

    property int itemIndex: model.index
    property string favoriteId: model.favoriteId !== undefined ? model.favoriteId : ""
    property url url: model.url !== undefined ? model.url : ""
    property variant icon: model.decoration !== undefined ? model.decoration : ""
    property var m: model
    property bool isFolderItem: model.itemType === "folder"
    property bool isIndented:   model.indented === true

    property bool hasActionList: {
        if (isFolderItem) return true;
        if (isIndented)   return false;
        return (model.favoriteId !== null) || (("hasActionList" in model) && (model.hasActionList === true));
    }

    property int itemColumns
    property bool labels2lines: false
    Accessible.role: Accessible.MenuItem
    Accessible.name: model.display

    function openActionMenu(x, y) {
        if (isFolderItem) {
            allAppsFolderContextMenu.targetIndex = model.folderIdx;
            allAppsFolderContextMenu.popup();
            return;
        }
        var actionList = (model.actionList !== undefined) ? model.actionList : [];
        Tools.fillActionMenu(i18n, actionMenu, actionList, GridView.view.model.favoritesModel, model.favoriteId);
        actionMenu.visualParent = item;
        actionMenu.open(x, y);
    }

    function actionTriggered(actionId, actionArgument) {
        var close = (Tools.triggerAction(GridView.view.model, model.index, actionId, actionArgument) === true);

        if (close) {
            root.toggle();
        }
    }
    // Left indent for expanded folder children
    property real indentOffset: isIndented ? Kirigami.Units.gridUnit * 1.5 : 0

    // Folder drop highlight ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Kirigami.Units.smallSpacing
        visible: isFolderItem && folderDropArea.containsDrag
        color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
        border.width: 2
        border.color: Kirigami.Theme.highlightColor
        z: 1
    }

    // Drop-onto-folder area (only active for folder items)
    DropArea {
        id: folderDropArea
        anchors.fill: parent
        enabled: isFolderItem
        onDropped: {
            var src = kicker.dragSource;
            if (!src || !src.favoriteId || src.favoriteId === "") return;
            if (src.m && src.m.itemType === "folder") return;
            var favId = src.favoriteId;
            var fi = model.folderIdx;
            if (fi < 0 || fi >= rootItem.allAppsFoldersData.length) return;
            var folders = rootItem.allAppsFoldersData.slice();
            var folder = folders[fi];
            if (!folder || (folder.items && folder.items.indexOf(favId) >= 0)) return;
            var newItems = (folder.items || []).concat([favId]);
            folders[fi] = { name: folder.name, items: newItems, createdAt: folder.createdAt || 0 };
            rootItem.allAppsFoldersData = folders;
            rootItem.saveAllAppsFolders();
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: {
            if (typeof scrollFlickable !== "undefined" && scrollFlickable) {
                scrollFlickable.contentY -= wheel.angleDelta.y
            }
        }
    }
    Kirigami.Icon {
        id: icon
        y: item.showLabel ? (2 * highlightItemSvg.margins.top) : undefined
        anchors.horizontalCenter: isIndented ? undefined : parent.horizontalCenter
        anchors.left:             isIndented ? parent.left : undefined
        anchors.leftMargin:       isIndented ? indentOffset : 0
        anchors.verticalCenter: item.showLabel ? undefined : parent.verticalCenter

        width: isIndented ? iconSize * 0.85 : iconSize
        height: width

        animated: false

        source: model.decoration
    }

    PlasmaComponents3.Label {
        id: label

        visible: item.showLabel

        anchors {
            top: icon.bottom
            topMargin: Kirigami.Units.smallSpacing
            left: parent.left
            leftMargin: isIndented ? (indentOffset + icon.width + Kirigami.Units.smallSpacing) : highlightItemSvg.margins.left
            right: parent.right
            rightMargin: highlightItemSvg.margins.right
        }

        horizontalAlignment: isIndented ? Text.AlignLeft : Text.AlignHCenter

        maximumLineCount: 1
        elide: Text.ElideMiddle
        wrapMode: Text.Wrap

        color: isIndented ? root.colorWithAlpha(Kirigami.Theme.textColor, 0.85) : Kirigami.Theme.textColor

        font.pointSize: isIndented
                        ? Kirigami.Theme.defaultFont.pointSize * 0.9
                        : Kirigami.Theme.defaultFont.pointSize
        text: ("name" in model ? model.name : model.display)
        textFormat: Text.PlainText
    }


    PlasmaCore.ToolTipArea {
        id: toolTip

        property string text: model.display

        anchors.fill: parent
        active: root.visible && label.truncated
        mainItem: toolTipDelegate

        onContainsMouseChanged: item.GridView.view.itemContainsMouseChanged(containsMouse)
    }

    // Folder edit zone: hover-only tracker (clicks pass through to hoverArea which emits folderEditRequested)
    MouseArea {
        id: folderBtnZone
        visible: isFolderItem
        anchors.right: parent.right
        width: Kirigami.Units.gridUnit * 2
        height: parent.height
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 1
    }

    property bool folderEditZoneHovered: isFolderItem && folderBtnZone.containsMouse

    // Visual indicator — non-interactive, top-right corner badge
    Item {
        visible: isFolderItem && folderEditZoneHovered
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
        height: width
        z: 3

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.smallSpacing
            color: root.colorWithAlpha(Kirigami.Theme.highlightColor, 0.18)
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            source: "list-add"
            width: Kirigami.Units.iconSizes.small
            height: width
            animated: false
        }
    }

    // Ctrl+number keyboard shortcut badge
    Rectangle {
        property int pageRelIdx: rootItem.pinnedItemsPerPage > 0
                                 ? model.index % rootItem.pinnedItemsPerPage
                                 : model.index
        visible: !isFolderItem && !isIndented && rootItem.ctrlHeld && pageRelIdx < 9
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        width: Kirigami.Units.gridUnit * 1.4
        height: width
        radius: width / 2
        color: Kirigami.Theme.highlightColor
        z: 3

        Behavior on opacity { NumberAnimation { duration: 80 } }

        Text {
            anchors.centerIn: parent
            text: parent.pageRelIdx + 1
            color: "white"
            font.bold: true
            font.pixelSize: parent.width * 0.52
        }
    }

    // Frequency dot — subtle bottom-left indicator for heavily used pinned apps
    Rectangle {
        property var entry: favoriteId !== "" && typeof rootItem !== "undefined"
                            ? rootItem.launchCounts[favoriteId]
                            : undefined
        property int useCount: {
            if (!entry) return 0;
            if (typeof entry === "number") return entry;
            return entry.total || 0;
        }
        visible: !isFolderItem && !isIndented && useCount >= 3 && !rootItem.ctrlHeld
        width: Kirigami.Units.smallSpacing + 2
        height: width
        radius: width / 2
        color: Kirigami.Theme.positiveTextColor
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: Kirigami.Units.smallSpacing + 2
        anchors.leftMargin: Kirigami.Units.smallSpacing + 2
        opacity: 0.65
        z: 2
    }

    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Menu && hasActionList) {
                            event.accepted = true;
                            openActionMenu(item);
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            event.accepted = true;

                            if (favoriteId !== "" && typeof rootItem !== "undefined") {
                                rootItem.recordLaunch(favoriteId);
                            }

                            if ("trigger" in GridView.view.model) {
                                GridView.view.model.trigger(index, "", null);
                                root.toggle();
                            }

                            itemGrid.itemActivated(index, "", null);
                        }
                    }
}
