/*
 * Coucou: la barra entre pantallas.
 *
 * Con "todas las pantallas (la que estás usando)", la barra salta a la pantalla del ratón. Para
 * cambiar de pantalla, GTK destruye la superficie de la ventana (wl_surface) y crea otra, pero
 * Coucou sigue usando la vieja en org_kde_plasma_window.set_minimized_geometry (dónde se
 * minimiza cada ventana de la barra). El número de esa superficie ya es de otro objeto
 * (wl_buffer, wl_shm_pool…): KWin lo toma como un error de protocolo y corta la conexión, y la
 * barra se cierra en cada salto.
 *
 * Esta biblioteca (LD_PRELOAD, solo en Coucou: la carga coucou-launch) lleva la cuenta de las
 * superficies vivas y no deja pasar set_minimized_geometry / unset_minimized_geometry con una que
 * ya no existe. Coucou vuelve a mandarlas con la superficie nueva en cuanto cambia algo de la barra.
 *
 * La compila proyecto/construir.sh y queda en paquetes/coucou-claro/usr/lib/coucou/.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client-core.h>
#include <wayland-util.h>

#define WL_CLOSURE_MAX_ARGS 20   /* el de libwayland */

extern const struct wl_interface wl_surface_interface;

/* struct wl_proxy empieza con struct wl_object, y este con el puntero a su interfaz */
struct objeto { const struct wl_interface *interface; };

#define MAX_SUPERFICIES 512
static void *vivas[MAX_SUPERFICIES];
static int n_vivas;
static pthread_mutex_t candado = PTHREAD_MUTEX_INITIALIZER;
static int avisos;

static void anotar_viva(void *p) {
    pthread_mutex_lock(&candado);
    if (n_vivas < MAX_SUPERFICIES) vivas[n_vivas++] = p;
    pthread_mutex_unlock(&candado);
}
static void anotar_muerta(void *p) {
    pthread_mutex_lock(&candado);
    for (int i = 0; i < n_vivas; i++)
        if (vivas[i] == p) { vivas[i] = vivas[--n_vivas]; break; }
    pthread_mutex_unlock(&candado);
}
static int esta_viva(void *p) {
    int si = 0;
    pthread_mutex_lock(&candado);
    for (int i = 0; i < n_vivas; i++)
        if (vivas[i] == p) { si = 1; break; }
    pthread_mutex_unlock(&candado);
    return si;
}

/* Los hijos de Coucou (las apps que se abren desde la barra) no cargan esta biblioteca */
__attribute__((constructor)) static void quitarse_de_ld_preload(void) {
    const char *lp = getenv("LD_PRELOAD");
    if (!lp || !strstr(lp, "coucou-pantallas")) return;
    char *copia = strdup(lp), *resto = NULL, *nuevo = calloc(1, strlen(lp) + 1);
    if (!copia || !nuevo) { free(copia); free(nuevo); return; }
    for (char *t = strtok_r(copia, ": ", &resto); t; t = strtok_r(NULL, ": ", &resto)) {
        if (strstr(t, "coucou-pantallas")) continue;
        if (*nuevo) strcat(nuevo, ":");
        strcat(nuevo, t);
    }
    if (*nuevo) setenv("LD_PRELOAD", nuevo, 1); else unsetenv("LD_PRELOAD");
    free(copia); free(nuevo);
}

typedef struct wl_proxy *(*marshal_array_flags_t)(struct wl_proxy *, uint32_t, const struct wl_interface *,
                                                  uint32_t, uint32_t, union wl_argument *);
typedef void (*marshal_array_t)(struct wl_proxy *, uint32_t, union wl_argument *);
typedef void (*destroy_t)(struct wl_proxy *);

static void *real(const char *nombre) {
    void *f = dlsym(RTLD_NEXT, nombre);
    if (!f) { fprintf(stderr, "coucou-pantallas: falta %s\n", nombre); abort(); }
    return f;
}

