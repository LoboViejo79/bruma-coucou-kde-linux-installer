import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property alias cfg_maximo: maximo.value
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        QQC2.SpinBox { id: maximo; Kirigami.FormData.label: "Máximo del arco:"; from: 100; to: 150; stepSize: 10
                       textFromValue: v => v + " %"; valueFromText: t => parseInt(t) }
    }
}
