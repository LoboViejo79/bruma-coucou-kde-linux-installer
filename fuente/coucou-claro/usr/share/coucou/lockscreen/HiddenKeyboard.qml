// Con un InputPanel en la escena, el teclado virtual de Qt no abre su propia
// ventana al enfocar la contraseña (Plasma hace lo mismo con su cargador).
import QtQuick
import QtQuick.VirtualKeyboard

InputPanel {
    visible: false
    width: 0
    height: 0
}
