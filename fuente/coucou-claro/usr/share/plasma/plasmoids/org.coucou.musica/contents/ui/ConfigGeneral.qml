import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property alias cfg_caratulaDeFondo: caratula.checked
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        QQC2.CheckBox { id: caratula; Kirigami.FormData.label: "Fondo:"; text: "La carátula de lo que suena, difuminada" }
    }
}
