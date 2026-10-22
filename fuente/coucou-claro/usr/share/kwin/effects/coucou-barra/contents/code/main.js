/*
    Coucou: la barra al pasar de una pantalla a otra.

    Con "todas las pantallas (la que estás usando)" la barra salta a la pantalla del ratón. Para
    eso rehace su ventana, y los primeros cuadros de la ventana nueva salen mal: primero el vidrio
    vacío (sin contenido), un cuadro en blanco (parpadeo) y, en una pantalla con otra escala, la
    barra a medio tamaño corrida a un lado; recién después de unos 100-150 ms queda bien. Además,
    en un mismo salto la ventana a veces se rehace dos o tres veces seguidas (de ahí el parpadeo).

    Este efecto oculta la ventana nueva mientras se arma y después la hace entrar desde su borde:
    desde arriba si la barra está arriba, desde abajo si está abajo. La que se va sale hacia su
    borde. Solo para las ventanas de Coucou sin título pegadas a un borde (la barra); sus
    ventanas normales (Configuración, el chat…) no se tocan.

    Coucou Code (el botón "pantalla completa" del panel de la isla) es una ventana aparte: nace del
    panel. Crece desde el rectángulo donde estaba el panel (se lo ubica por el puntero, que acaba de
    tocar ese botón, en la esquina de arriba a la derecha del panel) hasta su tamaño; al cerrarla
    se encoge hacia el dock. Sus primeros cuadros salen vacíos (la página carga): queda oculta
    CODE_ESPERA ms, mientras el panel sigue quieto en pantalla (/usr/share/coucou/web/mochi.js),
    y recién entonces crece desde él; el panel se desvanece encima.
    Con eso win11-open no la anima (se aparta cuando otro efecto toma la ventana).
*/
"use strict";

const ESPERA = 190;     // ms ocultas mientras se arma la ventana nueva
const ENTRADA = 300;    // ms de la entrada
const SALIDA = 170;     // ms de la salida
const DESPLAZA = 36;    // px que recorre al entrar/salir
// Coucou Code: el panel de la isla con el chat (medidas de la barra) y dónde está su botón
// "pantalla completa" respecto del panel (desde la esquina de arriba a la derecha)
const PANEL = { ancho: 940, alto: 474, botonDerecha: 78, botonArriba: 26 };
// Lo que ocupa la barra (con el panel abierto) en su borde, centrado
const BARRA = { ancho: 960, alto: 560 };
const CODE_ESPERA = 300, CODE_ABRE = 460, CODE_CIERRA = 300;

class CoucouBarra {
    constructor() {
        effect.animationEnded.connect(this.terminada.bind(this));
        effects.windowAdded.connect(this.agregada.bind(this));
        effects.windowClosed.connect(this.cerrada.bind(this));
    }

    // -1: pegada arriba, 1: pegada abajo, 0: no es la barra
    static borde(window) {
        if (window.windowClass !== "coucou coucou" || window.caption)
            return 0;
        const g = window.geometry, s = window.screen ? window.screen.geometry : null;
        if (!s || g.width <= 0 || g.height <= 0)
            return 0;
        const dArriba = Math.abs(g.y - s.y), dAbajo = Math.abs((s.y + s.height) - (g.y + g.height));
        const arriba = dArriba <= 8, abajo = dAbajo <= 8;
        if (!arriba && !abajo)
            return 0;
        // (pegada a los dos: la barra, que es del alto de la pantalla menos 1 px del lado de afuera —ver
        // libcoucou-web.so—: va del borde al que de verdad está pegada; si los dos por igual —Mochi en
        // el escritorio, a pantalla completa—, no es la barra)
        if (arriba && abajo)
            return dArriba === dAbajo ? 0 : (dAbajo < dArriba ? 1 : -1);
        return arriba ? -1 : 1;
    }

    static esCode(window) {
        return window.windowClass === "coucou coucou" && String(window.caption).indexOf("Coucou Code") === 0;
    }

    // La barra (para saber dónde está el dock)
    static barra() {
        for (const w of effects.stackingOrder)
            if (CoucouBarra.borde(w)) return w;
        return null;
    }

