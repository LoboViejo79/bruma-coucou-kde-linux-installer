import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
    }
}
