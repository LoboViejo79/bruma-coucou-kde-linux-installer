import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Crear nueva tarea" de Windows: escribe un programa, carpeta, documento o dirección
Dialog {
    id: dlg
    modal: true
    anchors.centerIn: parent
    width: 460
    title: "Crear nueva tarea"
    standardButtons: Dialog.Ok | Dialog.Cancel
    onOpened: { field.text = ""; admin.checked = false; field.forceActiveFocus() }
    onAccepted: procModel.runTask(field.text, admin.checked)

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            spacing: 14
            FluentIcon { name: "runtask"; size: 32; stroke: 1.2; Layout.alignment: Qt.AlignTop }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Escribe el nombre del programa, carpeta, documento o recurso de Internet que quieres abrir."
                color: win.text
            }
        }
        TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: "Abrir:"
            onAccepted: dlg.accept()
        }
        CheckBox {
            id: admin
            text: "Crear esta tarea con privilegios administrativos"
        }
    }
}
