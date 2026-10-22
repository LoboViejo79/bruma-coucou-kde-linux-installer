// Coucou Code: inicio de sesión (SDDM), al estilo del iPhone y a juego con la
// pantalla de bloqueo. En reposo, la fecha y una hora grande. Al tocar una
// tecla: fondo desenfocado, la hora arriba y pequeña, la foto (o Mochi), el
// nombre y una sola píldora de vidrio. Energía en un botón de la esquina.
// Con varias pantallas, todo eso va en la principal; las demás muestran el fondo, limpio.
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0A0920"

    readonly property string fontName: config.font || "Inter"
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    // La sesión: la última que se usó; si no hay, Plasma (Wayland). (Plasma 6.8 ya no tiene X11; la
    // sesión X11 de Coucou es solo para AnyDesk, se elige a mano.)
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : Math.max(plasmaIndex, 0)
    property string userName: ""
    property string userRealName: ""
    property string userIcon: ""
    property string sessionName: ""
    property bool shown: false
    property bool busy: false
    // SDDM abre una ventana por pantalla (cada una con su propio QML) y dice cuál es la principal
    readonly property bool principal: typeof primaryScreen === "undefined" || primaryScreen
    // En otra pantalla solo si el teclado quedó en ella (se escribe ahí): para no quedar trabado
    property bool tecladoAqui: false
    readonly property bool ui: principal || tecladoAqui
    // Entrando: todo se funde al violeta noche de la pantalla de carga, con Mochi
    // en el centro, para que el paso a la sesión no se vea como un corte negro
    property bool leaving: false
    property string message: ""
    // El índice de la sesión X11 de Plasma: la barra de Coucou está hecha para X11
    property int plasmaIndex: -1

    function wake() {
        if (leaving || !ui) return
        shown = true
        idle.restart()
        password.forceActiveFocus()
    }
    function doLogin() {
        // Lo que quedó "a medio escribir" en un método de entrada pasa al campo antes de mirarlo
        Qt.inputMethod.commit()
        if (busy || password.text.length === 0) return
        busy = true
        leaving = true
        message = ""
        // Un instante para que la salida se vea entera antes de que SDDM cierre esto
        loginDelay.restart()
        stuck.restart()
    }
    // Si SDDM no contesta (ni entra ni dice que falló), la pantalla vuelve a quedar usable
    Timer {
        id: stuck
        interval: 25000
        onTriggered: if (root.busy) {
            root.leaving = false
            root.busy = false
            root.message = "No se pudo entrar. Probá de nuevo"
            password.forceActiveFocus()
        }
    }
    property int failures: 0
    Timer {
        id: loginDelay
        interval: 260
        onTriggered: sddm.login(root.userName, password.text, root.sessionIndex)
    }

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
                // Sin foto propia, SDDM da su silueta genérica: mejor Mochi
                const icon = model.icon || ""
                root.userIcon = icon.indexOf("/sddm/faces/") >= 0 ? "" : icon
            }
        }
    }
    Repeater {
        model: sessionModel
        delegate: Item {
            visible: false
            Component.onCompleted: {
                if (/(^|\/)plasma\.desktop$/.test(model.file || "")) root.plasmaIndex = index
                if (index === root.sessionIndex) root.sessionName = model.name
            }
            Connections {
                target: root
                function onSessionIndexChanged() { if (index === root.sessionIndex) root.sessionName = model.name }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            stuck.stop()
            root.leaving = false
            root.busy = false
            password.text = ""
            root.failures++
            // Tras 3 claves incorrectas el sistema bloquea la cuenta unos minutos (pam_faillock):
            // dicho, para que nadie siga probando la correcta sin saber por qué no entra
            root.message = root.failures >= 3 ? "Demasiados intentos: esperá unos minutos y probá de nuevo" : "Contraseña incorrecta"
            shake.start()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() { }
    }

    Timer { id: idle; interval: 60000; onTriggered: if (password.text.length === 0 && !root.busy) { root.shown = false } }
    QtObject { id: now; property date date: new Date() }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: now.date = new Date() }

    // ── Fondo ───────────────────────────────────────────────────────────────
    Image {
        id: wall
        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
    }
    FastBlur {
        anchors.fill: parent
        source: wall
        radius: root.shown && root.ui ? 80 : 0
        visible: radius > 0
        Behavior on radius { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        color: "#0A0920"
        opacity: root.ui ? (root.shown ? 0.55 : 0.18) : 0.12
        Behavior on opacity { NumberAnimation { duration: 450 } }
    }
    Rectangle {
        visible: root.ui
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
        onPositionChanged: { if (moved) root.wake(); moved = true }
        onPressed: root.wake()
    }
    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { password.text = ""; root.shown = false; return }
        if (!root.principal) root.tecladoAqui = true
        // Se mira antes de despertar: wake() le da el foco al campo y la primera tecla se perdía
        const typed = event.text.length === 1 && event.text >= " " && !password.activeFocus && !root.busy
        root.wake()
        if (typed) { password.text += event.text; password.cursorPosition = password.text.length; event.accepted = true }
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !password.activeFocus) { root.doLogin(); event.accepted = true }
    }
    // Si el foco se pierde (campo desactivado mientras entra, clic en otro botón), vuelve solo
    readonly property Item focusNow: Window.activeFocusItem
    onFocusNowChanged: if (!focusNow) Qt.callLater(function () { if (root.shown && !root.busy) password.forceActiveFocus(); else root.forceActiveFocus() })

    // ── Fecha y hora ───────────────────────────────────────────────────────
    Item {
        visible: root.ui
        width: parent.width
        height: dateText.height + timeText.height
        y: root.shown ? parent.height * 0.07 : parent.height * 0.12
        scale: root.shown ? 0.42 : 1
        transformOrigin: Item.Top
        opacity: root.leaving ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            text: { const s = now.date.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
            color: "#EEFFFFFF"
            font.family: root.fontName; font.pixelSize: 24; font.weight: Font.DemiBold
            opacity: root.shown ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dateText.bottom
            anchors.topMargin: -12
            text: Qt.formatTime(now.date, "H:mm")
            color: "#F2FFFFFF"
            font.family: root.fontName; font.pixelSize: 168; font.weight: Font.Bold
            font.letterSpacing: -4
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 12
        visible: root.ui
        opacity: root.shown ? 0 : 0.9
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pulsa una tecla para iniciar sesión"
            color: "#DDFFFFFF"; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.Medium
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 136; height: 5; radius: 3; color: "#E6FFFFFF" }
    }

    // ── Usuario y contraseña ───────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height * 0.36 : parent.height * 0.42
        spacing: 14
        opacity: root.shown && root.ui && !root.leaving ? 1 : 0
        scale: root.leaving ? 0.94 : 1
        visible: opacity > 0
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92; height: 92
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#33FFFFFF" }
            Image {
                id: face
                property bool photo: root.userIcon !== "" && status !== Image.Error
                anchors.fill: parent
                anchors.margins: photo ? 0 : 16
                source: root.userIcon !== "" ? root.userIcon : "mochi.png"
                onStatusChanged: if (status === Image.Error) source = "mochi.png"
                fillMode: Image.PreserveAspectCrop
                layer.enabled: photo
                layer.effect: OpacityMask { maskSource: Rectangle { width: face.width; height: face.height; radius: width / 2 } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userRealName
            color: "#FFFFFF"; font.family: root.fontName; font.pixelSize: 19; font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                enabled: userModel.count > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
            }
        }

        Item { width: 1; height: 4 }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 290; height: 46; radius: 23
            color: password.activeFocus ? "#3DFFFFFF" : "#2BFFFFFF"
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
                font.family: root.fontName; font.pixelSize: 15; font.letterSpacing: text.length > 0 && !eyeBtn.reveal ? 2 : 0
                background: Item {}
                enabled: !root.busy
                onTextChanged: { idle.restart(); if (text.length === 0) eyeBtn.reveal = false }
                onAccepted: root.doLogin()
                Keys.onEscapePressed: { text = ""; root.shown = false }
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
                opacity: password.text.length > 0 || root.busy ? 1 : 0
                scale: password.text.length > 0 || root.busy ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                Canvas {
                    anchors.centerIn: parent; width: 14; height: 14
                    visible: !root.busy
                    onPaint: {
                        const c = getContext("2d"); c.reset()
                        c.strokeStyle = "#1A1838"; c.lineWidth = 2.2; c.lineCap = "round"; c.lineJoin = "round"
                        c.beginPath(); c.moveTo(7, 12); c.lineTo(7, 2); c.moveTo(2.5, 6.5); c.lineTo(7, 2); c.lineTo(11.5, 6.5); c.stroke()
                    }
                }
                Rectangle {
                    visible: root.busy
                    anchors.centerIn: parent; width: 14; height: 14; radius: 7
                    color: "transparent"; border.color: "#1A1838"; border.width: 2
                    Rectangle { width: 6; height: 6; radius: 3; color: "#FFFFFF"; x: 8; y: -1 }
                    RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: root.busy }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -14; duration: 55 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -8; duration: 60 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 5; duration: 55 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.message !== "" ? root.message : (keyboard.capsLock ? "Bloq Mayús activado" : "")
            color: root.message !== "" ? "#FFB4BE" : "#C8FFFFFF"
            font.family: root.fontName; font.pixelSize: 12; font.weight: Font.Medium
            height: 16
        }
        // La sesión (cuando hay más de una: Plasma y la X11 para AnyDesk): un botón; un clic pasa a la
        // siguiente
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: sessionModel.rowCount() > 1
            width: filaSesion.implicitWidth + 28; height: 30; radius: 15
            color: areaSesion.containsMouse ? "#2EFFFFFF" : "#1AFFFFFF"
            border.width: 1; border.color: "#26FFFFFF"
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
                id: filaSesion
                anchors.centerIn: parent
                spacing: 8
                Text { text: root.sessionName; color: "#F2FFFFFF"; font.family: root.fontName; font.pixelSize: 12; font.weight: Font.DemiBold
                       anchors.verticalCenter: parent.verticalCenter }
                Text { text: "⇄"; color: "#B3FFFFFF"; font.family: root.fontName; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: areaSesion; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount() }
        }
    }

    // ── Esquina: suspender, reiniciar y apagar, tres botones redondos ─────
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 12
        opacity: root.shown && root.ui && !root.leaving ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.leaving ? 180 : 300 } }
        Repeater {
            model: [
                { glyph: "☾", act: "suspend", show: sddm.canSuspend },
                { glyph: "↻", act: "reboot", show: sddm.canReboot },
                { glyph: "⏻", act: "off", show: sddm.canPowerOff }
            ]
            delegate: Rectangle {
                visible: modelData.show
                width: 44; height: 44; radius: 22
                color: pm.pressed ? "#55FFFFFF" : (pm.containsMouse ? "#40FFFFFF" : "#26FFFFFF")
                Text { anchors.centerIn: parent; text: modelData.glyph; color: "#FFFFFF"; font.pixelSize: 18 }
                MouseArea {
                    id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.act === "off" ? sddm.powerOff() : modelData.act === "reboot" ? sddm.reboot() : sddm.suspend()
                }
            }
        }
    }

    // ── Salida: funde al violeta noche con Mochi, como empieza la pantalla de carga
    Rectangle {
        id: veil
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#1A1740" }
            GradientStop { position: 1; color: "#08071A" }
        }
        opacity: root.leaving ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.leaving ? 380 : 250; easing.type: Easing.InOutQuad } }
        Image {
            id: byeMochi
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            source: "mochi.png"
            sourceSize: Qt.size(170, 170)
            opacity: root.leaving ? 1 : 0
            scale: root.leaving ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: 320 } }
            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
        }
    }


    Loader { source: "HiddenKeyboard.qml" }

    // La principal se queda con el teclado (la de la otra pantalla puede abrirse después y
    // quedar activa): se pide al abrir y otra vez un poco más tarde
    Timer {
        id: tomarTeclado
        interval: 400; repeat: true
        property int veces: 0
        onTriggered: { if (Window.window) Window.window.requestActivate(); root.forceActiveFocus(); if (++veces >= 4) stop() }
    }
    Component.onCompleted: {
        root.forceActiveFocus()
        if (root.principal) tomarTeclado.start()
    }
}
