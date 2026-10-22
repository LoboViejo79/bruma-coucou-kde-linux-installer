import QtQuick

// Coucou: un dibujo de pixeles a partir de filas de texto. Cada letra es un color de `colores`
// ("." es transparente). El tamaño de cada pixel es `px`; `k`, el de Escala (para verse nítido).
Lienzo {
    id: c
    property var filas: []
    property var colores: ({})
    property real px: 4
    readonly property int columnas: filas.length ? filas[0].length : 0
    width: columnas * px
    height: filas.length * px
    onFilasChanged: repintar()
    onColoresChanged: repintar()
    onPxChanged: repintar()
    onDibujar: g => {
        for (var y = 0; y < filas.length; y++) {
            var f = filas[y]
            for (var x = 0; x < f.length; x++) {
                var col = colores[f[x]]
                if (!col) continue
                g.fillStyle = col
                g.fillRect(x * px, y * px, px + 0.6, px + 0.6)   // un poco encimados: sin rayas entre pixeles
            }
        }
    }
}
