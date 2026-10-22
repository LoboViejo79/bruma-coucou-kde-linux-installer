import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property int cfg_experiencia
    property string cfg_ultimaComida
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        QQC2.Label { Kirigami.FormData.label: "Nivel:"; text: (Math.floor(cfg_experiencia / 100) + 1) + "  (" + cfg_experiencia + " de experiencia)" }
        QQC2.Button { text: "Empezar de nuevo"; icon.name: "edit-reset"; onClicked: { cfg_experiencia = 0; cfg_ultimaComida = "" } }
    }
}
