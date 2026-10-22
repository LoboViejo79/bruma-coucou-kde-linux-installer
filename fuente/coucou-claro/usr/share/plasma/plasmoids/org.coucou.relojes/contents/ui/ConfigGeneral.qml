import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.coucou.widgets as C

KCM.SimpleKCM {
    id: pagina
    property alias cfg_estilo: color.valor
    property string cfg_lugares
    // Tres filas: nombre, zona horaria y carita
    property var filas: {
        var l = cfg_lugares.split(",").map(function (x) { var p = x.split("|"); return [p[0] || "", p[1] || "", p[2] || ""] })
        while (l.length < 3) l.push(["", "", ""])
        return l.slice(0, 3)
    }
    function guardar() {
        cfg_lugares = filas.filter(function (f) { return f[1].trim() !== "" }).map(function (f) { return f.join("|") }).join(",")
    }
    Kirigami.FormLayout {
        C.ConfigColor { id: color }
        Repeater {
            model: 3
            RowLayout {
                required property int index
                Kirigami.FormData.label: "Lugar " + (index + 1) + ":"
                QQC2.TextField { placeholderText: "Nombre"; text: pagina.filas[index][0]; Layout.preferredWidth: 110
                                 onEditingFinished: { pagina.filas[index][0] = text; pagina.guardar() } }
                QQC2.TextField { placeholderText: "Zona (ej. Europe/Madrid)"; text: pagina.filas[index][1]; Layout.preferredWidth: 210
                                 onEditingFinished: { pagina.filas[index][1] = text.trim(); pagina.guardar() } }
                QQC2.TextField { placeholderText: "🙂"; text: pagina.filas[index][2]; Layout.preferredWidth: 46; maximumLength: 4
                                 onEditingFinished: { pagina.filas[index][2] = text; pagina.guardar() } }
            }
        }
        QQC2.Label { text: "Zonas: Europe/Madrid, America/Mexico_City, America/Argentina/Buenos_Aires, Asia/Tokyo…\nUn lugar sin zona no se muestra."; opacity: 0.7 }
    }
}