    // De dónde sale Coucou Code: el panel de la isla, si se lo tocó desde ahí; si no, el dock
    static panel(window) {
        const c = effects.cursorPos, b = CoucouBarra.barra();
        const s = window.screen ? window.screen.geometry : (b ? b.screen.geometry : null);
        if (b && s) {
            // (donde está la barra de verdad: abajo —o arriba—, en el medio; su ventana es de toda la
            // pantalla, transparente)
            const abajo = CoucouBarra.borde(b) > 0, ancho = Math.min(BARRA.ancho, s.width), alto = Math.min(BARRA.alto, s.height);
            const g = { x: s.x + (s.width - ancho) / 2, y: abajo ? s.y + s.height - alto : s.y, width: ancho, height: alto };
            if (c.x >= g.x && c.x <= g.x + g.width && c.y >= g.y && c.y <= g.y + g.height) {
                const w = Math.min(PANEL.ancho, s.width - 24), h = Math.min(PANEL.alto, s.height - 24);
                const x = Math.max(s.x + 12, Math.min(c.x + PANEL.botonDerecha - w, s.x + s.width - 12 - w));
                const y = Math.max(s.y + 12, Math.min(c.y - PANEL.botonArriba, s.y + s.height - 12 - h));
                return { x: x, y: y, width: w, height: h };
            }
        }
        return CoucouBarra.dock(window);
    }

    // El dock (el centro de la barra), como un cuadrito
    static dock(window) {
        const b = CoucouBarra.barra(), lado = 48;
        if (b) {
            const g = b.geometry, abajo = CoucouBarra.borde(b) > 0;
            const cy = abajo ? g.y + g.height - 37 : g.y + 37;
            return { x: g.x + g.width / 2 - lado / 2, y: cy - lado / 2, width: lado, height: lado };
        }
        const g = window.geometry;
        return { x: g.x + g.width / 2 - lado / 2, y: g.y + g.height - lado, width: lado, height: lado };
    }

    // Escala y desplazamiento para que la ventana se vea en el rectángulo r (la escala es respecto
    // del centro de la ventana)
    static hacia(window, r) {
        const g = window.geometry;
        return {
            escala: { value1: Math.max(0.03, r.width / g.width), value2: Math.max(0.03, r.height / g.height) },
            corre: { value1: (r.x + r.width / 2) - (g.x + g.width / 2), value2: (r.y + r.height / 2) - (g.y + g.height / 2) },
        };
    }

    codeAbre(window) {
        if (effect.isGrabbed(window, Effect.WindowAddedGrabRole))
            return;
        window.setData(Effect.WindowAddedGrabRole, effect);
        // (el panel se mide ahora: el puntero todavía está sobre el botón)
        window.coucouPanel = CoucouBarra.panel(window);
        window.coucouCodeDesde = Date.now();
        window.coucouCodeOculta = set({ window: window, duration: 1, animations: [{ type: Effect.Opacity, to: 0 }] });
        window.coucouCodeEspera = animate({ window: window, duration: CODE_ESPERA, animations: [{ type: Effect.Opacity, from: 0, to: 0 }] });
    }

    codeCrece(window) {
        const d = CoucouBarra.hacia(window, window.coucouPanel);
        window.coucouCode = animate({
            window: window,
            duration: CODE_ABRE,
            curve: QEasingCurve.OutCubic,
            animations: [
                { type: Effect.Scale, from: d.escala, to: { value1: 1, value2: 1 } },
                { type: Effect.Translation, from: d.corre, to: { value1: 0, value2: 0 } },
                { type: Effect.Opacity, from: 0.4, to: 1, curve: QEasingCurve.OutCubic, duration: CODE_ABRE * 0.4 },
            ],
        });
        cancel(window.coucouCodeOculta);
        delete window.coucouCodeOculta;
    }