/* Los argumentos variables de wl_proxy_marshal_flags, como los arma libwayland */
static int argumentos(const char *firma, va_list ap, union wl_argument *args) {
    int n = 0;
    for (const char *c = firma; *c && n < WL_CLOSURE_MAX_ARGS; c++) {
        switch (*c) {
        case 'i': args[n++].i = va_arg(ap, int32_t); break;
        case 'u': args[n++].u = va_arg(ap, uint32_t); break;
        case 'f': args[n++].f = va_arg(ap, wl_fixed_t); break;
        case 's': args[n++].s = va_arg(ap, const char *); break;
        case 'o': args[n++].o = va_arg(ap, struct wl_object *); break;
        case 'n': args[n++].o = va_arg(ap, struct wl_object *); break;
        case 'a': args[n++].a = va_arg(ap, struct wl_array *); break;
        case 'h': args[n++].h = va_arg(ap, int32_t); break;
        default: break;   /* '?' y el número de versión */
        }
    }
    return n;
}

static const struct wl_message *mensaje(struct wl_proxy *p, uint32_t opcode) {
    const struct wl_interface *i = p ? ((struct objeto *)p)->interface : NULL;
    if (!i || opcode >= (uint32_t)i->method_count) return NULL;
    return &i->methods[opcode];
}

static struct wl_proxy *enviar(struct wl_proxy *p, uint32_t opcode, const struct wl_interface *iface,
                               uint32_t version, uint32_t flags, union wl_argument *args) {
    static marshal_array_flags_t f;
    if (!f) f = (marshal_array_flags_t)real("wl_proxy_marshal_array_flags");
    if (flags & WL_MARSHAL_FLAG_DESTROY) anotar_muerta(p);
    struct wl_proxy *nuevo = f(p, opcode, iface, version, flags, args);
    if (nuevo && iface == &wl_surface_interface) anotar_viva(nuevo);
    return nuevo;
}

struct wl_proxy *wl_proxy_marshal_flags(struct wl_proxy *p, uint32_t opcode, const struct wl_interface *iface,
                                        uint32_t version, uint32_t flags, ...) {
    union wl_argument args[WL_CLOSURE_MAX_ARGS];
    const struct wl_message *m = mensaje(p, opcode);
    va_list ap;
    va_start(ap, flags);
    if (m) argumentos(m->signature, ap, args);
    va_end(ap);
    return enviar(p, opcode, iface, version, flags, args);
}

struct wl_proxy *wl_proxy_marshal_array_flags(struct wl_proxy *p, uint32_t opcode, const struct wl_interface *iface,
                                              uint32_t version, uint32_t flags, union wl_argument *args) {
    return enviar(p, opcode, iface, version, flags, args);
}

void wl_proxy_destroy(struct wl_proxy *p) {
    static destroy_t f;
    if (!f) f = (destroy_t)real("wl_proxy_destroy");
    anotar_muerta(p);
    f(p);
}

/* Por aquí manda Coucou set_minimized_geometry */
void wl_proxy_marshal_array(struct wl_proxy *p, uint32_t opcode, union wl_argument *args) {
    static marshal_array_t f;
    if (!f) f = (marshal_array_t)real("wl_proxy_marshal_array");
    const struct wl_message *m = mensaje(p, opcode);
    if (m && args && (strcmp(m->name, "set_minimized_geometry") == 0 || strcmp(m->name, "unset_minimized_geometry") == 0) &&
        strcmp(((struct objeto *)p)->interface->name, "org_kde_plasma_window") == 0 &&
        args[0].o && !esta_viva(args[0].o)) {
        if (avisos < 3) {
            avisos++;
            fprintf(stderr, "coucou-pantallas: %s con una superficie que ya no existe (la barra cambió de pantalla): no se manda\n", m->name);
        }
        return;
    }
    f(p, opcode, args);
}
