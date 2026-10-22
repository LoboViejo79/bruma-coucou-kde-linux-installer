/*
 * Coucou: las páginas de Configuración (win11-settings) desde fuente/configuracion.
 *
 * El programa de Configuración viene compilado con sus páginas QML adentro, y su código C++ no
 * está en este proyecto. Para poder cambiar las páginas, construir.sh arma con ellas
 * /usr/share/coucou/configuracion.rcc y esta biblioteca (LD_PRELOAD, la pone /usr/local/bin/
 * win11-settings) lo registra ANTES que los recursos del programa: Qt usa el primero que
 * encuentra, así que valen las páginas del proyecto. Lo que no esté ahí sale del programa.
 *
 * Si falta el .rcc, no hace nada: Configuración usa sus páginas de siempre.
 */
#include <QResource>
#include <QString>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unistd.h>

static const char *RCC = "/usr/share/coucou/configuracion.rcc";

__attribute__((constructor)) static void coucou_configuracion() {
    // Los programas que abre Configuración no cargan esta biblioteca
    if (const char *lp = getenv("LD_PRELOAD")) {
        std::string resto, s(lp);
        size_t i = 0;
        while (i <= s.size()) {
            size_t j = s.find_first_of(": ", i);
            if (j == std::string::npos) j = s.size();
            std::string t = s.substr(i, j - i);
            if (!t.empty() && t.find("coucou-configuracion") == std::string::npos)
                resto += (resto.empty() ? "" : ":") + t;
            i = j + 1;
        }
        if (resto.empty()) unsetenv("LD_PRELOAD"); else setenv("LD_PRELOAD", resto.c_str(), 1);
    }
    const char *p = getenv("COUCOU_PAGINAS");
    if (!p) p = RCC;
    if (access(p, R_OK) == 0)
        QResource::registerResource(QString::fromLocal8Bit(p));
}
