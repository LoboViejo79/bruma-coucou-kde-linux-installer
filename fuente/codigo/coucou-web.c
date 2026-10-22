/*
    Coucou: agrega un script nuestro a la página de la barra (Mochi).

    La barra es una página web (Tauri + WebKitGTK) que viene compilada dentro de /usr/bin/coucou.
    Esta biblioteca se precarga solo en Coucou (coucou-launch, LD_PRELOAD) y, cuando la barra va a
    cargar su página, le suma /usr/share/coucou/web/mochi.js como script de usuario (y mochi.css como
    hoja de estilo de usuario, que la política de seguridad de la página no bloquea): corre en la
    misma página que la barra, así puede animar sus elementos (las transiciones de elementos
    compartidos: el mochi del dock que viaja al panel, el panel que pasa a pantalla completa…).

    La página puede pedir dos cosas afuera, con window.webkit.messageHandlers.coucou.postMessage(…):
      { abrir: "control", barra, margen, derecha, flecha, fondo1, fondo2, borde }: el Centro de
        control de Coucou (los colores, como #AARRGGBB)
      { abrir: "foco" }: que la ventana de adelante vuelva a ser la activa (/usr/lib/coucou/devolver-foco)
      { abrir: "juego", accion: "alternar" | "estado" }: el modo juego de Coucou (/usr/lib/coucou/modo-juego,
        el mismo del Centro de control) desde la ventana de Juegos de la barra; con "estado", la
        respuesta vuelve a la página: window.__coucouJuego({activo, aviso, …})
    Cualquier otro mensaje se ignora.

    COUCOU_WEB_JS=/otro/archivo.js y COUCOU_WEB_CSS=/otro/archivo.css usan otros (pruebas);
    COUCOU_WEB_CONSOLA=1 hace que los console.log de la página salgan por la salida de Coucou.
*/
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <webkit2/webkit2.h>

#define SCRIPT "/usr/share/coucou/web/mochi.js"
#define ESTILO "/usr/share/coucou/web/mochi.css"
// El Coucou Code que mochi.js pone en el panel del mochi (un iframe de /ide.html, de Coucou mismo)
// no recibe lo de Tauri para hablar con Coucou (solo lo tiene la página de arriba): se lo pasa ella.
// Y antes de que corra su código, mochi.js (window.top.__ccMarco) prepara lo suyo (el zoom de la
// terminal, que necesita ver cuándo se crea cada una)
#define MARCOS \
    "if (window.top !== window && !window.__TAURI_INTERNALS__ && location.protocol === 'tauri:'" \
    "    && location.host === 'localhost' && location.pathname === '/ide.html') try {" \
    "  const t = window.top;" \
    "  if (t.location.origin === location.origin && t.__TAURI_INTERNALS__) {" \
    "    for (const k of Object.getOwnPropertyNames(t)) if (k.startsWith('__TAURI')) window[k] = t[k];" \
    "    if (typeof t.__ccMarco === 'function') t.__ccMarco(window);" \
    "  }" \
    "} catch (e) {}"

