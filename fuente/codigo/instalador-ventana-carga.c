/*
 * Coucou: la parte chica de la ventana del instalador (bin/libcoucou-ventana.so, por LD_PRELOAD;
 * la pone instalar.sh). No usa Qt: LD_PRELOAD pasa a todo lo que abre la ventana (instalar.sh,
 * pacman, grep…) y la biblioteca de Qt en cada uno los hacía tardar muchísimo. Solo dentro de la
 * ventana (coucou-instalador) carga la de verdad, libcoucou-ventana-qt.so (instalador-ventana.cpp),
 * que está en la misma carpeta. LD_PRELOAD no se quita: la ventana se vuelve a abrir a sí misma al
 * arrancar y sin él perdía las pantallas.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

__attribute__((constructor)) static void coucou_ventana_carga(void) {
    char exe[PATH_MAX];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    if (n <= 0) return;
    exe[n] = 0;
    const char *base = strrchr(exe, '/');
    if (strcmp(base ? base + 1 : exe, "coucou-instalador") != 0) return;
    Dl_info info;
    if (!dladdr((void *)coucou_ventana_carga, &info) || !info.dli_fname) return;
    char lib[PATH_MAX];
    snprintf(lib, sizeof lib, "%s", info.dli_fname);
    char *barra = strrchr(lib, '/');
    if (!barra) return;
    snprintf(barra + 1, sizeof lib - (size_t)(barra + 1 - lib), "libcoucou-ventana-qt.so");
    if (!dlopen(lib, RTLD_NOW | RTLD_GLOBAL)) fprintf(stderr, "coucou-ventana: %s\n", dlerror());
}