    codeCierra(window) {
        if (effect.isGrabbed(window, Effect.WindowClosedGrabRole) || !window.visible)
            return;
        for (const k of ["coucouCode", "coucouCodeOculta", "coucouCodeEspera"])
            if (window[k] !== undefined) { cancel(window[k]); delete window[k]; }
        window.setData(Effect.WindowClosedGrabRole, effect);
        const d = CoucouBarra.hacia(window, CoucouBarra.dock(window));
        animate({
            window: window,
            duration: CODE_CIERRA,
            curve: QEasingCurve.InOutCubic,
            animations: [
                { type: Effect.Scale, to: d.escala },
                { type: Effect.Translation, to: d.corre },
                { type: Effect.Opacity, to: 0, curve: QEasingCurve.InCubic },
            ],
        });
    }

    agregada(window) {
        if (CoucouBarra.esCode(window)) {
            if (!effects.hasActiveFullScreenEffect && window.visible) this.codeAbre(window);
            return;
        }
        const b = CoucouBarra.borde(window);
        if (!b || effects.hasActiveFullScreenEffect)
            return;
        if (effect.isGrabbed(window, Effect.WindowAddedGrabRole))
            return;
        window.setData(Effect.WindowAddedGrabRole, effect);
        window.coucouBorde = b;
        // Oculta mientras se arma: queda en 0 hasta cancelarla (set), y una animación muda
        // cuenta el tiempo de espera
        window.coucouDesde = Date.now();
        window.coucouOculta = set({ window: window, duration: 1, animations: [{ type: Effect.Opacity, to: 0 }] });
        window.coucouEspera = animate({ window: window, duration: ESPERA, animations: [{ type: Effect.Opacity, from: 0, to: 0 }] });
    }

    // animationEnded no trae el id de la animación (llega 0): se mira cuánto pasó desde que se
    // agregó: la de ocultar (set) termina enseguida, la espera a los ESPERA ms
    terminada(window) {
        if (CoucouBarra.esCode(window)) {
            // (animationEnded no dice cuál terminó: se mira el tiempo, como abajo)
            const pasó = Date.now() - (window.coucouCodeDesde || 0);
            if (window.coucouCodeEspera !== undefined && pasó >= CODE_ESPERA / 2) {
                delete window.coucouCodeEspera;
                this.codeCrece(window);
            } else if (window.coucouCode !== undefined && pasó >= CODE_ESPERA + CODE_ABRE / 2) {
                delete window.coucouCode;
                window.setData(Effect.WindowAddedGrabRole, null);
            }
            return;
        }
        if (window.coucouEspera === undefined || Date.now() - window.coucouDesde < ESPERA / 2)
            return;
        delete window.coucouEspera;
        const b = window.coucouBorde || -1;
        window.coucouEntrada = animate({
            window: window,
            duration: ENTRADA,
            curve: QEasingCurve.OutCubic,
            animations: [
                { type: Effect.Translation, from: { value1: 0, value2: b * DESPLAZA }, to: { value1: 0, value2: 0 } },
                { type: Effect.Opacity, from: 0, to: 1 },
            ],
        });
        if (window.coucouOculta !== undefined) {
            cancel(window.coucouOculta);
            delete window.coucouOculta;
        }
        window.setData(Effect.WindowAddedGrabRole, null);
    }

    cerrada(window) {
        if (CoucouBarra.esCode(window)) {
            if (!effects.hasActiveFullScreenEffect) this.codeCierra(window);
            return;
        }
        const b = window.coucouBorde || CoucouBarra.borde(window);
        if (!b || effects.hasActiveFullScreenEffect || !window.visible)
            return;
        if (effect.isGrabbed(window, Effect.WindowClosedGrabRole))
            return;
        // Si se cierra todavía oculta (se rehízo dos veces seguidas): se va sin verse
        const oculta = window.coucouOculta !== undefined;
        for (const k of ["coucouOculta", "coucouEspera", "coucouEntrada"]) {
            if (window[k] !== undefined) { cancel(window[k]); delete window[k]; }
        }
        window.setData(Effect.WindowClosedGrabRole, effect);
        animate({
            window: window,
            duration: oculta ? 1 : SALIDA,
            curve: QEasingCurve.InCubic,
            animations: [
                { type: Effect.Translation, to: { value1: 0, value2: b * DESPLAZA } },
                { type: Effect.Opacity, from: oculta ? 0 : 1, to: 0 },
            ],
        });
    }
}

new CoucouBarra();