static char *leer(const char *ruta) {
    FILE *f = fopen(ruta, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *s = n > 0 ? malloc(n + 1) : NULL;
    if (s && fread(s, 1, n, f) == (size_t)n) s[n] = 0;
    else { free(s); s = NULL; }
    fclose(f);
    return s;
}

// Un número entero chico, como texto (para los argumentos de coucou-control)
static gboolean entero(const char *s) {
    if (!s || !*s || strlen(s) > 5) return FALSE;
    for (const char *c = s; *c; c++) if (*c < '0' || *c > '9') return FALSE;
    return TRUE;
}

// Un color #AARRGGBB
static gboolean color(const char *s) {
    if (!s || strlen(s) != 9 || s[0] != '#') return FALSE;
    for (const char *c = s + 1; *c; c++) if (!g_ascii_isxdigit(*c)) return FALSE;
    return TRUE;
}

static char *campo(JSCValue *v, const char *nombre) {
    if (!jsc_value_object_has_property(v, nombre)) return NULL;
    JSCValue *x = jsc_value_object_get_property(v, nombre);
    char *s = jsc_value_is_undefined(x) || jsc_value_is_null(x) ? NULL : jsc_value_to_string(x);
    g_object_unref(x);
    return s;
}

// "modo-juego estado" terminó: su JSON va a la página como texto (escapado) y ella lo lee
static void juego_estado(GObject *fuente, GAsyncResult *res, gpointer datos) {
    GWeakRef *ref = datos;
    WebKitWebView *vista = g_weak_ref_get(ref);
    g_weak_ref_clear(ref); g_free(ref);
    char *salida = NULL;
    if (g_subprocess_communicate_utf8_finish(G_SUBPROCESS(fuente), res, &salida, NULL, NULL) && vista && salida && salida[0] == '{') {
        GString *js = g_string_new("window.__coucouJuego && window.__coucouJuego(JSON.parse(\"");
        for (const char *c = salida; *c; c++) {
            if (*c == '\\' || *c == '"') { g_string_append_c(js, '\\'); g_string_append_c(js, *c); }
            else if ((unsigned char)*c >= 0x20) g_string_append_c(js, *c);
        }
        g_string_append(js, "\"))");
        webkit_web_view_evaluate_javascript(vista, js->str, -1, NULL, NULL, NULL, NULL, NULL);
        g_string_free(js, TRUE);
    }
    g_free(salida);
    if (vista) g_object_unref(vista);
    g_object_unref(fuente);
}

static void juego(WebKitWebView *vista, const char *accion) {
    // (sin la precarga de Coucou: es otro programa)
    GSubprocessLauncher *l = g_subprocess_launcher_new(strcmp(accion, "estado") == 0 ? G_SUBPROCESS_FLAGS_STDOUT_PIPE
                                                                                     : G_SUBPROCESS_FLAGS_NONE);
    g_subprocess_launcher_unsetenv(l, "LD_PRELOAD");
    GSubprocess *p = g_subprocess_launcher_spawn(l, NULL, "/usr/lib/coucou/modo-juego", accion, NULL);
    g_object_unref(l);
    if (!p) return;
    if (strcmp(accion, "estado") == 0 && vista) {
        GWeakRef *ref = g_new0(GWeakRef, 1);
        g_weak_ref_init(ref, vista);
        g_subprocess_communicate_utf8_async(p, NULL, NULL, juego_estado, ref);
    } else {
        g_object_unref(p);   // (GSubprocess lo espera solo cuando termina)
    }
}

// "Pantalla completa" del panel del mochi: la ventana de la barra (una superficie de gtk-layer-shell,
// pegada a su borde, del alto del panel) pasa a ocupar toda la pantalla (pegada a los cuatro bordes)
// y el panel crece adentro hasta ser Coucou Code; al volver, recupera sus bordes y su tamaño. Solo
// para la página de la barra.
static gboolean grande = FALSE, anclas[4];
static int ancho0, alto0;
static GtkWindow *barra = NULL;      // (la ventana de la barra, siempre alta: ver más abajo)
static gboolean barra_alta(void);
static void agrandar(WebKitWebView *vista, gboolean si) {
    if (barra && barra_alta()) return;   // (ya ocupa toda la pantalla: no hay nada que agrandar)
    const char *uri = vista ? webkit_web_view_get_uri(vista) : NULL;
    if (!uri || !g_str_has_prefix(uri, "tauri://localhost") || (strstr(uri, ".html") && !strstr(uri, "/index.html"))) return;
    GtkWidget *top = gtk_widget_get_toplevel(GTK_WIDGET(vista));
    void (*poner)(GtkWindow *, int, gboolean) = dlsym(RTLD_DEFAULT, "gtk_layer_set_anchor");
    gboolean (*leer)(GtkWindow *, int) = dlsym(RTLD_DEFAULT, "gtk_layer_get_anchor");
    if (!GTK_IS_WINDOW(top) || !poner || !leer) return;
    GtkWindow *w = GTK_WINDOW(top);
    if (si && !grande) {
        for (int i = 0; i < 4; i++) anclas[i] = leer(w, i);
        gtk_window_get_size(w, &ancho0, &alto0);
        for (int i = 0; i < 4; i++) poner(w, i, TRUE);
        grande = TRUE;
    } else if (!si && grande) {
        for (int i = 0; i < 4; i++) poner(w, i, anclas[i]);
        gtk_window_resize(w, ancho0, alto0);
        grande = FALSE;
    }
}

static void mensaje(WebKitUserContentManager *ucm, WebKitJavascriptResult *r, gpointer datos) {
    (void)ucm;
    JSCValue *v = webkit_javascript_result_get_js_value(r);
    if (!v || !jsc_value_is_object(v)) return;
    char *que = campo(v, "abrir");
    if (que && strcmp(que, "foco") == 0) {
        char *argv[] = { "/usr/lib/coucou/devolver-foco", NULL };
        char **env = g_environ_unsetenv(g_get_environ(), "LD_PRELOAD");
        g_spawn_async(NULL, argv, env, G_SPAWN_DEFAULT, NULL, NULL, NULL, NULL);
        g_strfreev(env);
    } else if (que && strcmp(que, "juego") == 0) {
        char *accion = campo(v, "accion");
        if (accion && (strcmp(accion, "alternar") == 0 || strcmp(accion, "estado") == 0))
            juego(WEBKIT_IS_WEB_VIEW(datos) ? WEBKIT_WEB_VIEW(datos) : NULL, accion);
        g_free(accion);
    } else if (que && strcmp(que, "grande") == 0) {
        char *si = campo(v, "si");
        agrandar(WEBKIT_IS_WEB_VIEW(datos) ? WEBKIT_WEB_VIEW(datos) : NULL, si && strcmp(si, "true") == 0);
        g_free(si);
    } else if (que && strcmp(que, "control") == 0) {
        static const char *numeros[] = { "margen", "derecha", "flecha" }, *colores[] = { "fondo1", "fondo2", "borde" };
        char *argv[10] = { "/usr/bin/coucou-control" };
        int n = 1;
        char *barra = campo(v, "barra");
        if (barra && (strcmp(barra, "abajo") == 0 || strcmp(barra, "arriba") == 0)) argv[n++] = g_strconcat("barra=", barra, NULL);
        g_free(barra);
        for (int i = 0; i < 3; i++) {
            char *x = campo(v, numeros[i]);
            if (entero(x)) argv[n++] = g_strconcat(numeros[i], "=", x, NULL);
            g_free(x);
        }
        for (int i = 0; i < 3; i++) {
            char *x = campo(v, colores[i]);
            if (color(x)) argv[n++] = g_strconcat(colores[i], "=", x, NULL);
            g_free(x);
        }
        argv[n] = NULL;
        // (sin la precarga de Coucou: el panel es otro programa)
        char **env = g_get_environ();
        env = g_environ_unsetenv(env, "LD_PRELOAD");
        g_spawn_async(NULL, argv, env, G_SPAWN_DEFAULT, NULL, NULL, NULL, NULL);
        g_strfreev(env);
        for (int i = 1; i < n; i++) g_free(argv[i]);
    }
    g_free(que);
}

// Una vez por vista: la hoja de estilo, el script, el canal para pedir el Centro de control (y el
// modo juego) y, si se pide, la consola
static void preparar(WebKitWebView *vista) {
    if (!vista || g_object_get_data(G_OBJECT(vista), "coucou-web")) return;
    g_object_set_data(G_OBJECT(vista), "coucou-web", GINT_TO_POINTER(1));
    WebKitUserContentManager *ucm = webkit_web_view_get_user_content_manager(vista);
    if (!ucm) return;
    const char *ruta = getenv("COUCOU_WEB_CSS");
    char *css = leer(ruta && *ruta ? ruta : ESTILO);
    if (css) {
        WebKitUserStyleSheet *h = webkit_user_style_sheet_new(css, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                                                              WEBKIT_USER_STYLE_LEVEL_USER, NULL, NULL);
        webkit_user_content_manager_add_style_sheet(ucm, h);
        webkit_user_style_sheet_unref(h);
        free(css);
    }
    ruta = getenv("COUCOU_WEB_JS");
    char *js = leer(ruta && *ruta ? ruta : SCRIPT);
    if (js) {
        WebKitUserScript *s = webkit_user_script_new(js, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                                                     WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END, NULL, NULL);
        webkit_user_content_manager_add_script(ucm, s);
        webkit_user_script_unref(s);
        free(js);
    }
    WebKitUserScript *m = webkit_user_script_new(MARCOS, WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES,
                                                 WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, NULL, NULL);
    webkit_user_content_manager_add_script(ucm, m);
    webkit_user_script_unref(m);
    if (webkit_user_content_manager_register_script_message_handler(ucm, "coucou"))
        g_signal_connect(ucm, "script-message-received::coucou", G_CALLBACK(mensaje), vista);
    const char *c = getenv("COUCOU_WEB_CONSOLA");
    if (c && *c == '1') {
        WebKitSettings *ajustes = webkit_web_view_get_settings(vista);
        if (ajustes) webkit_settings_set_enable_write_console_messages_to_stdout(ajustes, TRUE);
    }
}

static void *real(const char *nombre) {
    void *f = dlsym(RTLD_NEXT, nombre);
    if (!f) { fprintf(stderr, "coucou-web: no se encontró %s\n", nombre); abort(); }
    return f;
}

void webkit_web_view_load_uri(WebKitWebView *v, const gchar *uri) {
    static void (*f)(WebKitWebView *, const gchar *);
    if (!f) f = real("webkit_web_view_load_uri");
    preparar(v);
    f(v, uri);
}

void webkit_web_view_load_request(WebKitWebView *v, WebKitURIRequest *r) {
    static void (*f)(WebKitWebView *, WebKitURIRequest *);
    if (!f) f = real("webkit_web_view_load_request");
    preparar(v);
    f(v, r);
}

void webkit_web_view_load_html(WebKitWebView *v, const gchar *html, const gchar *base) {
    static void (*f)(WebKitWebView *, const gchar *, const gchar *);
    if (!f) f = real("webkit_web_view_load_html");
    preparar(v);
    f(v, html, base);
}

/*
    La barra, siempre del alto de la pantalla. La ventana de la barra (la superficie de gtk-layer-shell
    "coucou") Coucou la pega a su borde con el tamaño de lo que muestra (960x560). Para el panel del
    mochi en pantalla completa había que agrandarla y después achicarla, y en esos cambios KWin
    mostraba un cuadro o dos la imagen de antes en el lugar nuevo: el dock y el panel parpadeaban. Así
    que es siempre del ancho y del alto de su pantalla (menos 1 px del lado de afuera: así KWin sigue
    viendo que está pegada a su borde, ver el efecto coucou-barra) y nunca cambia de tamaño. Es
    transparente y solo recibe clics en el dock y en el panel (la barra se lo dice a Coucou: sus
    "formas"), así que lo de atrás se sigue usando. Se mira lo que Coucou le pide (a qué borde va, en
    qué pantalla) y se lo hace así. COUCOU_BARRA_CHICA=1 lo deja como era.
*/
static gboolean deseo[4];      // (los bordes que pide Coucou: de ellos solo cuenta arriba o abajo)
#define deseo_arriba (deseo[2] && !deseo[3])
static gboolean barra_alta(void) {
    const char *e = getenv("COUCOU_BARRA_CHICA");
    return !(e && *e == '1');
}
static int alto_pantalla(GtkWindow *w) {
    GdkMonitor *(*monitor)(GtkWindow *) = dlsym(RTLD_DEFAULT, "gtk_layer_get_monitor");
    GdkMonitor *m = monitor ? monitor(w) : NULL;
    GdkDisplay *d = gdk_display_get_default();
    if (!m && d) {
        GdkWindow *gw = gtk_widget_get_window(GTK_WIDGET(w));
        m = gw ? gdk_display_get_monitor_at_window(d, gw) : NULL;
        if (!m) m = gdk_display_get_primary_monitor(d);
        if (!m && gdk_display_get_n_monitors(d) > 0) m = gdk_display_get_monitor(d, 0);
    }
    if (!m) return 0;
    GdkRectangle r;
    gdk_monitor_get_geometry(m, &r);
    return r.height;
}
static void estirar(GtkWindow *w) {
    static void (*anclar)(GtkWindow *, int, gboolean);
    static void (*pedir)(GtkWidget *, gint, gint);
    static void (*medir)(GtkWindow *, gint, gint);
    if (!anclar) anclar = real("gtk_layer_set_anchor");
    if (!pedir) pedir = real("gtk_widget_set_size_request");
    if (!medir) medir = real("gtk_window_resize");
    const int h = alto_pantalla(w);
    if (h <= 0) return;
    anclar(w, 0, TRUE); anclar(w, 1, TRUE);                     // izquierda, derecha
    anclar(w, 2, deseo_arriba); anclar(w, 3, !deseo_arriba);    // arriba o abajo, el suyo
    pedir(GTK_WIDGET(w), 1, h - 1);
    medir(w, 1, h - 1);
}
void gtk_layer_set_namespace(GtkWindow *w, const char *nombre) {
    static void (*f)(GtkWindow *, const char *);
    if (!f) f = real("gtk_layer_set_namespace");
    f(w, nombre);
    if (nombre && strcmp(nombre, "coucou") == 0 && barra_alta()) {
        gboolean (*leer)(GtkWindow *, int) = dlsym(RTLD_DEFAULT, "gtk_layer_get_anchor");
        barra = w;
        if (leer) for (int i = 0; i < 4; i++) deseo[i] = leer(w, i);
        estirar(w);
    }
}
void gtk_layer_set_anchor(GtkWindow *w, int borde, gboolean si) {
    static void (*f)(GtkWindow *, int, gboolean);
    if (!f) f = real("gtk_layer_set_anchor");
    if (w && w == barra && barra_alta()) {
        if (borde >= 0 && borde < 4) deseo[borde] = si;
        estirar(w);
        return;
    }
    f(w, borde, si);
}
void gtk_layer_set_monitor(GtkWindow *w, GdkMonitor *m) {
    static void (*f)(GtkWindow *, GdkMonitor *);
    if (!f) f = real("gtk_layer_set_monitor");
    f(w, m);
    if (w && w == barra && barra_alta()) estirar(w);
}
void gtk_window_resize(GtkWindow *w, gint ancho, gint alto) {
    static void (*f)(GtkWindow *, gint, gint);
    if (!f) f = real("gtk_window_resize");
    if (w && w == barra && barra_alta()) { estirar(w); return; }
    f(w, ancho, alto);
}
void gtk_widget_set_size_request(GtkWidget *w, gint ancho, gint alto) {
    static void (*f)(GtkWidget *, gint, gint);
    if (!f) f = real("gtk_widget_set_size_request");
    if (w && (GtkWindow *)w == barra && barra_alta()) { estirar(barra); return; }
    f(w, ancho, alto);
}
