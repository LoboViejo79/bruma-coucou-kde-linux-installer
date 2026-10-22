// Avisos de volumen/brillo de Plasma (OSD): centrados justo encima de la barra de tareas,
// como en Windows 11, en lugar de flotar en medio de la pantalla.
const GAP = 12;

function place(w) {
    if (!w.onScreenDisplay) return;
    // Zona útil de la pantalla del aviso: ya descuenta la barra de tareas
    const area = workspace.clientArea(KWin.MaximizeArea, w);
    const g = w.frameGeometry;
    const x = Math.round(area.x + (area.width - g.width) / 2);
    const y = Math.round(area.y + area.height - g.height - GAP);
    if (g.x !== x || g.y !== y)
        w.frameGeometry = { x: x, y: y, width: g.width, height: g.height };
}

function watch(w) {
    if (!w.onScreenDisplay) return;
    place(w);
    // El aviso cambia de tamaño (texto, barra) y KWin lo vuelve a centrar
    w.frameGeometryChanged.connect(() => place(w));
}

workspace.windowAdded.connect(watch);
workspace.stackingOrder.forEach(watch);
