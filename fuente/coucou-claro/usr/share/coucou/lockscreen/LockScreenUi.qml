/*
    Coucou Code: pantalla de bloqueo, al estilo del iPhone.
    En reposo: la fecha y una hora grande sobre el fondo, nada más.
    Con varias pantallas, la hora, la foto y la contraseña van solo en la principal; las demás
    muestran el fondo, limpio. Se puede escribir con el foco en cualquiera: la clave es una sola
    (CoucouSync) y se ve en la principal.
    Al tocar una tecla o mover el mouse: el fondo se desenfoca, la hora sube y
    se achica, y aparecen la foto (o Mochi), el nombre y una sola píldora de
    vidrio para la contraseña. Un botón de suspender discreto en la esquina.
    La autenticación es la de Plasma (authenticator de kscreenlocker).

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import org.kde.plasma.private.sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: ui

    readonly property string font: "Inter"
    // La principal: la primera para Qt (la que Plasma tiene como principal en Pantallas)
    readonly property bool principal: {
        const s = Qt.application.screens
        return s.length < 2 || Screen.name === "" || Screen.name === s[0].name
    }
    readonly property bool shown: CoucouSync.shown
    function setShown(v) { CoucouSync.shown = v }
    // El fondo de la pantalla de bloqueo (Configuración › Coucou › Pantalla de bloqueo); cada
    // pantalla lo dibuja ella misma. Antes se tomaba la imagen de Plasma ("wallpaper") con un
    // ShaderEffectSource: con dos pantallas las dos usaban la misma, la segunda quedaba negra y
    // la pantalla de bloqueo se caía al cerrarse ("Cannot use same item on different windows").
    readonly property string fondo: {
        let c = ""
        try {
            if (typeof wallpaper !== "undefined" && wallpaper && wallpaper.configuration && wallpaper.configuration.Image)
                c = String(wallpaper.configuration.Image)
        } catch (e) {}
        if (c !== "" && c.indexOf("://") < 0) c = "file://" + c
        return c !== "" ? c : "file:///usr/share/wallpapers/coucou/fondo.png"
    }
    property bool noPassword: false
    property string message: ""
    // Opciones (Configuración > Coucou > Pantalla de bloqueo)
    function opt(name, def) { return (typeof config !== "undefined" && config[name] !== undefined) ? config[name] : def }
    readonly property bool clock24: opt("coucouClock24", true)
    readonly property bool showDate: opt("coucouShowDate", true)
    readonly property bool clockBold: opt("coucouClockBold", true)
    readonly property int blurAmount: Math.max(0, Math.min(100, opt("coucouBlur", 80)))
    readonly property bool showHint: opt("coucouShowHint", true)
    readonly property bool showSuspend: opt("coucouShowSuspend", true)
    readonly property bool useMochi: opt("coucouUseMochi", false)
    function clockText(d) { return ui.clock24 ? Qt.formatTime(d, "H:mm") : Qt.formatTime(d, "h:mm") }

    function say(msg) {
        if (!msg) return
        message = msg
        messageTimer.interval = 3000
        messageTimer.restart()
    }
    // Lo que dice el sistema (p. ej. "10 minutos restantes para el desbloqueo" tras 3 claves
    // incorrectas): queda a la vista y no lo tapa un "Contraseña incorrecta". Antes desaparecía
    // en 3 s y quien seguía probando la clave correcta solo veía "incorrecta".
    property double systemSaidAt: 0
    function sayFromSystem(msg) {
        if (!msg) return
        message = msg
        systemSaidAt = Date.now()
        messageTimer.interval = 15000
        messageTimer.restart()
    }
    function wake() {
        if (!shown) {
            setShown(true)
            // Como el bloqueo de Plasma: la ventana toma el teclado y la verificación arranca de nuevo
            Window.window.requestActivate()
            authenticator.startAuthenticating()
        }
        idleTimer.restart()
        if (principal) password.forceActiveFocus(); else ui.forceActiveFocus()
    }
    // Enter durante la pausa tras una clave incorrecta: se envía apenas Plasma vuelve a pedirla
    property bool pendingSubmit: false
    // El sistema está esperando la clave (pidió una y todavía no se le contestó)
    property bool prompting: false
    function submit() {
        Qt.inputMethod.commit()
        if (password.text.length === 0) return
        if (graceTimer.running) { pendingSubmit = true; return }
        // Nadie la espera (la verificación se cortó: un rato sin uso, una suspensión…): se
        // arranca otra vez y la clave va apenas el sistema la pida. Antes se perdía en silencio
        // y Enter "no hacía nada" hasta tocar Escape.
        if (!prompting) { pendingSubmit = true; authenticator.startAuthenticating(); answerTimer.restart(); return }
        send()
    }
    function send() {
        prompting = false
        pendingSubmit = false
        authenticator.respond(password.text)
        answerTimer.restart()
    }
    // Sin respuesta (ni bien ni mal) en un rato: se vuelve a pedir y se manda de nuevo
    Timer {
        id: answerTimer
        interval: 8000
        onTriggered: if (password.text.length > 0) { ui.pendingSubmit = true; ui.prompting = false; authenticator.startAuthenticating() }
    }
    // Lo escrito siempre va a la contraseña: si el foco se perdió (tras un error, un clic
    // en otro botón...), se devuelve al campo sin perder la tecla
    readonly property Item focusNow: Window.activeFocusItem
    onFocusNowChanged: if (!focusNow) Qt.callLater(function () { if (ui.shown && ui.principal) password.forceActiveFocus(); else ui.forceActiveFocus() })
    // La clave es una sola para todas las pantallas
    Connections {
        target: CoucouSync
        function onPasswordChanged() { if (password.text !== CoucouSync.password) password.text = CoucouSync.password }
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return
            answerTimer.stop()
            ui.prompting = false
            if (Date.now() - ui.systemSaidAt > 3000) ui.say("Contraseña incorrecta")
            password.text = ""
            ui.pendingSubmit = false
            shake.start()
            graceTimer.restart()
            password.forceActiveFocus()
        }
        function onSucceeded() {
            answerTimer.stop()
            // Sin contraseña (cuenta sin clave): un botón, nunca desbloquear solo
            if (authenticator.hadPrompt) Qt.quit()
            else { ui.noPassword = true; ui.setShown(true) }
        }
        function onInfoMessageChanged() { ui.sayFromSystem(authenticator.infoMessage) }
        function onErrorMessageChanged() { ui.sayFromSystem(authenticator.errorMessage) }
        function onPromptForSecretChanged() {
            ui.prompting = true
            if (ui.principal) password.forceActiveFocus()
            if (ui.pendingSubmit && password.text.length > 0) ui.send()
        }
    }
    Connections {
        target: root
        function onClearPassword() { password.text = "" }
    }

    SessionManagement { id: session }
    Connections {
        target: session
        function onAboutToSuspend() { password.text = "" }
    }
    KeyboardIndicator.KeyState { id: caps; key: Qt.Key_CapsLock }

    Timer { id: messageTimer; interval: 3000; onTriggered: ui.message = "" }
    Timer { id: graceTimer; interval: 1200; onTriggered: { authenticator.startAuthenticating(); password.forceActiveFocus() } }
    Timer {
        id: idleTimer
        interval: 15000
        onTriggered: if (password.text.length === 0) { ui.setShown(false); ui.forceActiveFocus() }
    }

    QtObject { id: now; property date date: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: now.date = new Date() }

    // ── Fondo: el de Plasma; desenfocado y oscurecido al desbloquear ────────
    Rectangle { anchors.fill: parent; color: "#14123A" }
    Image {
        id: wallSource
        anchors.fill: parent
        source: ui.fondo
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        smooth: true
        visible: false
        onStatusChanged: if (status === Image.Error && source != "file:///usr/share/wallpapers/coucou/fondo.png") source = "file:///usr/share/wallpapers/coucou/fondo.png"
    }
    FastBlur {
        anchors.fill: parent
        source: wallSource
        // En las otras pantallas el fondo queda nítido
        radius: ui.shown && ui.principal ? ui.blurAmount : 0
        Behavior on radius { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        color: "#0A0920"
        opacity: ui.principal ? (ui.shown ? 0.55 : 0.18) : 0.12
        Behavior on opacity { NumberAnimation { duration: 450 } }
    }
    // Viñeta suave arriba, para que la hora siempre se lea
    Rectangle {
        visible: ui.principal
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: parent.height * 0.45
        gradient: Gradient {
            GradientStop { position: 0; color: "#66000000" }
            GradientStop { position: 1; color: "#00000000" }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        property bool moved: false
        onPositionChanged: { if (moved) ui.wake(); moved = true }
        onPressed: ui.wake()
        cursorShape: ui.shown ? Qt.ArrowCursor : Qt.BlankCursor
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            password.text = ""
            ui.setShown(false)
            return
        }
        // Escribiendo con el foco en otra pantalla: la clave se arma igual (se ve en la principal)
        if (!ui.principal && event.key === Qt.Key_Backspace) {
            ui.wake()
            password.text = password.text.slice(0, -1)
            event.accepted = true
            return
        }
        // Se mira antes de despertar: wake() le da el foco al campo y la primera tecla se perdía
        const typed = event.text.length === 1 && event.text >= " " && !password.activeFocus
        ui.wake()
        if (typed) { password.text += event.text; password.cursorPosition = password.text.length; event.accepted = true; return }
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !password.activeFocus) { ui.submit(); event.accepted = true; return }
        event.accepted = false
    }

    // ── Fecha y hora ───────────────────────────────────────────────────────
    Item {
        id: clockBox
        visible: ui.principal
        width: parent.width
        height: dateText.height + timeText.height
        y: ui.shown ? parent.height * 0.07 : parent.height * 0.12
        scale: ui.shown ? 0.42 : 1
        transformOrigin: Item.Top
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: { const s = now.date.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
            color: "#EEFFFFFF"
            font.family: ui.font; font.pixelSize: 24; font.weight: Font.DemiBold
            opacity: ui.shown || !ui.showDate ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.bottom
            anchors.topMargin: -12
            text: ui.clockText(now.date)
            color: "#F2FFFFFF"
            font.family: ui.font; font.pixelSize: 168; font.weight: ui.clockBold ? Font.Bold : Font.ExtraLight
            font.letterSpacing: -4
            layer.enabled: true
            layer.effect: DropShadow { radius: 24; samples: 33; color: "#40000000"; verticalOffset: 2 }
        }
    }

    // Pista abajo, en reposo: la barrita del iPhone
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 12
        visible: ui.principal
        opacity: ui.shown || !ui.showHint ? 0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pulsa una tecla para desbloquear"
            color: "#DDFFFFFF"; font.family: ui.font; font.pixelSize: 13; font.weight: Font.Medium
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 136; height: 5; radius: 3; color: "#E6FFFFFF"
        }
    }

    // ── Desbloqueo: foto, nombre y una sola píldora ────────────────────────
    Column {
        id: unlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: ui.shown ? parent.height * 0.36 : parent.height * 0.42
        spacing: 14
        // En las otras pantallas no se ve, pero el campo sigue ahí: la clave escrita desde ellas
        opacity: ui.shown && ui.principal ? 1 : 0
        visible: opacity > 0
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92; height: 92
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#33FFFFFF" }
            Image {
                id: face
                property bool photo: kscreenlocker_userImage !== "" && !ui.useMochi
                anchors.fill: parent
                anchors.margins: photo ? 0 : 16
                // Como el bloqueo de Plasma: la ruta, carpeta por carpeta, para que espacios o tildes no la rompan
                source: photo ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : "mochi.png"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                layer.enabled: photo
                layer.effect: OpacityMask { maskSource: Rectangle { width: face.width; height: face.height; radius: width / 2 } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: kscreenlocker_userName
            color: "#FFFFFF"; font.family: ui.font; font.pixelSize: 19; font.weight: Font.DemiBold
        }

        Item { width: 1; height: 4 }

        // La píldora de vidrio
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 290; height: 46; radius: 23
            color: password.activeFocus ? "#3DFFFFFF" : "#2BFFFFFF"
            visible: !ui.noPassword
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                visible: password.text.length === 0
                text: "Contraseña"
                color: "#C8FFFFFF"
                font.family: "Inter"; font.pixelSize: 15
            }
            TextField {
                id: password
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: text.length > 0 ? 78 : 46 }
                echoMode: eyeBtn.reveal ? TextInput.Normal : TextInput.Password
                // Una clave: sin predicción ni texto "a medio confirmar" de un método de entrada
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
                passwordCharacter: "●"
                horizontalAlignment: text.length > 0 ? TextInput.AlignLeft : TextInput.AlignHCenter
                color: "#FFFFFF"
                font.family: ui.font; font.pixelSize: 15; font.letterSpacing: text.length > 0 && !eyeBtn.reveal ? 2 : 0
                background: Item {}
                onTextChanged: {
                    idleTimer.restart()
                    if (text.length === 0) eyeBtn.reveal = false
                    if (CoucouSync.password !== text) CoucouSync.password = text
                }
                onAccepted: ui.submit()
                Keys.onEscapePressed: { text = ""; ui.setShown(false) }
            }
            // Ojito: muestra u oculta lo que se escribió
            Item {
                id: eyeBtn
                property bool reveal: false
                anchors { right: parent.right; rightMargin: 44; verticalCenter: parent.verticalCenter }
                width: 32; height: 32
                opacity: password.text.length > 0 ? (eyeMouse.containsMouse ? 1 : 0.75) : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Canvas {
                    id: eyeIcon
                    anchors.centerIn: parent; width: 20; height: 14
                    property bool open: eyeBtn.reveal
                    onOpenChanged: requestPaint()
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = "#FFFFFF"; c.fillStyle = "#FFFFFF"
                        c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round"
                        c.beginPath(); c.moveTo(1.5, 7); c.quadraticCurveTo(10, -3, 18.5, 7)
                        c.quadraticCurveTo(10, 17, 1.5, 7); c.closePath(); c.stroke()
                        c.beginPath(); c.arc(10, 7, 2.6, 0, 2 * Math.PI); c.fill()
                        if (!open) { c.beginPath(); c.moveTo(3, 13); c.lineTo(17, 1); c.stroke() }
                    }
                }
                MouseArea {
                    id: eyeMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { eyeBtn.reveal = !eyeBtn.reveal; password.forceActiveFocus() }
                }
            }
            Rectangle {
                anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                width: 36; height: 36; radius: 18
                color: "#FFFFFF"
                opacity: password.text.length > 0 ? 1 : 0
                scale: password.text.length > 0 ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Canvas {
                    anchors.centerIn: parent; width: 14; height: 14
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = "#1A1838"; c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round"
                        c.beginPath(); c.moveTo(7, 12); c.lineTo(7, 2); c.moveTo(2.5, 6.5); c.lineTo(7, 2); c.lineTo(11.5, 6.5); c.stroke()
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ui.submit() }
            }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -14; duration: 55; easing.type: Easing.OutQuad }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -8; duration: 60 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 5; duration: 55 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }
        }

        // Sin contraseña: solo un botón
        Rectangle {
            visible: ui.noPassword
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200; height: 46; radius: 23; color: "#3DFFFFFF"
            Text { anchors.centerIn: parent; text: "Desbloquear"; color: "#FFFFFF"; font.family: ui.font; font.pixelSize: 15; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ui.message !== "" ? ui.message : (caps.locked ? "Bloq Mayús activado" : "")
            color: ui.message !== "" ? "#FFB4BE" : "#C8FFFFFF"
            font.family: ui.font; font.pixelSize: 12; font.weight: Font.Medium
            height: 16
        }
    }

    // ── Esquina: suspender, discreto ───────────────────────────────────────
    Rectangle {
        visible: session.canSuspend && ui.showSuspend && ui.principal
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        width: 44; height: 44; radius: 22
        color: sleepMouse.containsMouse ? "#40FFFFFF" : "#26FFFFFF"
        opacity: ui.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Text { anchors.centerIn: parent; text: "☾"; color: "#FFFFFF"; font.pixelSize: 18 }
        MouseArea { id: sleepMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: session.suspend() }
    }


    Loader { source: "HiddenKeyboard.qml" }

    // Entrada: aparece sobre las auroras violetas del arranque y se disuelve en
    // la pantalla de bloqueo (al prender, sigue sin cortes al splash de Plasma)
    Image {
        id: entrance
        anchors.fill: parent
        source: "file:///usr/share/plasma/look-and-feel/org.coucou.code/contents/splash/bg.png"
        fillMode: Image.Stretch
        Rectangle { anchors.fill: parent; z: -1; color: "#14123A" }
        NumberAnimation on opacity { from: 1; to: 0; duration: 700; easing.type: Easing.InOutQuad; running: true }
        visible: opacity > 0
    }

    Component.onCompleted: {
        ui.forceActiveFocus()
        authenticator.startAuthenticating()
    }
}
