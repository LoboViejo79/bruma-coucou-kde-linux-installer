#!/usr/bin/env bash
# ¿Coucou ya está instalado en este equipo? ¿Qué trae de nuevo este instalador?
# No cambia nada ni pide contraseña. Escribe líneas CLAVE=valor:
#   instalado=1|0            coucou-claro está instalado
#   version_instalada=X      la del instalador con que se instaló (o "?" si fue uno viejo)
#   version_instalador=X     la de esta carpeta
#   diseno=… modo=… …        lo que se eligió la vez pasada (si se sabe)
#   nuevos=N                 paquetes de esta carpeta más nuevos que los instalados (o que faltan)
#   cambio=nombre vieja→nueva   uno por cada paquete nuevo
# Uso: estado.sh [carpeta del instalador]
set -uo pipefail
DIR=${1:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}
MARCA=/var/lib/coucou-instalador/instalado

if pacman -Q coucou-claro >/dev/null 2>&1; then echo "instalado=1"; else echo "instalado=0"; fi
echo "version_instalador=$(tr -d '[:space:]' < "$DIR/VERSION" 2>/dev/null || echo '?')"
if [ -r "$MARCA" ]; then
  # Solo las claves conocidas (el archivo es de root, pero igual no se ejecuta nada de él)
  grep -E '^(version|diseno|modo|login|arranque|acento|apps|rendimiento|voz|usuario|fecha)=' "$MARCA" |
    sed 's/^version=/version_instalada=/'
else
  echo "version_instalada=?"
fi

n=0
for p in "$DIR"/paquetes/*.pkg.tar.zst; do
  [ -f "$p" ] || continue
  read -r nombre nueva < <(pacman -Qp "$p" 2>/dev/null) || continue
  vieja=$(pacman -Q "$nombre" 2>/dev/null | awk '{print $2}')
  # Solo lo que es más nuevo: nunca se baja a una versión anterior a la que ya está
  if [ -z "$vieja" ] || [ "$(vercmp "$nueva" "$vieja")" -gt 0 ]; then
    n=$((n + 1))
    echo "cambio=$nombre ${vieja:-(nuevo)}→$nueva"
    echo "paquete=$p"
  fi
done
# El instalador mismo más nuevo que el que instaló (arreglos en los scripts, sin paquetes nuevos):
# también es una actualización
vi=$(tr -d '[:space:]' < "$DIR/VERSION" 2>/dev/null)
va=$(sed -n 's/^version=//p' "$MARCA" 2>/dev/null | head -1)
if [ -n "$vi" ] && { [ -z "$va" ] || [ "$(vercmp "$vi" "$va")" -gt 0 ]; }; then
  n=$((n + 1))
  echo "cambio=instalador ${va:-?}→$vi"
fi
echo "nuevos=$n"
