import QtQuick
import QtQuick.Window

// Coucou: un dibujo hecho con código (el reloj de arena, el arco del volumen…) que se ve nítido a
// cualquier tamaño. Se usa con las medidas de diseño (dentro de Escala) y se pinta en la señal
// `dibujar(g)` con esas mismas medidas; por dentro el lienzo es del tamaño real en pantalla.
//   Lienzo { k: e.k; x: 30; y: 20; width: 110; height: 120; onDibujar: g => { ... } }
Item {
    id: l
    property real k: 1
    signal dibujar(var g)
    function repintar() { c.requestPaint() }
    Canvas {
        id: c
        readonly property real f: Math.max(0.1, l.k * (Screen.devicePixelRatio || 1))
        width: Math.ceil(l.width * f); height: Math.ceil(l.height * f)
        scale: 1 / f
        transformOrigin: Item.TopLeft
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var g = getContext("2d")
            g.reset()
            g.save()
            g.scale(f, f)
            l.dibujar(g)
            g.restore()
        }
    }
}
