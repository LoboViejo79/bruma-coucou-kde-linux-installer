// Coucou: devolver el foco (script de KWin, lo corre /usr/lib/coucou/devolver-foco).
// Si la ventana activa quedó siendo la barra (se escribió en un panel: un recordatorio, el
// buscador…), activa la ventana que estaba adelante. Si no, los botones del dock no minimizaban la
// app al primer clic: la barra minimiza solo si la app es la ventana activa.
(function () {
    function esBarra(w) { return !!w && String(w.resourceClass) === "coucou" && !w.caption; }
    if (!esBarra(workspace.activeWindow)) return;
    var orden = workspace.stackingOrder;
    for (var i = orden.length - 1; i >= 0; i--) {
        var w = orden[i];
        if (!w.normalWindow || w.minimized || w.skipTaskbar || esBarra(w)) continue;
        if (!w.onAllDesktops && w.desktops && workspace.currentDesktop && w.desktops.indexOf(workspace.currentDesktop) < 0) continue;
        workspace.activeWindow = w;
        return;
    }
})();
