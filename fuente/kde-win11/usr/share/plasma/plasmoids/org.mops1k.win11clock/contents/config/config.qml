/*
    SPDX-FileCopyrightText: 2026 mops1k
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-system-time"
        source: "config/ConfigGeneral.qml"
    }
}
