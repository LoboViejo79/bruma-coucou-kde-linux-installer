#!/usr/bin/env bash
# Bruma Coucou: arma el instalador desde su código, en esta misma carpeta.
#
#   fuente/construir.sh           actualiza paquetes/ con lo que haya cambiado en fuente/:
#                                 - un paquete que cambió sube su número (1.0.37-47 → -48)
#                                 - el instalador sube de versión (VERSION: 1.0.63 → 1.0.64) si
#                                   cambió cualquier cosa, así los equipos que ya tienen Coucou
#                                   lo ven como actualización
#   fuente/construir.sh --revisar solo dice qué cambió, sin tocar nada
#   fuente/construir.sh --zip     además arma ../bruma-coucou-vX.Y.Z.zip para repartir
#                                 (sin fuente/, que no hace falta para instalar)
#
# No hace falta ser administrador. Ver fuente/LEEME.md.
set -euo pipefail
F=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)    # fuente/
R=$(dirname "$F")                                    # la carpeta del instalador
EST=$F/.construido                                   # huellas de lo último armado (no se edita)
mkdir -p "$EST"
REVISAR=0; ZIP=0
for a in "$@"; do case $a in --revisar) REVISAR=1 ;; --zip) ZIP=1 ;; *) echo "opción desconocida: $a" >&2; exit 2 ;; esac; done

aviso() { printf '%s\n' "$*"; }
falla() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for c in bsdtar zstd pacman sha256sum; do command -v $c >/dev/null || falla "falta el programa $c"; done

# Huella de una carpeta: contenido, permisos y enlaces de cada archivo (no las fechas)
huella() { # $1=carpeta, resto: condiciones de find para dejar cosas fuera
  local d=$1; shift
  ( cd "$d" && LC_ALL=C find . "$@" \( -type f -o -type l \) ! -name .directory -print0 | LC_ALL=C sort -z |
    while IFS= read -r -d '' f; do
      if [ -L "$f" ]; then printf '%s -> %s\n' "$f" "$(readlink "$f")"
      else printf '%s %s %s\n' "$f" "$(stat -c %a "$f")" "$(sha256sum < "$f" | cut -c1-64)"; fi
    done ) | sha256sum | cut -c1-64
}

