// Inicio de sesión estilo Windows 11 para SDDM (Qt 6)
// Pantalla de bloqueo con reloj grande -> clic o tecla -> fondo desenfocado,
// foto redonda, nombre y campo de contraseña. Abajo a la derecha: teclado, sesión y apagado.

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root
    width: 1920
    height: 1080

    readonly property real s: Math.max(0.75, Math.min(width / 1920, height / 1080) * 1.1)
    readonly property string fontName: config.font || "Selawik"
    readonly property color accent: config.accentColor || "#0067c0"

    property bool unlocked: false
    property bool busy: false
    property string errorText: ""
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string userName: ""
    property string userRealName: ""
    property string userIcon: ""

    function showLogin() {
        if (unlocked)
            return
        unlocked = true
        idle.restart()
        password.forceActiveFocus()
    }
    function showLock() {
        unlocked = false
        errorText = ""
        password.text = ""
        powerMenu.close()
        sessionMenu.close()
        root.forceActiveFocus()
    }
    function doLogin() {
        if (busy || errorText !== "")
            return
        busy = true
        sddm.login(userName, password.text, sessionIndex)
    }

    // Datos del usuario elegido: se leen a través de un Repeater invisible
    Repeater {
        model: userModel
        delegate: Item {
            visible: false
            Component.onCompleted: if (index === root.userIndex) apply()
            Connections {
                target: root
                function onUserIndexChanged() { if (index === root.userIndex) apply() }
            }
            function apply() {
                root.userName = model.name
                root.userRealName = model.realName || model.name
                root.userIcon = model.icon || ""
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            busy = false
            password.text = ""
            errorText = qsTr("La contraseña no es correcta. Inténtalo de nuevo.")
            errorOk.forceActiveFocus()
        }
        function onLoginSucceeded() { }
    }

    // Vuelve a la pantalla de bloqueo tras un rato sin tocar nada
    Timer {
        id: idle
        interval: 60000
        running: root.unlocked && !root.busy
        onTriggered: root.showLock()
    }

    focus: true
    Keys.onPressed: function (e) {
        if (!root.unlocked) {
            root.showLogin()
            e.accepted = true
        }
    }

    // ---------- Fondo ----------
    Image {
        id: bg
        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        sourceSize.width: 2560
    }
    Image {
        anchors.fill: parent
        source: config.backgroundBlur || "background-blur.jpg"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 2560
        opacity: root.unlocked ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.unlocked ? 0.28 : 0.08
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.unlocked
        onClicked: root.showLogin()
    }

    // ---------- Pantalla de bloqueo: reloj ----------
    Item {
        id: lockView
        anchors.fill: parent
        opacity: root.unlocked ? 0 : 1
        visible: opacity > 0
        transform: Translate { y: root.unlocked ? -60 * root.s : 0
            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.13
            spacing: 2 * root.s

            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontName
                font.pixelSize: 132 * root.s
                font.weight: Font.DemiBold
                color: "white"
                text: Qt.formatTime(now.date, "H:mm")
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: 0.35; shadowBlur: 0.6; shadowVerticalOffset: 2 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontName
                font.pixelSize: 26 * root.s
                color: "white"
                text: {
                    const t = Qt.locale().toString(now.date, "dddd, d 'de' MMMM")
                    return t.charAt(0).toUpperCase() + t.slice(1)
                }
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowOpacity: 0.35; shadowBlur: 0.5; shadowVerticalOffset: 1 }
            }
        }
    }

    QtObject {
        id: now
        property date date: new Date()
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: now.date = new Date()
    }

    // ---------- Inicio de sesión ----------
    Item {
        id: loginView
        anchors.fill: parent
        opacity: root.unlocked ? 1 : 0
        visible: opacity > 0
        scale: root.unlocked ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -40 * root.s
            spacing: 0

            // Foto redonda
            Item {
                id: avatarBox
                anchors.horizontalCenter: parent.horizontalCenter
                width: 192 * root.s
                height: width

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: root.userIcon !== "" ? root.userIcon : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    smooth: true
                }
                Item {
                    id: avatarMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: avatarImg
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    visible: avatarImg.status === Image.Ready
                }
                Image {
                    anchors.fill: parent
                    source: "icons/user.svg"
                    sourceSize: Qt.size(width, height)
                    visible: avatarImg.status !== Image.Ready
                }
            }

            Item { width: 1; height: 22 * root.s }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.fontName
                font.pixelSize: 30 * root.s
                font.weight: Font.DemiBold
                color: "white"
                text: root.userRealName
            }

            Item { width: 1; height: 26 * root.s }

            // Campo de contraseña / mensaje de error / "Te damos la bienvenida"
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300 * root.s
                height: 88 * root.s

                // Campo
                Rectangle {
                    id: field
                    visible: root.errorText === "" && !root.busy
                    width: parent.width
                    height: 38 * root.s
                    radius: 5 * root.s
                    color: password.activeFocus ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(0, 0, 0, 0.30)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    Rectangle {   // línea inferior: azul al escribir, como en WinUI
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 1
                        height: password.activeFocus ? 2 : 1
                        color: password.activeFocus ? "#60cdff" : Qt.rgba(1, 1, 1, 0.55)
                    }

                    TextField {
                        id: password
                        anchors.left: parent.left
                        anchors.right: reveal.left
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 12 * root.s
                        rightPadding: 4
                        echoMode: reveal.pressed ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        font.family: root.fontName
                        // puntos algo más grandes que el texto, como en Windows
                        font.pixelSize: (echoMode === TextInput.Password && text.length > 0 ? 16 : 15) * root.s
                        color: "white"
                        placeholderText: qsTr("Contraseña")
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.75)
                        selectionColor: root.accent
                        background: null
                        onAccepted: root.doLogin()
                        onTextChanged: idle.restart()
                        Keys.onEscapePressed: root.showLock()
                    }

                    // Mantener pulsado para ver la contraseña
                    AbstractButton {
                        id: reveal
                        anchors.right: submit.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32 * root.s; height: 30 * root.s
                        visible: password.text.length > 0
                        focusPolicy: Qt.NoFocus
                        background: Rectangle { radius: 4; color: reveal.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent" }
                        contentItem: Image {
                            source: "icons/eye.svg"
                            sourceSize: Qt.size(18 * root.s, 18 * root.s)
                            fillMode: Image.Pad
                            opacity: 0.85
                        }
                    }
                    AbstractButton {
                        id: submit
                        anchors.right: parent.right
                        anchors.rightMargin: 3 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32 * root.s; height: 30 * root.s
                        focusPolicy: Qt.NoFocus
                        onClicked: root.doLogin()
                        background: Rectangle {
                            radius: 4
                            color: submit.pressed ? Qt.rgba(1, 1, 1, 0.06) : submit.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        }
                        contentItem: Image {
                            source: "icons/arrow.svg"
                            sourceSize: Qt.size(18 * root.s, 18 * root.s)
                            fillMode: Image.Pad
                        }
                    }
                }

                Text {
                    anchors.top: field.bottom
                    anchors.topMargin: 12 * root.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: field.visible && keyboard.capsLock
                    font.family: root.fontName
                    font.pixelSize: 13 * root.s
                    color: "white"
                    text: qsTr("Bloq Mayús está activado")
                }

                // Error, como en Windows: mensaje y botón Aceptar
                Column {
                    visible: root.errorText !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18 * root.s
                    Text {
                        width: 340 * root.s
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: root.fontName
                        font.pixelSize: 15 * root.s
                        color: "white"
                        text: root.errorText
                    }
                    Button {
                        id: errorOk
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 136 * root.s; height: 34 * root.s
                        onClicked: { root.errorText = ""; password.forceActiveFocus() }
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        Keys.onSpacePressed: clicked()
                        contentItem: Text {
                            text: qsTr("Aceptar")
                            font.family: root.fontName
                            font.pixelSize: 14 * root.s
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 5 * root.s
                            color: errorOk.pressed ? Qt.rgba(1, 1, 1, 0.10) : errorOk.hovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.17)
                            border.width: errorOk.activeFocus ? 2 : 1
                            border.color: errorOk.activeFocus ? "white" : Qt.rgba(1, 1, 1, 0.2)
                        }
                    }
                }

                // Entrando...
                Column {
                    visible: root.busy
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16 * root.s
                    Spinner { anchors.horizontalCenter: parent.horizontalCenter; size: 30 * root.s; running: root.busy }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: root.fontName
                        font.pixelSize: 17 * root.s
                        color: "white"
                        text: qsTr("Te damos la bienvenida")
                    }
                }
            }
        }

        // ---------- Otros usuarios (abajo a la izquierda) ----------
        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 24 * root.s
            spacing: 4 * root.s
            visible: userModel.count > 1

            Repeater {
                model: userModel
                delegate: AbstractButton {
                    id: ub
                    width: 260 * root.s
                    height: 56 * root.s
                    focusPolicy: Qt.NoFocus
                    onClicked: {
                        root.userIndex = index
                        root.errorText = ""
                        password.text = ""
                        password.forceActiveFocus()
                    }
                    background: Rectangle {
                        radius: 6 * root.s
                        color: index === root.userIndex ? Qt.rgba(1, 1, 1, 0.20) : ub.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                    }
                    contentItem: Row {
                        spacing: 12 * root.s
                        leftPadding: 8 * root.s
                        Item {
                            width: 40 * root.s; height: width
                            anchors.verticalCenter: parent.verticalCenter
                            Image { id: smallImg; anchors.fill: parent; source: model.icon || ""; sourceSize: Qt.size(80, 80); visible: false; fillMode: Image.PreserveAspectCrop }
                            Item { id: smallMask; anchors.fill: parent; layer.enabled: true; visible: false
                                Rectangle { anchors.fill: parent; radius: width / 2 } }
                            MultiEffect { anchors.fill: parent; source: smallImg; maskEnabled: true; maskSource: smallMask
                                maskThresholdMin: 0.5; maskSpreadAtMin: 1.0; visible: smallImg.status === Image.Ready }
                            Image { anchors.fill: parent; source: "icons/user.svg"; sourceSize: Qt.size(80, 80); visible: smallImg.status !== Image.Ready }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: root.fontName
                            font.pixelSize: 15 * root.s
                            color: "white"
                            text: model.realName || model.name
                        }
                    }
                }
            }
        }
    }

    // ---------- Abajo a la derecha: teclado, sesión, apagado (siempre visibles, como en Windows) ----------
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24 * root.s
        spacing: 6 * root.s
        opacity: root.unlocked ? 1 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        TrayButton {
            id: kbdBtn
            s: root.s
            visible: keyboard.layouts.length > 0
            label: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
            onClicked: if (keyboard.layouts.length > 1) keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
        TrayButton {
            id: sessionBtn
            s: root.s
            iconSource: "icons/session.svg"
            visible: sessionModel.rowCount() > 1
            onClicked: sessionMenu.open()
            FluentMenu {
                id: sessionMenu
                s: root.s
                y: -height - 8 * root.s
                x: sessionBtn.width - width
                Repeater {
                    model: sessionModel
                    delegate: FluentMenuItem {
                        text: model.name
                        checked: index === root.sessionIndex
                        onTriggered: root.sessionIndex = index
                    }
                }
            }
        }
        TrayButton {
            id: powerBtn
            objectName: "powerButton"
            s: root.s
            iconSource: "icons/power.svg"
            onClicked: powerMenu.open()
            FluentMenu {
                id: powerMenu
                s: root.s
                y: -height - 8 * root.s
                x: powerBtn.width - width
                FluentMenuItem { text: qsTr("Suspender"); visible: sddm.canSuspend; height: visible ? implicitHeight : 0; onTriggered: sddm.suspend() }
                FluentMenuItem { text: qsTr("Apagar"); visible: sddm.canPowerOff; height: visible ? implicitHeight : 0; onTriggered: sddm.powerOff() }
                FluentMenuItem { text: qsTr("Reiniciar"); visible: sddm.canReboot; height: visible ? implicitHeight : 0; onTriggered: sddm.reboot() }
            }
        }
    }

    Component.onCompleted: root.forceActiveFocus()
}
