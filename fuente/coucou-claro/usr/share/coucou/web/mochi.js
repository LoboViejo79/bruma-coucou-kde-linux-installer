/*
    Coucou: transiciones de elementos compartidos en la barra (Mochi).

    Lo agrega libcoucou-web.so a la página de la barra (ver fuente/codigo/coucou-web.c), junto con
    mochi.css. La barra viene compilada: aquí no se cambia su código, se le suma esto encima.

    Abrir y cerrar los paneles de la barra (el del mochi, el buscador, los juegos, las notificaciones,
    "en segundo plano"…), con la API de View Transitions: cada uno nace del botón que se tocó y
    vuelve a él al cerrarse (no viaja desde el centro); pasando de uno a otro, va de un lugar al otro. se toma una foto de cómo está, se lleva la barra a
    cómo va a quedar y el navegador anima entre las dos. Abriendo, el botón del mochi se transforma
    en la isla y el dibujito del mochi viaja del dock a su lugar en el panel; cerrando, la isla se
    encoge hacia el botón del mochi y el mochi vuelve al dock (con la animación de la barra).

    El botón de Wi-Fi / volumen / batería de la barra abre el Centro de control de Coucou
    (/usr/bin/coucou-control) apoyado sobre la barra, en lugar del panel propio de la barra (se lo
    pide a libcoucou-web.so). El "Modo juego" de la ventana de Juegos es el de Coucou, el mismo del
    Centro de control (/usr/lib/coucou/modo-juego), y dice qué quedó en pausa mientras está activo.

    La barra anima la isla con un resorte propio, cuadro por cuadro; mientras tanto le da al
    contenido (#content) el tamaño final (ver su applyGeometry). Con eso se sabe dónde va a quedar:
    la isla y el mochi se fijan ahí (clase cc-fija, con las medidas en variables de CSS; mochi.css
    les gana a los estilos que pone la barra) hasta que el resorte termina y coincide.

    "Pantalla completa" (el botón de arriba a la derecha del panel del mochi): el mismo panel crece
    hasta ocupar la pantalla y es Coucou Code (ver pantallaCompleta), en vez de abrir su ventana.
*/
(function () {
    "use strict";
    // Solo en la página de la barra (no en la de Configuración ni en la del mochi suelto)
    if (window.__coucouMochi || !/^\/(index\.html)?$/.test(location.pathname)) return;
    window.__coucouMochi = true;
    const raiz = document.documentElement;
    const $ = id => document.getElementById(id);

    // Los cuadros de la barra pasan por aquí: así se puede correr uno en el momento, o pausarlos
    // mientras corre una transición (la barra hace mucho en cada cuadro —su resorte, el dibujo del
    // mochi— y con eso la transición iba a saltos; la isla ya está fija donde va a quedar)
    const rafReal = window.requestAnimationFrame.bind(window);
    let pendientes = new Map(), proximoId = 1, agendado = false, pausado = false;
    function agendar() { if (!agendado && !pausado && pendientes.size) { agendado = true; rafReal(t => { agendado = false; if (!pausado) correr(t); else agendar(); }); } }
    function pausar(si) { pausado = si; agendar(); }
    function correr(t) {
        const lista = pendientes; pendientes = new Map();
        for (const cb of lista.values()) { try { cb(t); } catch (e) { console.error(e); } }
    }
    window.requestAnimationFrame = cb => {
        const id = proximoId++;
        pendientes.set(id, cb);
        agendar();
        return id;
    };
    window.cancelAnimationFrame = id => { pendientes.delete(id); };

    // Dónde queda el mochi respecto de la isla abierta (se aprende de la barra misma)
    let mochiEnIsla = { x: -12, y: -8 };
    try { const g = JSON.parse(localStorage.getItem("cc-mochi-en-isla")); if (g && isFinite(g.x) && isFinite(g.y)) mochiEnIsla = g; } catch (e) {}
    const px = v => Math.round(v * 10) / 10 + "px";
    function fijar(vars) {
        for (const [k, v] of Object.entries(vars)) raiz.style.setProperty("--cc-" + k, v);
    }
    let soltar = null;
    function soltarLuego(ms, alSoltar) {
        clearTimeout(soltar);
        soltar = setTimeout(() => {
            if (alSoltar) alSoltar();
            raiz.classList.remove("cc-fija", "cc-cerrando");
        }, ms);
    }

    let enTransicion = false;
    function nombrar(el, n) { if (el) el.style.viewTransitionName = n || ""; }

    // El tamaño final de cada panel. La barra lo calcula adentro (cada panel mide lo suyo); afuera se
    // ve en el contenido mientras la isla crece (lo pone del tamaño final), pero no mientras se achica
    // (ahí queda del tamaño de antes). Por eso se aprende el tamaño de cada panel cuando está quieto.
    let tamanos = {};
    try { tamanos = JSON.parse(localStorage.getItem("cc-tamanos")) || {}; } catch (e) {}
    function panelActual() {
        const vs = [...document.querySelectorAll("#views > .view")];
        const v = vs.find(x => x.classList.contains("on")) || vs.find(x => x.offsetWidth > 0 && getComputedStyle(x).visibility !== "hidden" && +getComputedStyle(x).opacity > 0.5);
        return v ? [...v.classList].filter(c => c !== "view" && c !== "on").join(".") || "panel" : "";
    }
    function aprenderTamano() {
        const isla = $("island"), clave = panelActual();
        if (!isla || !clave || !/\bopen\b/.test(isla.className) || raiz.classList.contains("cc-fija")) return;
        const w = parseFloat(isla.style.width), h = parseFloat(isla.style.height);
        if (!(w > 100 && h > 40)) return;
        tamanos[clave] = { w: Math.round(w), h: Math.round(h) };
        try { localStorage.setItem("cc-tamanos", JSON.stringify(tamanos)); } catch (e) {}
    }
    // El tamaño al que va el panel nuevo (null si no se sabe todavía)
    function tamanoFinal() {
        const isla = $("island"), contenido = $("content");
        const cw = parseFloat(contenido.style.width), ch = parseFloat(contenido.style.height);
        const iw = parseFloat(isla.style.width), ih = parseFloat(isla.style.height);
        const sabido = tamanos[panelActual()];
        if (sabido) return sabido;
        if (!cw && !ch) return iw > 0 ? { w: iw, h: ih } : null;          // ya quieta: ese es
        if (cw >= iw - 1 && ch >= ih - 1) return { w: cw, h: ch };        // creciendo: el contenido
        return null;
    }

    // Dónde va a quedar la isla, igual que la barra (su cardX y cardTop): centrada en el botón que la
    // abrió sin pasarse de los bordes (o en el medio, con la barra en forma de isla), apoyada en la
    // misma línea. La barra ya fijó su destino (corre un cuadro). Devuelve false si no se sabe su tamaño.
    function fijarEn(boton, conMochi) {
        const isla = $("island");
        correr(performance.now());
        // El cambio de panel que la barra hace con un fundido (el de antes se va, el nuevo aparece):
        // terminado ya, así la foto del panel nuevo no lleva restos del de antes
        const vistas = $("views");
        if (vistas) for (const a of vistas.getAnimations({ subtree: true })) {
            try { if (a.effect && a.effect.getTiming().iterations !== Infinity) a.finish(); } catch (e) {}
        }
        const t = tamanoFinal();
        if (!t) return false;
        const r = isla.getBoundingClientRect(), rb = boton.getBoundingClientRect();
        const w = t.w, h = t.h;
        const ancha = /\bbar-(wide|edge)\b/.test($("root").className);
        const abajo = !/\bbar-top\b/.test($("root").className);
        raiz.classList.toggle("cc-arriba", !abajo);
        const centro = rb.left + rb.width / 2;
        const cx = ancha ? Math.min(Math.max(centro, w / 2 + 12), innerWidth - w / 2 - 12) : innerWidth / 2;
        const x = cx - w / 2, y = abajo ? r.top + r.height - h : r.top;
        // (la flecha apunta al botón, como la pone la barra: entre 30 px de cada borde)
        const caret = Math.min(Math.max(centro - x, 30), w - 30);
        fijar({ w: px(w), h: px(h), y: px(y), cx: px(cx), caret: px(caret), mx: px(x + mochiEnIsla.x), my: px(y + mochiEnIsla.y) });
        raiz.classList.add("cc-fija");
        raiz.classList.toggle("cc-fija-mochi", !!conMochi);
        // Cuando el resorte de la barra termina, se le devuelve; de paso se aprende dónde deja al
        // mochi (para la próxima)
        soltarLuego(1500, () => {
            raiz.classList.remove("cc-fija", "cc-fija-mochi");
            const ri = isla.getBoundingClientRect(), mochi = $("bot-canvas");
            if (conMochi && mochi && /\bopen\b/.test(isla.className) && ri.width > 100) {
                mochiEnIsla = { x: Math.round(mochi.offsetLeft - ri.left), y: Math.round(mochi.offsetTop - ri.top) };
                try { localStorage.setItem("cc-mochi-en-isla", JSON.stringify(mochiEnIsla)); } catch (e) {}
            }
            requestAnimationFrame(() => setTimeout(aprenderTamano, 400));
        });
        return true;
    }

    // La isla se abre, se cierra o pasa de un panel a otro. modo: "abre" (nace del botón que se tocó:
    // el mochi, el buscador, los juegos, las notificaciones…), "cierra" (se encoge hacia ese botón)
    // o "cambia" (ya abierta, de un panel a otro: el de antes vuelve a su botón —antes— y el nuevo
    // nace del suyo, cada uno por separado; estirar uno hasta el otro deformaba el contenido).
    // Se avisa enseguida, antes de que la página se vuelva a pintar: los cuadros de la barra se pausan,
    // así la foto de "antes" es todavía como estaba.
    function transicion(modo, boton, antes) {
        const isla = $("island"), mochi = $("bot-canvas");
        if (!isla || !boton) return;
        const conMochi = boton.classList.contains("mb-mochi");
        // (cerrando, la barra lleva al mochi de vuelta al dock con su propia animación: sus cuadros
        // siguen y el mochi no entra en la transición; su dibujo cambia de tamaño y lugar adentro de
        // su canvas, así que fijarlo no sirve)
        // Abriendo o pasando a otro panel se pausan los cuadros de la barra (si no, la transición
        // arranca trabada). Saliendo del panel del mochi, el dibujito (que la barra lleva de vuelta al
        // dock) se oculta mientras tanto y reaparece ya en el dock; si no, quedaba flotando.
        if (modo !== "cierra") pausar(true);
        const sinMochi = modo === "cambia" && antes && antes.classList.contains("mb-mochi");
        if (sinMochi) raiz.classList.add("cc-sin-mochi");
        enTransicion = true;
        clearTimeout(soltar);
        raiz.classList.remove("cc-fija", "cc-fija-mochi", "cc-cerrando");
        if (modo !== "cierra") nombrar(boton, "cc-isla");
        if (modo !== "abre") {
            const ri = isla.getBoundingClientRect(), rb = (modo === "cambia" && antes ? antes : boton).getBoundingClientRect();
            fijar({ ox: px(rb.left + rb.width / 2 - ri.left), oy: px(rb.top + rb.height / 2 - ri.top) });
            nombrar(isla, "cc-isla-sale");
        }
        if (modo !== "cierra" && conMochi) nombrar(mochi, "cc-mochi");
        const t = document.startViewTransition(() => {
            nombrar(boton, ""); nombrar(isla, "");
            if (modo === "cierra") {
                raiz.classList.add("cc-cerrando");
                soltarLuego(1300);
                if (soltarAlCerrar) {
                    // (desde la pantalla completa: la foto de antes es el panel grande, que se encoge
                    // hacia su botón; el mochi, que no va en ella, aparece después en el dock)
                    soltarAlCerrar = false;
                    soltarGrande(true);
                    raiz.classList.add("cc-sin-mochi");
                    setTimeout(() => raiz.classList.remove("cc-sin-mochi"), 600);
                }
            } else if (fijarEn(boton, conMochi)) {
                nombrar(isla, "cc-isla");
            } else {
                // No se sabe todavía cómo queda el panel nuevo: se oculta mientras la barra lo acomoda
                // y después nace de su botón (así nunca se ve deformado ni viajando)
                raiz.classList.add("cc-oculta");
                acomodando = true;
                pausar(false);
            }
        });
        let acomodando = false;
        if (modo !== "cierra") t.ready.then(() => { if (!acomodando) pausar(true); }, () => {});
        t.finished.finally(() => {
            pausar(false);
            if (sinMochi) setTimeout(() => raiz.classList.remove("cc-sin-mochi"), 550);
            nombrar(isla, ""); nombrar(boton, ""); nombrar(mochi, "");
            if (!acomodando) { enTransicion = false; return; }
            esperarQuieta(() => {
                raiz.classList.remove("cc-oculta");
                enTransicion = false;
                if (/\bopen\b/.test(isla.className)) transicion("abre", boton);
            });
        });
    }

    // Espera a que la isla quede quieta (el resorte de la barra terminó) y entonces sigue
    function esperarQuieta(seguir) {
        const isla = $("island");
        let antes = "", iguales = 0, vueltas = 0;
        const mirar = () => {
            const k = isla.style.width + "|" + isla.style.height;
            iguales = k === antes ? iguales + 1 : 0;
            antes = k;
            if (iguales >= 2 || ++vueltas > 30) { aprenderTamano(); seguir(); }
            else setTimeout(mirar, 40);
        };
        setTimeout(mirar, 60);
    }

    // (el saludo del arranque abre y cierra la isla a su manera: eso no se toca)
    let listo = false;
    setTimeout(() => { listo = true; }, 4000);
    // Qué botón de la barra se tocó (el mochi, el buscador, los juegos, las notificaciones, "en
    // segundo plano"…: los que abren la isla; las apps del dock no) y desde cuál se abrió la isla
    const abridor = el => el && el.closest && el.closest("#menubar .mb-mochi, #menubar .mb-btn:not(.mb-system)");
    let tocado = null, tocadoEn = 0, origen = null;
    window.addEventListener("mousedown", e => {
        const b = e.button === 0 && abridor(e.target);
        if (b) { tocado = b; tocadoEn = Date.now(); }
    }, true);
    // Con la isla abierta, otro botón: pasa de un panel al otro (la clase "open" no cambia)
    window.addEventListener("click", e => {
        const b = abridor(e.target), isla = $("island");
        // (con el panel del mochi en pantalla completa, otro panel no: vuelve antes a su tamaño)
        if (b && !b.classList.contains("mb-mochi")) soltarGrande();
        if (!b || !isla || !abierta || !origen || b === origen || !listo || enTransicion || !document.startViewTransition) return;
        const antes = origen;
        origen = b;
        transicion("cambia", b, antes);
    }, true);
    let focoPendiente = null;
    function devolverFoco() {
        const c = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.coucou;
        if (!c) return;
        clearTimeout(focoPendiente);
        focoPendiente = setTimeout(() => { if (!/\bopen\b/.test(($("island") || {}).className || "")) c.postMessage({ abrir: "foco" }); }, 200);
    }
    let abierta = null, soltarAlCerrar = false;
    function vigilar() {
        const isla = $("island");
        if (!isla) return false;
        abierta = /\bopen\b/.test(isla.className);
        new MutationObserver(() => {
            const ahora = /\bopen\b/.test(isla.className);
            if (ahora === abierta) return;
            abierta = ahora;
            // Cerrada: si la barra se quedó con el foco (se escribió en el panel), que vuelva a la
            // ventana de adelante; si no, su botón del dock la traía en vez de minimizarla
            // (con el panel en pantalla completa, se deja de estarlo adentro de la animación de cerrarse:
            // antes, el panel grande pasaba de golpe a chico y recién ahí se cerraba —un parpadeo—)
            if (!ahora) { if (grande) soltarAlCerrar = true; devolverFoco(); }
            else {
                setTimeout(precargar, 1200);
                // (minimizado: vuelve grande, ya abierto el panel, si se abrió con el mochi)
                if (minimizado) {
                    minimizado = false;
                    if (Date.now() - tocadoEn < 1500 && tocado && tocado.classList.contains("mb-mochi")) setTimeout(() => pantallaCompleta(true), 650);
                }
            }
            const desde = ahora ? (Date.now() - tocadoEn < 1500 && tocado && tocado.isConnected ? tocado : null) : origen;
            origen = ahora ? desde : null;
            if (ahora) setTimeout(aprenderTamano, 1800);
            const animar = listo && !enTransicion && document.startViewTransition && desde;
            if (animar) transicion(ahora ? "abre" : "cierra", desde);
            // (sin animación: de una)
            else if (soltarAlCerrar) { soltarAlCerrar = false; soltarGrande(true); }
        }).observe(isla, { attributes: true, attributeFilter: ["class"] });
        return true;
    }
    if (!vigilar()) {
        const espera = new MutationObserver(() => { if (vigilar()) espera.disconnect(); });
        espera.observe(document.documentElement, { childList: true, subtree: true });
    }

    // "Pantalla completa" (el botón de arriba a la derecha del panel del mochi, que abría la ventana
    // aparte de Coucou Code): el mismo panel crece hasta ocupar la pantalla (sobre la barra, que queda
    // en su lugar), siempre en el Chat y acomodado como Visual Studio Code: el chat a la derecha (lo
    // que había en el panel, el cuadro de escribir abajo) y Coucou Code en el resto (el explorador a la
    // izquierda, el editor y la terminal abajo); las otras pestañas siguen mostrando lo suyo solo.
    // La ventana de la barra es de toda la pantalla (libcoucou-web.so la deja así: transparente, recibe
    // clics solo en el dock y el panel; con COUCOU_BARRA_CHICA=1 se la agranda en el momento) y el panel crece con
    // una transición como las de los paneles: el recuadro va del panel a la pantalla y adentro el
    // Coucou Code de pantalla completa se va descubriendo, mientras el mochi, las pestañas, el
    // proyecto, el modelo y lo del chat (el cuadro de escribir, la presentación, las tarjetas, la
    // conversación) viajan a su lugar nuevo. El mismo botón (o cerrar el panel) lo devuelve.
    let grande = false, cambiandoGrande = false, ventanaChica = false;
    const canalWeb = () => window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.coucou;
    // Hasta que pase algo (o un rato)
    const hasta = (cond, ms) => new Promise(listo => {
        const fin = performance.now() + ms;
        const mirar = () => (cond() || performance.now() > fin) ? listo() : rafReal(mirar);
        mirar();
    });
    // El panel grande: toda la pantalla, de borde a borde, menos la barra (como una ventana maximizada)
    function medidasGrande() {
        const mb = $("menubar").getBoundingClientRect(), abajo = !/\bbar-top\b/.test($("root").className), m = 8;
        const y = abajo ? 0 : mb.bottom + m, h = abajo ? mb.top - m : innerHeight - mb.bottom - m;
        fijar({ w: px(innerWidth), h: px(h), y: px(y), cx: px(innerWidth / 2), mx: px(mochiEnIsla.x), my: px(y + mochiEnIsla.y) });
    }
    // Dónde la ventana de la barra recibe clics (set_island_shapes: el panel y la barra; lo demás es
    // transparente y los deja pasar) y dónde está el panel (set_island_rect: tocar fuera lo cierra).
    // La barra los manda con el tamaño que ella le da al panel: con el panel grande, se mandan los
    // suyos (y se repiten mientras tanto, por si la barra los vuelve a mandar); al volver, los del
    // panel de nuevo
    let repetirIsla = null;
    function avisarIsla() {
        const T = window.__TAURI_INTERNALS__, isla = $("island"), barra = $("menubar");
        if (!T || !isla) return;
        const r = isla.getBoundingClientRect(), formas = [[r.left, r.top, r.width, r.height, grande ? 0 : 26]];
        if (barra) { const b = barra.getBoundingClientRect(); formas.push([b.left, b.top, b.width, b.height, b.height / 2]); }
        T.invoke("set_island_shapes", { shapes: formas.map(f => f.map(Math.round)) }).catch(() => {});
        T.invoke("set_island_rect", { x: r.left, y: r.top, width: r.width, height: r.height }).catch(() => {});
    }
    function vigilarIsla(si) {
        clearInterval(repetirIsla);
        repetirIsla = si ? setInterval(avisarIsla, 500) : null;
        avisarIsla();
    }
    // Los que viajan (cada uno con su nombre) y el recuadro del panel
    function nombrarGrande(si) {
        const card = document.querySelector(".chat-card.cx");
        const pares = [[$("island"), "cc-panel"], [$("bot-canvas"), "cc-mochi"],
            [card && card.querySelector(".cx-tabs"), "cc-p-tabs"], [card && card.querySelector(".cx-proj"), "cc-p-proj"],
            [card && card.querySelector(".cx-who"), "cc-p-who"], [card && card.querySelector(".cx-tools"), "cc-p-tools"],
            [card && card.querySelector(".cx-more"), "cc-p-mas"], [card && card.querySelector(".chat-bar"), "cc-p-barra"],
            [card && card.querySelector(".cx-hero-card"), "cc-p-hero"], [card && card.querySelector(".chat-log"), "cc-p-log"],
            ...[...(card ? card.querySelectorAll(".cx-card") : [])].map((e, i) => [e, "cc-p-tarjeta" + i])];
        for (const [e, n] of pares) nombrar(e, si ? n : "");
    }
    async function pantallaCompleta(si) {
        const isla = $("island"), card = document.querySelector(".chat-card.cx"), cuerpo = card && card.querySelector(".chat-body");
        const canal = canalWeb();
        if (cambiandoGrande || si === grande || !isla || !cuerpo || !canal || !document.startViewTransition) return;
        cambiandoGrande = true;
        try {
            if (si) {
                // (la ventana de la barra ya es de toda la pantalla —libcoucou-web.so la deja así—; si no,
                // con COUCOU_BARRA_CHICA=1, se la agranda antes)
                ventanaChica = innerHeight < screen.height * 0.8;
                if (ventanaChica) {
                    canal.postMessage({ abrir: "grande", si: true });
                    await hasta(() => innerHeight > 700 && innerWidth > 1000, 600);
                    await new Promise(r => rafReal(() => rafReal(r)));      // (ya acomodada en la ventana grande)
                }
                avisarIsla();
                pausar(true);
                nombrarGrande(true);
                const t = document.startViewTransition(() => {
                    nombrarGrande(false);
                    medidasGrande();
                    raiz.classList.add("cc-grande");
                    mostrarIde(cuerpo, "vscode");
                    prepararGrande(card);
                    nombrarGrande(true);
                });
                await t.finished.catch(() => {});
                grande = true;
                vigilarIsla(true);
            } else {
                pausar(true);
                nombrarGrande(true);
                raiz.classList.add("cc-achica");
                const t = document.startViewTransition(() => {
                    nombrarGrande(false);
                    raiz.classList.remove("cc-grande");
                    if (cuerpo.dataset.ccVista === "vscode") volverAlChat(cuerpo);
                    nombrarGrande(true);
                });
                await t.finished.catch(() => {});
                raiz.classList.remove("cc-achica");
                grande = false;
                if (ventanaChica) {
                    canal.postMessage({ abrir: "grande", si: false });
                    await hasta(() => innerHeight < 700, 600);
                }
                vigilarIsla(false);
                setTimeout(avisarIsla, 700);
            }
        } finally {
            raiz.classList.remove("cc-achica");
            nombrarGrande(false);
            pausar(false);
            cambiandoGrande = false;
        }
    }
    // (cerrado el panel estando grande: la ventana de la barra vuelve a su tamaño, sin transición)
    // (demora: la ventana de la barra vuelve a su tamaño cuando termina la animación de cerrarse, que
    // se ve en la ventana grande: si se achicaba enseguida, la cortaba)
    function soltarGrande(demora) {
        if (!grande && !raiz.classList.contains("cc-grande")) return;
        grande = false;
        clearInterval(repetirIsla);
        // (y a Coucou, dónde está ahora el panel —cerrándose— y qué recibe clics: la barra no lo
        // vuelve a mandar si para ella no cambió, y se quedaba con lo del panel grande: el dock no
        // recibía clics)
        setTimeout(avisarIsla, 60);
        setTimeout(avisarIsla, 700);
        raiz.classList.remove("cc-grande");
        const cuerpo = document.querySelector(".chat-card.cx .chat-body");
        if (cuerpo && cuerpo.dataset.ccVista === "vscode") volverAlChat(cuerpo);
        const c = canalWeb();
        if (c && ventanaChica) setTimeout(() => c.postMessage({ abrir: "grande", si: false }), demora ? 520 : 0);
    }
    // Cuando la ventana de la barra cambia de tamaño (al agrandar o achicar el panel), su esquina de
    // arriba a la izquierda se mueve en la pantalla. Lo que se ubica pegado a la barra (el dock) queda
    // en su lugar solo, pero lo que la barra ubica con coordenadas (el panel, el aviso, las tareas…)
    // quedaba corrido: un cuadro el panel aparecía en la esquina de la pantalla (o desaparecía), y el
    // mochi y su brillo viajaban desde ahí (la barra los anima hasta donde van). Antes de que se pinte
    // ese cuadro se corren lo mismo que se movió la ventana; el mochi se fija en su lugar de la pantalla
    // hasta que la barra lo alcance, y su brillo se oculta mientras tanto
    const origenVentana = () => ({
        x: (screen.width - innerWidth) / 2,
        y: /\bbar-top\b/.test(($("root") || {}).className || "") ? 0 : screen.height - innerHeight,
    });
    let origenAntes = origenVentana(), quietoMochi = null;
    addEventListener("resize", () => {
        const o = origenVentana(), dx = origenAntes.x - o.x, dy = origenAntes.y - o.y;
        origenAntes = o;
        if (!dx && !dy) return;
        for (const id of ["island", "toast", "jobs", "bar-gear", "upload-layer", "greeting-canvas"]) {
            const e = $(id);
            if (!e) continue;
            if (/px$/.test(e.style.left)) e.style.left = (parseFloat(e.style.left) + dx) + "px";
            if (/px$/.test(e.style.top)) e.style.top = (parseFloat(e.style.top) + dy) + "px";
        }
        // (y las medidas con que se fija la isla mientras anima: ver fijarEn)
        for (const [k, d] of [["cx", dx], ["mx", dx], ["y", dy], ["my", dy]]) {
            const v = raiz.style.getPropertyValue("--cc-" + k);
            if (/px$/.test(v)) raiz.style.setProperty("--cc-" + k, px(parseFloat(v) + d));
        }
        const m = $("bot-canvas");
        if (m && /px$/.test(m.style.left) && !raiz.classList.contains("cc-grande")) {
            // (ya fijo por la animación de la isla: con sus medidas, recién corridas)
            if (!raiz.classList.contains("cc-fija-mochi")) fijar({ mx: px(parseFloat(m.style.left) + dx), my: px(parseFloat(m.style.top) + dy) });
            raiz.classList.add("cc-fija-mochi", "cc-redim");
            clearTimeout(quietoMochi);
            quietoMochi = setTimeout(() => raiz.classList.remove("cc-fija-mochi", "cc-redim"), 800);
        }
    }, true);
    // Los botones de ventana (arriba a la derecha, solo con el panel grande): minimizar (el panel se
    // cierra al dock y, al abrirlo de nuevo, vuelve grande), restaurar (al tamaño del panel) y cerrar
    let minimizado = false;
    const cerrarPanel = () => { const T = window.__TAURI_INTERNALS__; if (T) T.invoke("plugin:event|emit", { event: "outside-click" }).catch(() => {}); };
    const ICONO_VENTANA = {
        min: '<path d="M6 12h12"/>',
        rest: '<rect x="6.5" y="6.5" width="11" height="11" rx="2.5"/>',
        cerrar: '<path d="M7 7l10 10M17 7 7 17"/>',
    };
    function prepararGrande(card) {
        const arriba = card.querySelector(".cx-top"), cuerpo = card.querySelector(".chat-body");
        if (arriba && !arriba.querySelector(".cc-ventana")) {
            const caja = document.createElement("div");
            caja.className = "cc-ventana";
            for (const [a, t] of [["min", "Minimizar"], ["rest", "Restaurar"], ["cerrar", "Cerrar"]]) {
                const b = document.createElement("button");
                b.className = "cc-vbtn cc-v-" + a;
                b.title = t;
                b.innerHTML = `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round">${ICONO_VENTANA[a]}</svg>`;
                b.addEventListener("click", e => {
                    e.stopPropagation();
                    if (a === "rest") pantallaCompleta(false);
                    else { minimizado = a === "min"; cerrarPanel(); }
                });
                caja.append(b);
            }
            arriba.append(caja);
        }
        if (cuerpo && !cuerpo.querySelector(".cc-div-chat")) {
            for (const tipo of ["chat", "term"]) {
                const d = document.createElement("div");
                d.className = "cc-div cc-div-" + tipo;
                d.addEventListener("pointerdown", e => arrastrar(e, tipo, cuerpo));
                cuerpo.append(d);
            }
        }
        requestAnimationFrame(() => ubicarDivisores(cuerpo));
    }
    // Los divisores: el ancho del chat (entre el editor y el chat) y el alto de la terminal; se
    // recuerdan. El de la terminal va sobre el borde de arriba de la terminal (que está en el iframe)
    const TAM = { chat: 0, term: 0 };
    try { Object.assign(TAM, JSON.parse(localStorage.getItem("cc-grande-tamanos")) || {}); } catch (e) {}
    function aplicarTamanos(cuerpo) {
        if (TAM.chat) raiz.style.setProperty("--cc-chat", TAM.chat + "px"); else raiz.style.removeProperty("--cc-chat");
        const d = ide && ide.querySelector("iframe") && ide.querySelector("iframe").contentDocument;
        if (d && d.documentElement) { if (TAM.term) d.documentElement.style.setProperty("--cc-term", TAM.term + "px"); else d.documentElement.style.removeProperty("--cc-term"); }
        if (cuerpo) ubicarDivisores(cuerpo);
    }
    function ubicarDivisores(cuerpo) {
        const dt = cuerpo.querySelector(".cc-div-term"), marco = ide && ide.querySelector("iframe");
        const term = marco && marco.contentDocument && marco.contentDocument.querySelector(".ide-term");
        if (!dt || !term) return;
        const rc = cuerpo.getBoundingClientRect(), rm = marco.getBoundingClientRect(), rt = term.getBoundingClientRect();
        dt.style.left = (rm.left - rc.left + rt.left) + "px";
        dt.style.width = rt.width + "px";
        dt.style.top = (rm.top - rc.top + rt.top - 7) + "px";
    }
    function arrastrar(e, tipo, cuerpo) {
        e.preventDefault();
        const div = e.currentTarget;
        div.setPointerCapture(e.pointerId);
        raiz.classList.add("cc-arrastrando");
        const marco = ide && ide.querySelector("iframe");
        const mover = ev => {
            if (tipo === "chat") TAM.chat = Math.round(Math.max(300, Math.min(innerWidth * 0.55, innerWidth - ev.clientX - 6)));
            else {
                const rm = marco.getBoundingClientRect(), w = marco.contentDocument.querySelector(".ide-work");
                const fondo = w ? rm.top + w.getBoundingClientRect().bottom : rm.bottom;
                TAM.term = Math.round(Math.max(110, Math.min(fondo - rm.top - 220, fondo - ev.clientY)));
            }
            aplicarTamanos(cuerpo);
        };
        const soltar = () => {
            div.removeEventListener("pointermove", mover);
            raiz.classList.remove("cc-arrastrando");
            try { localStorage.setItem("cc-grande-tamanos", JSON.stringify(TAM)); } catch (e) {}
        };
        div.addEventListener("pointermove", mover);
        div.addEventListener("pointerup", soltar, { once: true });
        div.addEventListener("pointercancel", soltar, { once: true });
    }
    addEventListener("resize", () => { const c = document.querySelector(".chat-card.cx .chat-body.cc-vscode"); if (c) ubicarDivisores(c); });
    // Coucou Code (y su terminal) se cargan antes, en el fondo, cuando se abre el panel del mochi:
    // cargarlo al agrandarlo trababa la animación
    function precargar() {
        const cuerpo = document.querySelector(".chat-card.cx .chat-body");
        if (!cuerpo || ide && cuerpo.contains(ide)) return;
        // (con su tamaño, invisible: la terminal se arma para ese ancho; oculto, salía de dos columnas)
        cuerpo.classList.add("cc-precarga");
        asegurarIde(cuerpo, true);
        setTimeout(() => cuerpo.classList.remove("cc-precarga"), 4000);
    }
    window.addEventListener("click", e => {
        if (!(e.target.closest && e.target.closest("button.hdr-expand"))) return;
        e.stopImmediatePropagation(); e.preventDefault();
        pantallaCompleta(!grande);
    }, true);
    window.addEventListener("keydown", e => { if (e.key === "Escape" && grande) { e.stopImmediatePropagation(); pantallaCompleta(false); } }, true);
    // Código, Archivos y Terminal (las pestañas de arriba del chat del mochi): se abren adentro del
    // mismo panel, debajo de las pestañas, en vez de en la ventana aparte de Coucou Code. Es la misma
    // página de Coucou Code (/ide.html, en un iframe) sin su chat ni su barra de arriba (el chat es
    // la pestaña Chat). Las tres se dividen igual que el Chat: una columna a la izquierda, debajo del
    // dibujito del mochi (que queda en el mismo lugar que en el Chat, con su espacio libre arriba de
    // ella), y lo principal a la derecha, desde arriba. Código: el explorador a la izquierda y el
    // editor a la derecha. Archivos: como un explorador de archivos, el árbol de carpetas a la izquierda
    // y lo que hay en la elegida a la derecha (ver archivos()). Terminal: las terminales abiertas y el + para abrir otra a la
    // izquierda, la terminal a la derecha. Chat vuelve a la conversación; lo de abajo del panel se
    // oculta sin achicarlo (visibility), así el panel no cambia de tamaño.
    // El proyecto es el mismo que el del chat (los dos lo guardan en "coucou.oc.project").
    const VISTAS = [null, "codigo", "archivos", "terminal"];   // en el orden de las pestañas
    const FOCO = { codigo: "code", archivos: "files", terminal: "terminal", vscode: "code" };
    // Las medidas de la columna del Chat: su ancho y dónde empieza (debajo del lugar del mochi, donde
    // en el Chat está "Conversación")
    const COLUMNA = 158, MOCHI_ALTO = 112, ENTRE = 12;   // (ENTRE: lo que separa las tarjetas, como en el Chat)
    const ESTILO_IDE = `
        html, body.ide-window { background: transparent !important; }
        .ide-top, .ide-status, .ide-chat, .ide-grip-v, .ide-grip-h,
        .ide-files > .ide-pane-head:first-child, .ide-sessions, .ide-term-head > .grow { display: none !important; }
        .ide-explorer { border-top: 0 !important; flex: 1 1 auto !important; }
        .ide-body, .ide-work { gap: ${ENTRE}px; }
        /* Las tarjetas, como las del Chat: su color y su borde (--cc-card y --cc-line, que pone ideVista) */
        .ide-files, .ide-main, .ide-term-head, .ide-term-body { border: 1px solid var(--cc-line, var(--ide-border)) !important; border-radius: 18px; overflow: hidden; background: var(--cc-card, var(--ide-panel)) !important; }
        .ide-main { box-shadow: none !important; }   /* (la de Coucou Code: ninguna otra tarjeta la tiene) */
        .ide-tabs { border-bottom-color: var(--cc-line, var(--ide-border)) !important; }
        /* Las tarjetitas de la bienvenida, como las del Chat (--cc-tarjeta y --cc-tarjeta-borde) */
        .ide-wcard { background: var(--cc-tarjeta, #fff) !important; border-color: var(--cc-tarjeta-borde, var(--ide-border)) !important; box-shadow: none !important; }
        .ide-wcard:hover { background: var(--ide-panel-solid) !important; border-color: rgba(124, 108, 246, .4) !important; }
        html.cc-v-codigo .ide-main, html.cc-v-codigo .ide-main.off { display: flex !important; flex: 1 1 auto !important; width: auto !important; max-width: none !important; min-width: 0 !important; position: static !important; }
        html.cc-v-codigo .ide-files, html.cc-v-codigo .ide-files.off { display: flex !important; flex: 0 0 ${COLUMNA}px !important; width: ${COLUMNA}px !important; margin-top: ${MOCHI_ALTO}px !important; }
        html.cc-v-codigo .ide-term { display: none !important; }
        html.cc-v-archivos .ide-files, html.cc-v-archivos .ide-work { display: none !important; }
        .cc-arch { display: none; }
        html.cc-v-archivos .cc-arch { display: flex; flex: 1 1 auto; gap: ${ENTRE}px; min-width: 0; min-height: 0; }
        .cc-arch-arbol, .cc-arch-lista { display: flex; flex-direction: column; min-height: 0; border: 1px solid var(--cc-line, var(--ide-border)); border-radius: 18px; overflow: hidden; background: var(--cc-card, var(--ide-panel)); }
        .cc-arch-arbol { flex: 0 0 ${COLUMNA}px; width: ${COLUMNA}px; margin-top: ${MOCHI_ALTO}px; }
        .cc-arch-lista { flex: 1 1 auto; min-width: 0; }
        .cc-arch-cuerpo { flex: 1 1 auto; overflow: auto; padding: 2px 0 8px; }
        .cc-arch-fila { display: flex !important; align-items: center; gap: 6px; cursor: default; user-select: none; }
        .cc-arch-ico { display: inline-flex; flex: none; opacity: 0.8; }
        .cc-arch-ico.chev { opacity: 0.55; transition: rotate 0.15s; }
        .cc-arch-fila.open > .chev { rotate: 90deg; }
        .cc-arch-nombre { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .cc-arch-tipo { margin-left: auto; padding: 0 14px 0 12px; flex: none; opacity: 0.55; font-size: 11.5px; }
        .cc-arch-ruta { gap: 2px; min-width: 0; overflow: hidden; white-space: nowrap; }
        .cc-arch-ruta button { all: unset; cursor: pointer; padding: 2px 6px; border-radius: 6px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; }
        .cc-arch-ruta button:hover { background: var(--ide-border); }
        .cc-arch-ruta button:last-child { cursor: default; background: none; }
        .cc-arch-ruta .sep { opacity: 0.45; }
        .cc-arch-vacio { padding: 22px; opacity: 0.6; text-align: center; }
        html.cc-v-terminal .ide-files, html.cc-v-terminal .ide-split { display: none !important; }
        html.cc-v-terminal .ide-term, html.cc-v-terminal .ide-term.off { display: flex !important; flex-direction: row !important; gap: ${ENTRE}px; flex: 1 1 auto !important; height: auto !important; border: 0 !important; background: transparent !important; }
        html.cc-v-terminal .ide-term-head { flex: 0 0 ${COLUMNA}px !important; width: ${COLUMNA}px !important; height: auto !important; margin-top: ${MOCHI_ALTO}px !important;
            display: grid !important; grid-template-columns: 1fr auto; align-content: start; align-items: center; gap: 8px; padding: 10px !important; }
        html.cc-v-terminal .ide-term-head > .ide-mini { grid-row: 1; grid-column: 2; }
        html.cc-v-terminal .ide-term-tabs { grid-row: 2; grid-column: 1 / -1;display: flex !important; flex-direction: column !important; align-items: stretch !important; gap: 4px; overflow: auto; }
        html.cc-v-terminal .ide-term-tabs > * { width: 100% !important; justify-content: flex-start; box-sizing: border-box; }
        /* (del alto que se ve, no más: si crecía con lo escrito, las últimas filas quedaban tapadas) */
        html.cc-v-terminal .ide-work, html.cc-v-terminal .ide-term { min-height: 0 !important; }
        html.cc-v-terminal .ide-term { flex: 1 1 0 !important; }
        html.cc-v-terminal .ide-term-body { flex: 1 1 auto !important; min-width: 0 !important; min-height: 0 !important; height: auto !important; }
        html.cc-v-terminal .ide-term-body { padding-top: 12px !important; box-sizing: border-box !important; }   /* (aire arriba del primer renglón) */
        html.cc-v-terminal .ide-xterm { height: 100% !important; }
        /* vscode: el explorador a la izquierda (debajo del mochi), el editor y, abajo, la terminal */
        html.cc-v-vscode .ide-files, html.cc-v-vscode .ide-files.off { display: flex !important; flex: 0 0 ${COLUMNA}px !important; width: ${COLUMNA}px !important; margin-top: ${MOCHI_ALTO}px !important; }
        html.cc-v-vscode .ide-main, html.cc-v-vscode .ide-main.off { display: flex !important; flex: 1 1 auto !important; width: auto !important; max-width: none !important; min-width: 0 !important; position: static !important; }
        html.cc-v-vscode .ide-work, html.cc-v-vscode .ide-split { min-height: 0 !important; }
        html.cc-v-vscode .ide-split { flex: 1 1 0 !important; }
        html.cc-v-vscode .ide-term, html.cc-v-vscode .ide-term.off { display: flex !important; flex-direction: column !important; flex: 0 0 var(--cc-term, 30%) !important; height: auto !important; min-height: 0 !important;
            border: 1px solid var(--cc-line, var(--ide-border)) !important; border-radius: 18px; overflow: hidden; background: var(--cc-card, var(--ide-panel)) !important; }
        html.cc-v-vscode .ide-term-head, html.cc-v-vscode .ide-term-body { border: 0 !important; border-radius: 0 !important; background: transparent !important; }
        html.cc-v-vscode .ide-term-body { flex: 1 1 auto !important; min-height: 0 !important; padding-top: 4px !important; }
        html.cc-v-vscode .ide-xterm { height: 100% !important; }
        /* Las filas de la columna de la izquierda (el explorador, las carpetas, las terminales) y de la
           lista de Archivos, como las del Chat: la elegida, con el violeta de acento de fondo y en la letra */
        .ide-files .ide-row, .cc-arch .ide-row { height: 30px; margin: 1px 6px; border-radius: 9px; }
        .ide-row.on { background: rgba(109, 93, 240, .12) !important; color: var(--ide-accent) !important; font-weight: 600; }
        .ide-row.on svg { color: var(--ide-accent) !important; }
        html.cc-v-terminal .ide-term-head { padding: 0 6px 6px !important; gap: 2px 8px !important; }
        html.cc-v-terminal .ide-term-head .ide-pane-title { padding-left: 8px; line-height: 38px; text-transform: none; letter-spacing: 0; color: var(--ide-ink); font-size: 12.5px; font-weight: 700; }
        html.cc-v-terminal .ide-term-tab { height: 32px !important; padding: 0 6px 0 10px !important; border-radius: 9px !important; color: var(--ide-ink) !important; font-size: 12.5px !important; }
        html.cc-v-terminal .ide-term-tab:hover { background: var(--ide-hover) !important; }
        html.cc-v-terminal .ide-term-tab.on { background: rgba(109, 93, 240, .12) !important; color: var(--ide-accent) !important; font-weight: 600; }
        html.cc-v-terminal .ide-term-tab > :last-child { margin-left: auto; }
        /* La bienvenida de Código, más compacta (y centrada sin cortarse arriba si no entra) */
        .ide-welcome { justify-content: flex-start !important; gap: 14px !important; padding: 16px 20px !important; }
        .ide-welcome > :first-child { margin-top: auto; }
        .ide-welcome > :last-child { margin-bottom: auto; }
        .ide-w-logo { width: 42px !important; height: 42px !important; border-radius: 13px !important; box-shadow: 0 6px 18px rgba(109, 93, 240, .35) !important; }
        .ide-w-logo svg { width: 20px; height: 20px; }
        .ide-w-hero h1 { margin: 10px 0 2px !important; font-size: 20px !important; }
        .ide-w-hero p { font-size: 12.5px !important; }
        .ide-w-cards { grid-template-columns: repeat(2, minmax(160px, 240px)) !important; gap: 8px !important; }
        .ide-w-cards > * { padding-top: 8px !important; padding-bottom: 8px !important; min-height: 0 !important; }
        .ide-w-recent { width: min(488px, 100%) !important; }
        .ide-w-rec { height: 30px !important; }
    `;
    let ide = null, ideProyecto = "";
    const proyecto = () => { try { return localStorage.getItem("coucou.oc.project") || ""; } catch (e) { return ""; } };

    // El zoom de la terminal, como en cualquier terminal: Ctrl + y Ctrl − (o Ctrl y la rueda del
    // ratón) agrandan y achican la letra, Ctrl 0 la vuelve a la normal, y se recuerda. Con cada
    // cambio la terminal recalcula cuántas columnas y filas le entran (y se lo dice al programa que
    // corre adentro). Las terminales (xterm.js) quedan guardadas adentro del código de Coucou Code:
    // se las ve nacer desde __ccMarco, que libcoucou-web.so llama en el iframe antes de que ese
    // código corra (cada terminal, al crearse, guarda su _addonManager).
    // La letra (px) y el espacio entre renglones (con 1, las líneas quedaban casi pegadas). "cc-term-tamano":
    // el tamaño elegido (el de antes, "cc-term-letra", era con los renglones pegados: se vuelve a empezar)
    const LETRA = 13, LETRA_MIN = 8, LETRA_MAX = 32, INTERLINEA = 1.25;
    let letra = LETRA;
    try { const g = +localStorage.getItem("cc-term-tamano"); if (g >= LETRA_MIN && g <= LETRA_MAX) letra = g; localStorage.removeItem("cc-term-letra"); } catch (e) {}
    // Los colores de la terminal, uno para cada tema de la barra: el fondo transparente (se ve el de su
    // tarjeta, como todo lo demás) y los de los programas (ls, git…) que se lean sobre él (los de
    // siempre de xterm son para fondo oscuro: en el claro el verde y el celeste casi no se leían)
    const TEMAS_TERMINAL = {
        light: {
            background: "#00000000", foreground: "#26214d", cursor: "#6d5df0", cursorAccent: "#ffffff", selectionBackground: "#d9d3fb",
            black: "#26214d", brightBlack: "#8a86a8", white: "#d8d4ec", brightWhite: "#f2f0fb",
            red: "#c62f4b", green: "#1f8a4c", yellow: "#9a6700", blue: "#3b5bdb", magenta: "#8e3fbf", cyan: "#0b7a87",
            brightRed: "#d9415d", brightGreen: "#2a9d5c", brightYellow: "#b07b00", brightBlue: "#4c6ef5", brightMagenta: "#a14fd1", brightCyan: "#0f8f9e",
        },
        dark: {
            background: "#00000000", foreground: "#ece9ff", cursor: "#8b7cf6", cursorAccent: "#1a1832", selectionBackground: "#4b3fa8",
            black: "#1d1b33", brightBlack: "#6b6788", white: "#d7d3f0", brightWhite: "#ffffff",
            red: "#ff6b81", green: "#4ade80", yellow: "#facc15", blue: "#7aa2ff", magenta: "#c084fc", cyan: "#22d3ee",
            brightRed: "#ff8fa0", brightGreen: "#86efac", brightYellow: "#fde047", brightBlue: "#a5bfff", brightMagenta: "#d8b4fe", brightCyan: "#67e8f9",
        },
    };
    const temaBarra = () => document.documentElement.dataset.theme === "dark" ? "dark" : "light";
    window.__ccMarco = w => {
        const terminales = new Set();
        const ajustar = t => {
            try {
                const o = t.options;
                if (o.fontSize !== letra) o.fontSize = letra;
                if (o.lineHeight !== INTERLINEA) o.lineHeight = INTERLINEA;
                if (o.theme !== TEMAS_TERMINAL[temaBarra()]) o.theme = TEMAS_TERMINAL[temaBarra()];
            } catch (e) { return; }
            for (const a of (t._addonManager && t._addonManager._addons) || [])
                if (a.instance && typeof a.instance.fit === "function") try { a.instance.fit(); } catch (e) {}
        };
        Object.defineProperty(w.Object.prototype, "_addonManager", {
            configurable: true,
            set(v) {
                Object.defineProperty(this, "_addonManager", { value: v, writable: true, configurable: true });
                terminales.add(this);
                // La letra se pone cuando Coucou Code ya escucha los cambios de tamaño (onResize, después
                // de abrir la terminal de verdad): si no, el programa de adentro no se enteraba
                const d = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(this), "onResize");
                if (d && d.get) Object.defineProperty(this, "onResize", {
                    configurable: true,
                    get() {
                        const evento = d.get.call(this);
                        return (...a) => { const r = evento(...a); setTimeout(() => ajustar(this), 0); return r; };
                    },
                });
                else setTimeout(() => ajustar(this), 0);
            },
        });
        // (las de este Coucou Code, de nuevo: cuando cambia el tema de la barra)
        w.__ccAjustar = () => { for (const t of terminales) if (!t.element || t.element.isConnected) ajustar(t); };
        const zoom = n => {
            letra = Math.max(LETRA_MIN, Math.min(LETRA_MAX, n));
            try { localStorage.setItem("cc-term-tamano", letra); } catch (e) {}
            for (const t of terminales) {
                if (t.element && !t.element.isConnected) terminales.delete(t);   // (una que se cerró)
                else ajustar(t);
            }
        };
        const enTerminal = e => e.target && e.target.closest && e.target.closest(".ide-term-body");
        w.addEventListener("keydown", e => {
            if (!e.ctrlKey || e.altKey || e.metaKey || !enTerminal(e)) return;
            const k = e.key, c = e.code;
            let n = null;
            if (k === "+" || k === "=" || c === "NumpadAdd") n = letra + 1;
            else if (k === "-" || c === "NumpadSubtract") n = letra - 1;
            else if (k === "0" || c === "Numpad0") n = LETRA;
            if (n === null) return;
            e.preventDefault(); e.stopImmediatePropagation();
            zoom(n);
        }, true);
        // (la rueda: un punto por cada muesca; el touchpad manda muchos movimientos chicos, se juntan)
        let giro = 0;
        w.addEventListener("wheel", e => {
            if (!e.ctrlKey || !enTerminal(e) || !e.deltaY) return;
            e.preventDefault(); e.stopImmediatePropagation();
            giro += e.deltaMode === 1 ? e.deltaY * 33 : e.deltaY;
            if (Math.abs(giro) < 50) return;
            zoom(letra + (giro < 0 ? 1 : -1));
            giro = 0;
        }, { capture: true, passive: false });
    };

    // Archivos, como un explorador de archivos: a la izquierda (debajo del mochi) el árbol con las
    // carpetas del proyecto; a la derecha, lo que hay en la carpeta elegida, con su ruta arriba (cada
    // parte lleva ahí). Doble clic en una carpeta entra en ella; en un archivo, lo abre en Código. La
    // lista la da Coucou Code mismo (fs_list); para abrir un archivo se despliega su explorador hasta
    // él y se lo toca, como a mano. Cada vez que se muestra, se vuelve a leer.
    const ICONOS = {
        chev: '<path d="m9 18 6-6-6-6"/>',
        carpeta: '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
        abierta: '<path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"/>',
        archivo: '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
    };
    function archivos(cuerpo, w) {
        const d = w.document, raiz = proyecto() || ideProyecto;
        const viejo = d.querySelector(".cc-arch");
        if (viejo && viejo.dataset.raiz === raiz) { viejo.ccRefrescar && viejo.ccRefrescar(); return; }
        if (viejo) viejo.remove();
        const nuevo = (tag, clase, texto) => { const e = d.createElement(tag); if (clase) e.className = clase; if (texto) e.textContent = texto; return e; };
        const icono = (nombre, tam = 15) => {
            const s = nuevo("span", "cc-arch-ico " + nombre);
            s.innerHTML = `<svg viewBox="0 0 24 24" width="${tam}" height="${tam}" fill="none" stroke="currentColor" stroke-width="${nombre === "chev" ? 2.2 : 1.7}" stroke-linecap="round" stroke-linejoin="round">${ICONOS[nombre]}</svg>`;
            return s;
        };
        const listar = p => w.__TAURI_INTERNALS__.invoke("fs_list", { path: p }).catch(() => []);
        const nombreDe = p => p.slice(p.lastIndexOf("/") + 1) || p;
        const a = nuevo("div", "cc-arch");
        a.dataset.raiz = raiz;
        const arbol = nuevo("aside", "cc-arch-arbol"), lista = nuevo("section", "cc-arch-lista");
        const cabeza = nuevo("div", "ide-pane-head");
        cabeza.append(nuevo("span", "ide-side-title", "Carpetas"));
        const ramas = nuevo("div", "cc-arch-cuerpo"), ruta = nuevo("div", "ide-pane-head cc-arch-ruta"), contenido = nuevo("div", "cc-arch-cuerpo");
        arbol.append(cabeza, ramas);
        lista.append(ruta, contenido);
        a.append(arbol, lista);
        d.querySelector(".ide-body").append(a);
        if (!raiz) { contenido.append(nuevo("div", "cc-arch-vacio", "Abre o crea un proyecto para empezar.")); return; }

        const abiertas = new Set([raiz]);
        let actual = raiz;
        // El árbol: solo carpetas. Tocar una la elige (y la abre); la flechita la abre o la cierra
        function fila(dir, nombre, nivel) {
            const f = nuevo("div", "ide-row cc-arch-fila"), hijos = nuevo("div");
            f.style.paddingLeft = (6 + nivel * 12) + "px";
            f.title = dir;
            f.classList.toggle("open", abiertas.has(dir));
            f.classList.toggle("on", dir === actual);
            f.append(icono("chev", 11), icono(abiertas.has(dir) ? "abierta" : "carpeta"), nuevo("span", "cc-arch-nombre", nombre));
            f.addEventListener("click", e => {
                if (e.target.closest(".chev")) { abiertas.has(dir) ? abiertas.delete(dir) : abiertas.add(dir); pintarArbol(); }
                else ir(dir);
            });
            if (abiertas.has(dir)) listar(dir).then(l => { for (const h of l) if (h.dir) hijos.append(...fila(h.path, h.name, nivel + 1)); });
            return [f, hijos];
        }
        const pintarArbol = () => ramas.replaceChildren(...fila(raiz, nombreDe(raiz), 0));
        // La derecha: la ruta y lo que hay en la carpeta elegida
        async function pintarLista() {
            const pedida = actual;
            ruta.replaceChildren();
            const partes = [raiz, ...actual.slice(raiz.length + 1).split("/").filter(Boolean)];
            let p = "";
            partes.forEach((parte, i) => {
                p = i ? p + "/" + parte : parte;
                const destino = p, b = nuevo("button", "", i ? parte : nombreDe(raiz));
                b.addEventListener("click", () => destino !== actual && ir(destino));
                if (i) ruta.append(nuevo("span", "sep", "›"));
                ruta.append(b);
            });
            const l = await listar(pedida);
            if (pedida !== actual) return;
            contenido.replaceChildren();
            if (!l.length) { contenido.append(nuevo("div", "cc-arch-vacio", "Esta carpeta está vacía")); return; }
            for (const h of l) {
                const f = nuevo("div", "ide-row cc-arch-fila"), punto = h.name.lastIndexOf(".");
                f.style.paddingLeft = "12px";
                f.title = h.path;
                f.append(icono(h.dir ? "carpeta" : "archivo"), nuevo("span", "cc-arch-nombre", h.name),
                         nuevo("span", "cc-arch-tipo", h.dir ? "Carpeta" : punto > 0 ? h.name.slice(punto + 1).toUpperCase() : "Archivo"));
                f.addEventListener("click", () => { for (const o of contenido.children) o.classList.toggle("on", o === f); });
                f.addEventListener("dblclick", () => h.dir ? ir(h.path) : abrir(h.path));
                contenido.append(f);
            }
        }
        function ir(dir) {
            actual = dir;
            for (let p = dir; p.length >= raiz.length; p = p.slice(0, p.lastIndexOf("/"))) abiertas.add(p);
            pintarArbol();
            pintarLista();
        }
        async function abrir(archivo) {
            mostrarIde(cuerpo, "codigo");
            const filaDe = p => [...d.querySelectorAll(".ide-tree .ide-row")].find(r => r.dataset.path === p);
            const esperar = async p => {
                for (let i = 0; i < 40; i++) { const r = filaDe(p); if (r) return r; await new Promise(z => setTimeout(z, 50)); }
                return null;
            };
            let dir = raiz;
            for (const parte of archivo.slice(raiz.length + 1).split("/").slice(0, -1)) {
                dir += "/" + parte;
                const r = await esperar(dir);
                if (!r) return;
                if (!r.classList.contains("open")) r.click();
            }
            const r = await esperar(archivo);
            if (r) r.click();
        }
        a.ccRefrescar = () => { pintarArbol(); pintarLista(); };
        a.ccRefrescar();
    }

    // El tema de Coucou Code, el de la barra (claro u oscuro: solo, se quedaba en el claro y en el
    // oscuro sus letras no se veían sobre las tarjetas), con el color y el borde de las tarjetas del
    // Chat y de sus tarjetitas. Al abrirlo y cada vez que la barra cambia de tema.
    function ideTema(w) {
        const d = w.document, raiz = d.documentElement;
        if (raiz.dataset.theme !== temaBarra()) raiz.dataset.theme = temaBarra();
        // (si Coucou Code se pone otro, por su cuenta, vuelve al de la barra)
        if (!w.__ccTemaVigilado) {
            w.__ccTemaVigilado = true;
            new w.MutationObserver(() => { if (raiz.dataset.theme !== temaBarra()) raiz.dataset.theme = temaBarra(); })
                .observe(raiz, { attributes: true, attributeFilter: ["data-theme"] });
        }
        const panel = document.querySelector(".chat-card.cx .cx-panel");
        if (panel) {
            const c = getComputedStyle(panel);
            raiz.style.setProperty("--cc-card", c.backgroundColor);
            raiz.style.setProperty("--cc-line", c.borderTopColor);
        }
        const tarjeta = document.querySelector(".chat-card.cx .cx-card");
        if (tarjeta) {
            const c = getComputedStyle(tarjeta);
            raiz.style.setProperty("--cc-tarjeta", c.backgroundColor);
            raiz.style.setProperty("--cc-tarjeta-borde", c.borderTopColor);
        }
        resaltadoOscuro(w);
        if (w.__ccAjustar) w.__ccAjustar();
    }
    // El editor de Coucou Code (CodeMirror) solo tiene los colores de resaltado del tema claro: en el
    // oscuro, el texto en rojo oscuro, las palabras clave en violeta oscuro… casi no se leían. Se buscan
    // sus reglas (por su color) y, con el tema oscuro, se pintan con colores para fondo oscuro. Las
    // reglas aparecen cuando el editor pinta su texto: se vuelve a mirar cada vez que cambia lo que muestra.
    const RESALTADO_OSCURO = {
        "#708": "#c792ea", "#219": "#82aaff", "#164": "#f78c6c", "#a11": "#c3e88d", "#e40": "#f07178", "#00f": "#82aaff",
        "#30a": "#b4a7ff", "#085": "#ffcb6b", "#167": "#ffcb6b", "#256": "#89ddff", "#f00": "#ff5370", "#940": "#8c8aa8", "#404740": "#9aa0b5",
    };
    const rgbDe = h => { const x = h.length === 4 ? h.replace(/[0-9a-f]/gi, c => c + c) : h; const n = parseInt(x.slice(1), 16); return `rgb(${n >> 16}, ${n >> 8 & 255}, ${n & 255})`; };
    const RESALTADO_RGB = Object.fromEntries(Object.entries(RESALTADO_OSCURO).map(([a, b]) => [rgbDe(a), b]));
    function resaltadoOscuro(w) {
        const d = w.document;
        let css = `html[data-theme="dark"] .cm-cursor { border-left-color: #e6e3ff !important; }
            html[data-theme="dark"] .cm-selectionBackground, html[data-theme="dark"] .cm-focused .cm-selectionBackground { background: rgba(139, 124, 246, .35) !important; }\n`;
        for (const h of [...d.styleSheets, ...(d.adoptedStyleSheets || [])]) {
            let reglas;
            try { reglas = h.cssRules; } catch (e) { continue; }
            for (const r of reglas) {
                const nuevo = r.selectorText && /^\.ͼ\w+$/.test(r.selectorText) && RESALTADO_RGB[r.style && r.style.color];
                if (nuevo) css += `html[data-theme="dark"] ${r.selectorText} { color: ${nuevo} !important; }\n`;
            }
        }
        let s = d.getElementById("cc-resaltado");
        if (!s) { s = d.createElement("style"); s.id = "cc-resaltado"; d.head.append(s); }
        if (s.textContent !== css) s.textContent = css;
        if (!w.__ccEditoresVigilados) {
            w.__ccEditoresVigilados = true;
            let espera = 0;
            new w.MutationObserver(m => {
                if (espera || !m.some(x => x.target.closest && x.target.closest(".cm-content"))) return;
                espera = setTimeout(() => { espera = 0; resaltadoOscuro(w); }, 150);
            }).observe(d.body, { childList: true, subtree: true });
        }
    }
    new MutationObserver(() => {
        const w = ide && ide.querySelector("iframe") && ide.querySelector("iframe").contentWindow;
        // (después de que la barra pinte el tema nuevo, para leer sus colores; y otra vez por si Coucou
        // Code cambió lo suyo después)
        if (w && w.document && w.document.querySelector(".ide-body")) { requestAnimationFrame(() => ideTema(w)); setTimeout(() => ideTema(w), 300); }
    }).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });

    function ideVista(cuerpo, vista) {
        const marco = ide && ide.querySelector("iframe"), w = marco && marco.contentWindow;
        // (todavía sin cargar: cuando cargue, "load" vuelve a llamar)
        if (!w || !w.document || !w.document.querySelector(".ide-body")) return;
        const d = w.document;
        for (const v of [...VISTAS, "vscode"]) if (v) d.documentElement.classList.toggle("cc-v-" + v, v === vista);
        ideTema(w);
        if (!d.getElementById("cc-embebido")) {
            const s = d.createElement("style");
            s.id = "cc-embebido";
            s.textContent = ESTILO_IDE;
            d.head.append(s);
            // (el título de la columna de Terminal, como "Explorador" y "Carpetas")
            const titulo = d.querySelector(".ide-term-head .ide-pane-title");
            if (titulo) titulo.textContent = "Terminales";
        }
        if (vista === "archivos") archivos(cuerpo, w);
        if (vista === "vscode") { aplicarTamanos(cuerpo); requestAnimationFrame(() => ubicarDivisores(cuerpo)); setTimeout(() => ubicarDivisores(cuerpo), 400); }
        const p = proyecto();
        if (p && p !== ideProyecto) { ideProyecto = p; w.dispatchEvent(new w.CustomEvent("coucou-project-changed", { detail: p })); }
        // (en vscode también la terminal, de abajo: la crea si no hay ninguna)
        if (vista === "vscode") w.dispatchEvent(new w.CustomEvent("ide-focus-local", { detail: "terminal" }));
        w.dispatchEvent(new w.CustomEvent("ide-focus-local", { detail: FOCO[vista] }));
        marco.classList.add("listo");
    }
    // vista "vscode": la del panel en pantalla completa con la pestaña Chat (ver pantallaCompleta): el
    // chat a la derecha y Coucou Code (el explorador, el editor y la terminal) en el resto
    function mostrarIde(cuerpo, vista) {
        const tabs = [...cuerpo.querySelectorAll(".cx-tabs .cx-tab")];
        tabs.forEach((t, i) => t.classList.toggle("on", VISTAS[i] === (vista === "vscode" ? null : vista)));
        cuerpo.dataset.ccVista = vista;
        cuerpo.classList.toggle("cc-con-ide", vista !== "vscode");
        cuerpo.classList.toggle("cc-vscode", vista === "vscode");
        asegurarIde(cuerpo);
        ideVista(cuerpo, vista);
    }
    // El iframe de Coucou Code (de antemano: sin vista, oculto, con la terminal ya creada)
    function asegurarIde(cuerpo, antes) {
        const arriba = cuerpo.querySelector(".cx-top");
        if (!ide || !cuerpo.contains(ide)) {
            ide = document.createElement("div");
            ide.className = "cc-ide";
            const marco = document.createElement("iframe");
            ideProyecto = proyecto();
            marco.src = "/ide.html" + (ideProyecto ? "?project=" + encodeURIComponent(ideProyecto) : "");
            marco.addEventListener("load", () => {
                if (cuerpo.dataset.ccVista) ideVista(cuerpo, cuerpo.dataset.ccVista);
                else if (antes) {
                    const w = marco.contentWindow;
                    ideTema(w);
                    w.dispatchEvent(new w.CustomEvent("ide-focus-local", { detail: "terminal" }));
                }
                aplicarTamanos();
            });
            ide.append(marco);
            cuerpo.append(ide);
        }
        if (arriba) ide.style.top = (arriba.offsetTop + arriba.offsetHeight + 10) + "px";
    }
    function volverAlChat(cuerpo) {
        cuerpo.classList.remove("cc-con-ide", "cc-vscode");
        delete cuerpo.dataset.ccVista;
        const tabs = [...cuerpo.querySelectorAll(".cx-tabs .cx-tab")];
        tabs.forEach((t, i) => t.classList.toggle("on", i === 0));
    }
    window.addEventListener("click", e => {
        const tab = e.target.closest && e.target.closest(".chat-card.cx .cx-tabs .cx-tab");
        const cuerpo = tab && tab.closest(".chat-body");
        if (!cuerpo) return;
        const vista = VISTAS[[...tab.parentElement.children].indexOf(tab)];
        if (vista) {
            e.stopImmediatePropagation(); e.preventDefault();
            mostrarIde(cuerpo, vista);
        } else if (grande) {
            // Chat, con el panel en pantalla completa: el chat a la derecha y Coucou Code al lado
            mostrarIde(cuerpo, "vscode");
        } else if (cuerpo.classList.contains("cc-con-ide")) {
            // Chat: de vuelta a la conversación (la barra hace lo suyo: enfocar la caja de texto)
            volverAlChat(cuerpo);
        }
    }, true);

    // Un color de CSS ("rgb(…)", "rgba(…)" o "color(srgb r g b / a)") como #AARRGGBB (el de Qt)
    function hex(css) {
        let m = /color\(srgb\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*\/\s*([\d.]+))?/.exec(css), v;
        if (m) v = [m[1] * 255, m[2] * 255, m[3] * 255, m[4] === undefined ? 1 : +m[4]];
        else if ((m = /rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+))?/.exec(css))) v = [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
        else return "";
        const h = n => Math.round(Math.max(0, Math.min(255, n))).toString(16).padStart(2, "0");
        return "#" + h(v[3] * 255) + h(v[0]) + h(v[1]) + h(v[2]);
    }
    // Los colores de los paneles de la barra (su tema): el degradé de arriba a abajo y el borde
    function colores() {
        const cs = getComputedStyle($("island"));
        const partes = (cs.backgroundImage.match(/(color\([^)]*\)|rgba?\([^)]*\))/g) || []).map(hex).filter(Boolean);
        const solo = hex(cs.backgroundColor);
        return {
            fondo1: partes[0] || solo || "",
            fondo2: partes[partes.length - 1] || solo || "",
            borde: hex(cs.borderTopColor) || "",
        };
    }

    // El botón de Wi-Fi / volumen / batería: el Centro de control de Coucou, en su propia ventana
    const canal = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.coucou;
    const delSistema = e => e.button === 0 && e.target.closest && e.target.closest("#menubar .mb-system");
    if (canal) {
        for (const tipo of ["pointerdown", "mousedown", "pointerup", "mouseup"])
            window.addEventListener(tipo, e => { if (delSistema(e)) e.stopImmediatePropagation(); }, true);
        window.addEventListener("click", e => {
            const b = delSistema(e);
            if (!b) return;
            e.stopImmediatePropagation(); e.preventDefault();
            const r = b.getBoundingClientRect(), barra = $("menubar").getBoundingClientRect();
            const abajo = /\bbar-bottom\b/.test(($("root") || {}).className || "") || barra.top > innerHeight / 2;
            const derecha = Math.max(8, Math.round(innerWidth - r.right));
            // El mismo fondo que los paneles de la barra (los colores de su tema) y la flechita
            // apuntando al botón (a cuántos px del borde derecho del panel). La flecha ocupa 9 px
            // debajo del panel, que queda a 12 px de la barra, como los de la barra.
            const c = colores();
            canal.postMessage({
                abrir: "control",
                barra: abajo ? "abajo" : "arriba",
                margen: String(Math.round((abajo ? innerHeight - barra.top : barra.bottom) + 12 - 9)),
                derecha: String(derecha),
                flecha: String(Math.round(innerWidth - derecha - (r.left + r.width / 2))),
                fondo1: c.fondo1, fondo2: c.fondo2, borde: c.borde,
            });
        }, true);
    }

    // La ventana de Juegos: su "Modo juego" es el de Coucou (/usr/lib/coucou/modo-juego, el mismo
    // del Centro de control), no solo el perfil Rendimiento y "Concentración" como hacía la barra.
    // Lo pide a libcoucou-web.so, que contesta con window.__coucouJuego(estado); mientras está
    // activo se muestra qué quedó en pausa (para que se sepa que algo no anda por eso).
    if (canal) {
        let juego = null;                       // lo último que dijo "modo-juego estado"
        const botonJuego = () => document.querySelector(".gm-view .gm-mode");
        const pintarJuego = () => {
            const b = botonJuego();
            if (!b || !juego) return;
            // (la barra lo pinta según su propio estado al abrir la ventana: se corrige al de Coucou)
            if (b.classList.contains("on") !== !!juego.activo) b.classList.toggle("on", !!juego.activo);
            b.title = juego.activo ? "Modo juego activado. Tócalo de nuevo y todo vuelve a como estaba."
                                   : "Modo juego: pausa lo de fondo, libera RAM y pone todo al máximo";
            let a = document.querySelector(".gm-view .cc-juego-aviso");
            if (juego.activo && juego.aviso) {
                if (!a) {
                    const cabeza = document.querySelector(".gm-view .gm-head");
                    if (!cabeza) return;
                    a = document.createElement("div");
                    a.className = "cc-juego-aviso";
                    cabeza.after(a);
                }
                if (a.textContent !== juego.aviso) a.textContent = juego.aviso;
            } else if (a) a.remove();
        };
        window.__coucouJuego = estado => { juego = estado; pintarJuego(); };
        const pedirJuego = () => canal.postMessage({ abrir: "juego", accion: "estado" });
        const delJuego = e => e.button === 0 && e.target.closest && e.target.closest(".gm-view .gm-mode");
        for (const tipo of ["pointerdown", "mousedown", "pointerup", "mouseup"])
            window.addEventListener(tipo, e => { if (delJuego(e)) e.stopImmediatePropagation(); }, true);
        window.addEventListener("click", e => {
            if (!delJuego(e)) return;
            e.stopImmediatePropagation(); e.preventDefault();
            // Enseguida en el botón; el script lo confirma al terminar
            juego = Object.assign({}, juego || {}, { activo: !(juego && juego.activo), aviso: "" });
            pintarJuego();
            canal.postMessage({ abrir: "juego", accion: "alternar" });
            setTimeout(pedirJuego, 4000);
            setTimeout(pedirJuego, 9000);
        }, true);
        // Con la ventana de Juegos a la vista, el estado al día (también si se cambió desde el
        // Centro de control); el botón lo crea la barra una vez y se vigila desde que aparece
        setInterval(() => {
            const b = botonJuego();
            if (!b) return;
            if (!b.__ccJuego) {
                b.__ccJuego = true;
                new MutationObserver(pintarJuego).observe(b, { attributes: true, attributeFilter: ["class"] });
            }
            if (b.offsetParent !== null && !document.hidden) pedirJuego();
        }, 3000);
    }

})();