# 1. La biblioteca de la barra entre pantallas, desde su código
SO=$F/coucou-claro/usr/lib/coucou/libcoucou-pantallas.so
hf=$(sha256sum < "$F/codigo/coucou-pantallas.c" | cut -c1-64)
if [ ! -f "$SO" ] || [ "$(cat "$EST/coucou-pantallas.huella" 2>/dev/null)" != "$hf" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: codigo/coucou-pantallas.c"
  elif command -v gcc >/dev/null && pkg-config --exists wayland-client 2>/dev/null; then
    gcc -O2 -Wall -shared -fPIC -o "$SO" "$F/codigo/coucou-pantallas.c" -ldl -lpthread $(pkg-config --cflags --libs wayland-client)
    chmod 755 "$SO"; echo "$hf" > "$EST/coucou-pantallas.huella"
  else
    falla "cambió codigo/coucou-pantallas.c y no hay gcc o las cabeceras de wayland para compilarlo"
  fi
fi
# 1a. La que suma las transiciones de la barra (usr/share/coucou/web) a su página
SO=$F/coucou-claro/usr/lib/coucou/libcoucou-web.so
hf=$(sha256sum < "$F/codigo/coucou-web.c" | cut -c1-64)
if [ ! -f "$SO" ] || [ "$(cat "$EST/coucou-web.huella" 2>/dev/null)" != "$hf" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: codigo/coucou-web.c"
  elif command -v gcc >/dev/null && pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
    gcc -O2 -Wall -shared -fPIC -o "$SO" "$F/codigo/coucou-web.c" -ldl $(pkg-config --cflags --libs webkit2gtk-4.1)
    chmod 755 "$SO"; echo "$hf" > "$EST/coucou-web.huella"
  else
    falla "cambió codigo/coucou-web.c y no hay gcc o las cabeceras de webkit2gtk-4.1 para compilarlo"
  fi
fi

# 1b. Configuración (win11-settings): sus páginas desde fuente/configuracion (un .rcc) y la
#     biblioteca que las pone antes que las del programa (codigo/configuracion-paginas.cpp)
CL=$F/coucou-claro
hc=$( { huella "$F/configuracion"; sha256sum < "$F/codigo/configuracion-paginas.cpp"; } | sha256sum | cut -c1-64)
if [ ! -f "$CL/usr/share/coucou/configuracion.rcc" ] || [ ! -f "$CL/usr/lib/coucou/libcoucou-configuracion.so" ] ||
   [ "$(cat "$EST/configuracion.huella" 2>/dev/null)" != "$hc" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: configuracion/ (páginas de Configuración)"
  else
    command -v g++ >/dev/null && pkg-config --exists Qt6Core 2>/dev/null && [ -x /usr/lib/qt6/rcc ] ||
      falla "para armar Configuración hacen falta g++, las cabeceras de Qt6 y /usr/lib/qt6/rcc"
    qrc="$F/configuracion/.paginas.qrc"
    { echo '<!DOCTYPE RCC><RCC version="1.0"><qresource prefix="/qt/qml/Win11Settings">'
      ( cd "$F/configuracion" && find . -type f ! -name '.*' | sed 's#^\./##' | LC_ALL=C sort | sed 's#.*#<file>&</file>#' )
      echo '</qresource></RCC>'; } > "$qrc"
    # Formato 1: sin fechas adentro (el mismo QML da siempre el mismo archivo)
    /usr/lib/qt6/rcc --binary --format-version 1 "$qrc" -o "$CL/usr/share/coucou/configuracion.rcc"
    rm -f "$qrc"; chmod 644 "$CL/usr/share/coucou/configuracion.rcc"
    g++ -O2 -Wall -shared -fPIC -o "$CL/usr/lib/coucou/libcoucou-configuracion.so" "$F/codigo/configuracion-paginas.cpp" \
        $(pkg-config --cflags --libs Qt6Core)
    chmod 755 "$CL/usr/lib/coucou/libcoucou-configuracion.so"
    echo "$hc" > "$EST/configuracion.huella"
  fi
fi

# 1c. La Tienda de aplicaciones (win11-store), desde su código (kde-win11/…/store-app) → el programa
#     que instala coucou-claro (/usr/local/bin/win11-store)
ST=$F/kde-win11/usr/share/kde-win11/store-app
hs=$(huella "$ST" ! -path './build/*')
if [ ! -f "$CL/usr/local/bin/win11-store" ] || [ "$(cat "$EST/tienda.huella" 2>/dev/null)" != "$hs" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: la Tienda (store-app)"
  else
    command -v cmake >/dev/null && command -v g++ >/dev/null && pkg-config --exists flatpak Qt6Quick 2>/dev/null ||
      falla "para armar la Tienda hacen falta cmake, g++ y las cabeceras de Qt6 y flatpak"
    cmake -S "$ST" -B "$EST/tienda" -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$EST/tienda" -j"$(nproc)" >/dev/null || falla "no se pudo compilar la Tienda (cmake --build $EST/tienda)"
    install -m755 "$EST/tienda/win11-store" "$CL/usr/local/bin/win11-store"
    echo "$hs" > "$EST/tienda.huella"
  fi
fi

# 1d. Bienvenido (win11-welcome), desde su código (kde-win11/…/welcome-app) → el programa que
#     instala kde-win11 (/usr/bin/win11-welcome)
WA=$F/kde-win11/usr/share/kde-win11/welcome-app
hw=$(huella "$WA" ! -path './build/*')
if [ "$(cat "$EST/bienvenido.huella" 2>/dev/null)" != "$hw" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: Bienvenido (welcome-app)"
  else
    command -v cmake >/dev/null && command -v g++ >/dev/null && pkg-config --exists Qt6Quick 2>/dev/null ||
      falla "para armar Bienvenido hacen falta cmake, g++ y las cabeceras de Qt6"
    cmake -S "$WA" -B "$EST/bienvenido" -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$EST/bienvenido" -j"$(nproc)" >/dev/null || falla "no se pudo compilar Bienvenido (cmake --build $EST/bienvenido)"
    install -m755 "$EST/bienvenido/win11-welcome" "$F/kde-win11/usr/bin/win11-welcome"
    echo "$hw" > "$EST/bienvenido.huella"
  fi
fi

# 1e. La ventana del instalador (bin/coucou-instalador): sus pantallas desde fuente/ventana (un .rcc)
#     y la biblioteca que las pone antes que las del programa y suma las copias de seguridad
#     (codigo/instalador-ventana.cpp, que carga codigo/instalador-ventana-carga.c solo en la ventana)
#     → bin/ventana.rcc, bin/libcoucou-ventana.so y bin/libcoucou-ventana-qt.so
hv=$( { huella "$F/ventana"; sha256sum < "$F/codigo/instalador-ventana.cpp"; sha256sum < "$F/codigo/instalador-ventana-carga.c"; } | sha256sum | cut -c1-64)
if [ ! -f "$R/bin/ventana.rcc" ] || [ ! -f "$R/bin/libcoucou-ventana.so" ] || [ ! -f "$R/bin/libcoucou-ventana-qt.so" ] || [ "$(cat "$EST/ventana.huella" 2>/dev/null)" != "$hv" ]; then
  if [ $REVISAR = 1 ]; then aviso "cambió: ventana/ (pantallas del instalador)"
  else
    command -v g++ >/dev/null && pkg-config --exists Qt6Qml Qt6Gui 2>/dev/null && [ -x /usr/lib/qt6/rcc ] && [ -x /usr/lib/qt6/moc ] ||
      falla "para armar la ventana del instalador hacen falta g++, las cabeceras de Qt6 y /usr/lib/qt6/rcc y moc"
    qrc="$F/ventana/.pantallas.qrc"
    { echo '<!DOCTYPE RCC><RCC version="1.0"><qresource prefix="/qt/qml/CoucouInstalador">'
      ( cd "$F/ventana" && find . -type f ! -name '.*' | sed 's#^\./##' | LC_ALL=C sort | sed 's#.*#<file>&</file>#' )
      echo '</qresource></RCC>'; } > "$qrc"
    /usr/lib/qt6/rcc --binary --format-version 1 "$qrc" -o "$R/bin/ventana.rcc"
    rm -f "$qrc"; chmod 644 "$R/bin/ventana.rcc"
    mkdir -p "$EST/ventana"
    /usr/lib/qt6/moc "$F/codigo/instalador-ventana.cpp" -o "$EST/ventana/instalador-ventana.moc"
    g++ -O2 -Wall -shared -fPIC -I"$EST/ventana" -o "$R/bin/libcoucou-ventana-qt.so" "$F/codigo/instalador-ventana.cpp" \
        $(pkg-config --cflags --libs Qt6Qml Qt6Gui)
    gcc -O2 -Wall -shared -fPIC -o "$R/bin/libcoucou-ventana.so" "$F/codigo/instalador-ventana-carga.c" -ldl
    chmod 755 "$R/bin/libcoucou-ventana.so" "$R/bin/libcoucou-ventana-qt.so"
    echo "$hv" > "$EST/ventana.huella"
  fi
fi

# 2. Los paquetes con su árbol de archivos (fuente/<nombre>/ con .PKGINFO) → paquetes/
version_de() { sed -n 's/^pkgver = //p' "$1/.PKGINFO"; }
arch_de() { sed -n 's/^arch = //p' "$1/.PKGINFO" | head -1; }
subir_pkgrel() { # 1.0.37-47 → 1.0.37-48 en .PKGINFO y .BUILDINFO
  local v base rel nueva
  v=$(version_de "$1"); base=${v%-*}; rel=${v##*-}; nueva="$base-$((rel + 1))"
  sed -i "s/^pkgver = $v\$/pkgver = $nueva/" "$1/.PKGINFO"
  [ -f "$1/.BUILDINFO" ] && sed -i "s/^pkgver = $v\$/pkgver = $nueva/" "$1/.BUILDINFO"
  echo "$nueva"
}
armar_paquete() { # $1=carpeta $2=archivo de salida
  local d=$1 out=$2 size lista
  size=$(( $(du -sk --apparent-size --exclude=.PKGINFO --exclude=.BUILDINFO --exclude=.MTREE --exclude=.INSTALL "$d" | cut -f1) * 1024 ))
  sed -i -e "s/^builddate = .*/builddate = $(date +%s)/" -e "s/^size = .*/size = $size/" "$d/.PKGINFO"
  lista=$(mktemp)
  ( cd "$d" && LC_ALL=C find . -mindepth 1 ! -name .MTREE -printf '%P\0' | LC_ALL=C sort -z ) > "$lista"
  # Todo como de root (el árbol es de tu usuario, para poder editarlo sin sudo)
  ( cd "$d" && LANG=C bsdtar --uid 0 --gid 0 --uname root --gname root -cnf - --format=mtree \
      --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' --null --files-from "$lista" |
    gzip -c -f -n > .MTREE )
  ( cd "$d" && { printf '.MTREE\0'; cat "$lista"; } |
    LANG=C bsdtar --uid 0 --gid 0 --uname root --gname root --no-fflags -cnf - --null --files-from - |
    zstd -c -T0 -19 -q -f - -o "$out" )
  rm -f "$lista" "$d/.MTREE"
  pacman -Qp "$out" >/dev/null || falla "el paquete armado no se puede leer: $out"
}

CAMBIO=0
for d in "$F"/*/; do
  d=${d%/}; n=$(basename "$d")
  [ -f "$d/.PKGINFO" ] || continue
  h=$(huella "$d" ! -name .PKGINFO ! -name .BUILDINFO ! -name .MTREE)
  v=$(version_de "$d"); a=$(arch_de "$d")
  previa=$(cat "$EST/$n.huella" 2>/dev/null || true)
  if [ "$previa" != "$h" ] || [ ! -f "$R/paquetes/$n-$v-$a.pkg.tar.zst" ]; then
    CAMBIO=1
    if [ $REVISAR = 1 ]; then aviso "cambió: paquete $n"; continue; fi
    # La primera vez se arma con el número que tiene; después, cada cambio lo sube
    [ -n "$previa" ] && [ "$previa" != "$h" ] && v=$(subir_pkgrel "$d")
    aviso "armando $n $v"
    tmp="$R/paquetes/.$n-armando.pkg.tar.zst"
    armar_paquete "$d" "$tmp"
    rm -f "$R/paquetes/$n"-[0-9]*.pkg.tar.zst
    mv "$tmp" "$R/paquetes/$n-$v-$a.pkg.tar.zst"
    echo "$h" > "$EST/$n.huella"
  fi
done

# 3. El instalador: si cambió algo (sus archivos o algún paquete), sube de versión
for f in "$R"/*.sh; do bash -n "$f" || falla "error de sintaxis en $(basename "$f")"; done
hi=$( { huella "$R" \( -path ./fuente -o -path ./paquetes -o -name VERSION -o -name LEEME.txt -o -name coucou-instalador.log -o -name coucou-desinstalador.log -o -name '*.zip' -o -name README.md -o -path ./capturas -o -name '.git*' \) -prune -o;
        ls "$R"/paquetes/*.pkg.tar.zst | xargs -n1 basename; } | sha256sum | cut -c1-64)
VERSION=$(tr -d '[:space:]' < "$R/VERSION")
previa=$(cat "$EST/instalador.huella" 2>/dev/null || true)
if [ "$previa" != "$hi" ]; then
  CAMBIO=1
  if [ $REVISAR = 1 ]; then aviso "cambió: el instalador"
  else
    # La primera vez solo se anota; después, cada cambio sube el último número
    if [ -n "$previa" ]; then
      VERSION=$(awk -F. -v OFS=. '{ $NF = $NF + 1; print }' <<<"$VERSION")
      echo "$VERSION" > "$R/VERSION"
      sed -i -E "1s/versión [0-9.]+ \([0-9-]+\)/versión $VERSION ($(date +%F))/" "$R/LEEME.txt"
    fi
    echo "$hi" > "$EST/instalador.huella"
  fi
fi
if [ $REVISAR = 1 ]; then [ $CAMBIO = 1 ] || aviso "nada cambió desde el último armado"; exit 0; fi
[ $CAMBIO = 1 ] && aviso "instalador versión $VERSION" || aviso "nada cambió: versión $VERSION"
bash "$R/estado.sh" "$R" | grep -E '^(cambio|nuevos)=' || true

# 4. Para repartir: un zip sin fuente/ (no hace falta para instalar)
if [ $ZIP = 1 ]; then
  Z=$(dirname "$R")/bruma-coucou-v$VERSION.zip
  rm -f "$Z"
  ( cd "$(dirname "$R")" && bsdtar -a -cf "$Z" --exclude "$(basename "$R")/fuente" \
      --exclude "$(basename "$R")/coucou-instalador.log" --exclude "$(basename "$R")/coucou-desinstalador.log" --exclude "$(basename "$R")/paquetes/.*" \
      --exclude "$(basename "$R")/capturas" --exclude "$(basename "$R")/.git" --exclude "$(basename "$R")/.gitignore" "$(basename "$R")" )
  aviso "zip: $Z ($(du -h "$Z" | cut -f1))"
fi
