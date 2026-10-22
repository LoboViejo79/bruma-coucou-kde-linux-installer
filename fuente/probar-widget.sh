#!/usr/bin/env bash
# Coucou: ver un widget del proyecto sin instalar nada, en una ventana (plasmawindowed).
#
#   fuente/probar-widget.sh <id>          por ejemplo: fuente/probar-widget.sh musica
#
# Usa los archivos de fuente/coucou-claro (el widget y org.coucou.widgets) mientras la ventana
# está abierta; al cerrarla no queda nada. Se corre con tu usuario, desde el escritorio.
set -euo pipefail
F=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
id=${1:?uso: fuente/probar-widget.sh <id>   (los widgets: $(ls "$F/coucou-claro/usr/share/plasma/plasmoids" | sed 's/^org.coucou.//' | tr '\n' ' '))}
src="$F/coucou-claro/usr/share/plasma/plasmoids/org.coucou.$id"
[ -d "$src" ] || { echo "no existe el widget: $id" >&2; exit 1; }
dest=${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/org.coucou.$id
[ -e "$dest" ] && [ ! -L "$dest" ] && { echo "ya hay un org.coucou.$id propio en $dest: no se toca" >&2; exit 1; }
qml=$(mktemp -d)
mkdir -p "$qml/org/coucou" "$(dirname "$dest")"
ln -sfn "$F/coucou-claro/usr/lib/qt6/qml/org/coucou/widgets" "$qml/org/coucou/widgets"
ln -sfn "$src" "$dest"
trap 'rm -f "$dest"; rm -rf "$qml"' EXIT
QML_IMPORT_PATH="$qml" plasmawindowed "org.coucou.$id"
