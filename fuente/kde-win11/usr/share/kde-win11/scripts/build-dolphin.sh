#!/usr/bin/env bash
# Compila Dolphin con el parche de Windows 11 (dolphin/dolphin-win11.patch):
#  - caja de búsqueda real en la barra superior (busca por nombre en la carpeta actual al escribir)
#  - barra de comandos sobre la lista de archivos, con el panel lateral subiendo hasta arriba
# Usa la misma versión que el Dolphin del sistema y solo instala el ejecutable en
# ~/.local/opt/dolphin-win11 (las bibliotecas y plugins siguen siendo los del sistema).
# Después de actualizar Dolphin con pacman, vuelve a ejecutar este script; mientras tanto
# ~/.local/bin/dolphin usa el Dolphin normal.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC=~/.cache/dotfiles-src
DEST=~/.local/opt/dolphin-win11

VER=$(pacman -Q dolphin | awk '{print $2}' | cut -d- -f1)
echo "==> Dolphin $VER con el parche de Windows 11"
mkdir -p "$SRC/dolphin-dl"
TAR="$SRC/dolphin-dl/dolphin-$VER.tar.xz"
URL="https://download.kde.org/stable/release-service/$VER/src/dolphin-$VER.tar.xz"
if [ ! -f "$TAR" ]; then
  curl -sSfL "$URL" -o "$TAR.part"
  curl -sSfL "$URL.sha256" -o "$TAR.sha256"
  (cd "$SRC/dolphin-dl" && sed "s|dolphin-$VER.tar.xz|$(basename "$TAR.part")|" "$TAR.sha256" | sha256sum -c --quiet)
  mv "$TAR.part" "$TAR"
fi

B="$SRC/dolphin-$VER-win11"
rm -rf "$B"; mkdir -p "$B"
tar -xJf "$TAR" -C "$B" --strip-components=1
patch -d "$B" -p1 --quiet < "$HERE/dolphin/dolphin-win11.patch"

# Sin RPATH: el ejecutable debe cargar /usr/lib/libdolphinprivate.so.6 (la misma que usan los plugins)
cmake -S "$B" -B "$B/build" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_SKIP_BUILD_RPATH=ON >/dev/null
cmake --build "$B/build" --target dolphin -j"$(nproc)"

# Solo el ejecutable: enlaza con /usr/lib/libdolphinprivate.so del mismo paquete
mkdir -p "$DEST/bin"
install -m755 "$B/build/bin/dolphin" "$DEST/bin/dolphin.new" 2>/dev/null \
  || install -m755 "$(find "$B/build" -type f -name dolphin -perm -u+x | head -1)" "$DEST/bin/dolphin.new"
mv "$DEST/bin/dolphin.new" "$DEST/bin/dolphin"
echo "$VER" > "$DEST/version"
echo "   instalado en $DEST/bin/dolphin (se usa al abrir el Explorador)"
