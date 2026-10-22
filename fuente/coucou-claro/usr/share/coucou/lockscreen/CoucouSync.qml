/*
    Coucou Code: lo que comparten las pantallas de bloqueo (una ventana por pantalla, mismo motor
    QML). La contraseña y el "despierto" son uno solo: se escribe donde esté el foco y se ve en la
    pantalla principal.
*/
pragma Singleton

import QtQuick

QtObject {
    property string password: ""
    property bool shown: false
}
