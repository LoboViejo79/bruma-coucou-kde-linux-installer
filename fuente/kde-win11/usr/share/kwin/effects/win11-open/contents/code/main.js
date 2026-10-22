/*
    Abrir apps como en macOS: la ventana nueva sale del icono de la barra de tareas (o del
    punto donde se hizo clic: menú Inicio, escritorio...) y crece hasta su sitio con un
    fundido. Al cerrar se encoge un poco y se desvanece. Sustituye al efecto "scale".
*/
"use strict";

const blacklist = [
    "ksmserver ksmserver",
    "ksmserver-logout-greeter ksmserver-logout-greeter",
    "ksplashqml ksplashqml",
];

class Win11OpenEffect {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.cleanup.bind(this));
        effects.windowAdded.connect(this.windowAdded.bind(this));
        effects.windowClosed.connect(this.windowClosed.bind(this));
        effects.windowDataChanged.connect(this.windowDataChanged.bind(this));
        this.loadConfig();
    }

    loadConfig() {
        this.openDuration = animationTime(effect.readConfig("OpenDuration", 500));   // más ágil (antes 700)
        this.closeDuration = animationTime(effect.readConfig("CloseDuration", 300)); // (antes 400)
        // Tamaño de partida (lado) cuando no hay icono: un "icono" virtual bajo el puntero
        this.origin = effect.readConfig("OriginSize", 48);
    }

    static wanted(window) {
        if (blacklist.includes(window.windowClass))
            return false;
        if (window.windowClass === "plasmashell plasmashell" || window.windowClass === "plasmashell org.kde.plasmashell")
            return window.hasDecoration;
        if (window.lockScreen || window.outline || window.popupWindow || !window.managed)
            return false;
        // La barra de Coucou y sus otras capas (Mochi en el escritorio, avisos) no son apps que se
        // abren: al pasar de una pantalla a otra la barra rehace su ventana y este efecto la animaba
        // como una app nueva (se encogía en una pantalla y crecía desde el puntero en la otra),
        // encima de su propia animación, que sale del borde donde está la barra. Se veía doble.
        if (window.windowClass === "coucou coucou" && !window.caption)
            return false;
        return window.normalWindow || window.dialog;
    }

    // Rectángulo de origen: icono de la barra de tareas si ya se conoce; si no, el puntero
    startRect(window) {
        const icon = window.iconGeometry;
        if (icon && icon.width > 0 && icon.height > 0)
            return icon;
        const c = effects.cursorPos;
        const s = this.origin;
        return { x: c.x - s / 2, y: c.y - s / 2, width: s, height: s };
    }

    windowAdded(window) {
        if (effects.hasActiveFullScreenEffect || !Win11OpenEffect.wanted(window) || !window.visible)
            return;
        if (effect.isGrabbed(window, Effect.WindowAddedGrabRole))
            return;
        window.setData(Effect.WindowForceBlurRole, true);
        window.setData(Effect.WindowAddedGrabRole, effect);

        const g = window.geometry;
        const from = this.startRect(window);
        // Escala inicial: el tamaño del icono, sin bajar del 15 % para que no "salte"
        const sx = Math.max(0.15, Math.min(1, from.width / g.width));
        const sy = Math.max(0.15, Math.min(1, from.height / g.height));
        // La escala es respecto al centro de la ventana: desplazar ese centro al del origen
        const dx = (from.x + from.width / 2) - (g.x + g.width / 2);
        const dy = (from.y + from.height / 2) - (g.y + g.height / 2);

        window.win11OpenAnimation = animate({
            window: window,
            duration: this.openDuration,
            curve: QEasingCurve.OutQuint,
            animations: [
                { type: Effect.Scale, from: { value1: sx, value2: sy }, to: { value1: 1, value2: 1 } },
                { type: Effect.Translation, from: { value1: dx, value2: dy }, to: { value1: 0, value2: 0 } },
                { type: Effect.Opacity, from: 0, to: 1, curve: QEasingCurve.OutCubic, duration: this.openDuration * 0.6 },
            ],
        });
    }

    windowClosed(window) {
        if (effects.hasActiveFullScreenEffect || !Win11OpenEffect.wanted(window))
            return;
        if (!window.visible || window.skipsCloseAnimation)
            return;
        if (effect.isGrabbed(window, Effect.WindowClosedGrabRole))
            return;
        if (window.win11OpenAnimation) {
            cancel(window.win11OpenAnimation);
            delete window.win11OpenAnimation;
        }
        window.setData(Effect.WindowForceBlurRole, true);
        window.setData(Effect.WindowClosedGrabRole, effect);
        window.win11CloseAnimation = animate({
            window: window,
            duration: this.closeDuration,
            curve: QEasingCurve.InCubic,
            animations: [
                { type: Effect.Scale, to: 0.85 },
                { type: Effect.Opacity, to: 0 },
            ],
        });
    }

    windowDataChanged(window, role) {
        if (role === Effect.WindowAddedGrabRole) {
            if (window.win11OpenAnimation && effect.isGrabbed(window, role)) {
                cancel(window.win11OpenAnimation);
                delete window.win11OpenAnimation;
            }
        } else if (role === Effect.WindowClosedGrabRole) {
            if (window.win11CloseAnimation && effect.isGrabbed(window, role)) {
                cancel(window.win11CloseAnimation);
                delete window.win11CloseAnimation;
            }
        }
    }

    cleanup(window) {
        window.setData(Effect.WindowForceBlurRole, null);
        window.setData(Effect.WindowAddedGrabRole, null);
        window.setData(Effect.WindowClosedGrabRole, null);
    }
}

new Win11OpenEffect();
