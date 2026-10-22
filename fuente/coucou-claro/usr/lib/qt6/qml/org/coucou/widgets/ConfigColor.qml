import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Coucou: el selector "Color" de la configuración de cada widget (ver Paletas)
QQC2.ComboBox {
    id: cb
    property string valor: "coucou"
    Kirigami.FormData.label: "Color:"
    textRole: "nombre"
    valueRole: "id"
    model: Paletas.lista
    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(valor))
    onActivated: valor = currentValue
}
