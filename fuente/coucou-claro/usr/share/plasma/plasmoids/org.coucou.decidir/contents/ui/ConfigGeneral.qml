import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property alias cfg_opciones: opciones.text
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        QQC2.TextField { id: opciones; Kirigami.FormData.label: "Opciones:"; placeholderText: "Sí, No, Tal vez" }
        QQC2.Label { text: "Separadas por comas"; opacity: 0.7 }
    }
}
