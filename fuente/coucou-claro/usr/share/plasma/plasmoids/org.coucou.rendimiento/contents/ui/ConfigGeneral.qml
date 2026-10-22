import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property string cfg_principal
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        QQC2.ComboBox {
            Kirigami.FormData.label: "Número grande:"
            textRole: "n"; valueRole: "id"
            model: [{ id: "cpu", n: "Procesador" }, { id: "ram", n: "Memoria" }, { id: "temp", n: "Temperatura" },
                    { id: "bat", n: "Batería" }, { id: "gpu", n: "Gráficos" }]
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_principal))
            onActivated: cfg_principal = currentValue
        }
    }
}
