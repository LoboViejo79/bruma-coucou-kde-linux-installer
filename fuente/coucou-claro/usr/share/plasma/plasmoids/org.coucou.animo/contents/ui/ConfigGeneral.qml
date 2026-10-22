import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    property alias cfg_estilo: color.valor
    property alias cfg_imagen: imagen.text
    property alias cfg_pregunta: pregunta.text
    property int cfg_eleccion
    property string cfg_dia
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        RowLayout {
            Kirigami.FormData.label: "Imagen:"
            QQC2.TextField { id: imagen; placeholderText: "El fondo de Coucou"; Layout.preferredWidth: 260 }
            QQC2.Button { icon.name: "document-open"; text: "Elegir…"; onClicked: dialogo.open() }
            QQC2.Button { icon.name: "edit-clear"; visible: imagen.text !== ""; onClicked: imagen.text = "" }
        }
        QQC2.TextField { id: pregunta; Kirigami.FormData.label: "Pregunta:" }
    }
    FileDialog {
        id: dialogo
        title: "Elegir una imagen"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.gif)"]
        onAccepted: imagen.text = selectedFile
    }
}
