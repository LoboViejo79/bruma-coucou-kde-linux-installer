import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_ciudad: ciudad.text
    property alias cfg_fahrenheit: fahrenheit.checked
    property string cfg_estilo
    property double cfg_latitud
    property double cfg_longitud
    property string cfg_nombreLugar
    Kirigami.FormLayout {
        QQC2.TextField { id: ciudad; Kirigami.FormData.label: "Ciudad:"; placeholderText: "Vacío: la de tu conexión" }
        QQC2.CheckBox { id: fahrenheit; Kirigami.FormData.label: "Unidad:"; text: "Fahrenheit (°F)" }
        QQC2.Label { text: "Datos de Open-Meteo. Doble clic en el widget: actualizar ya."; opacity: 0.7 }
    }
}
