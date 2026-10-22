import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property int cfg_segundos
    property alias cfg_avisar: avisar.checked
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        Row {
            Kirigami.FormData.label: "Tiempo:"
            spacing: 6
            QQC2.SpinBox { id: min; from: 0; to: 1440; value: Math.floor(cfg_segundos / 60); onValueModified: cfg_segundos = value * 60 + seg.value }
            QQC2.Label { anchors.verticalCenter: parent.verticalCenter; text: "min" }
            QQC2.SpinBox { id: seg; from: 0; to: 59; value: cfg_segundos % 60; onValueModified: cfg_segundos = min.value * 60 + value }
            QQC2.Label { anchors.verticalCenter: parent.verticalCenter; text: "s" }
        }
        QQC2.CheckBox { id: avisar; Kirigami.FormData.label: "Al terminar:"; text: "Avisar con una notificación" }
    }
}
