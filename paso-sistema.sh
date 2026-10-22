#!/usr/bin/env bash
# Instalar Bruma Coucou, parte de administrador (la lanza instalar.sh con pkexec):
#   paso-sistema.sh <carpeta> coucou <claro|oscuro> <login 0|1> <arranque 0|1>
#                   [acento #RRGGBB] [apps,…] [rendimiento,…] [voz 0|1]
#                   [limpio 0|1]   1: reinstalar limpio (aparta lo que quedó de instalaciones viejas)
#   paso-sistema.sh <carpeta> actualizar     ya instalado: solo los paquetes más nuevos (nada del diseño,
#                                            el inicio de sesión, el arranque ni las apps se vuelve a hacer)
# 1. paquetes coucou-claro y kde-win11 (kde-win11 es la base del diseño: iconos, cursores, fuentes,
#    Configuración, Tienda; con sus dependencias de los repos: todo lo del menú de la barra)
# 2. las aplicaciones elegidas y los servicios (Bluetooth y perfiles de energía siempre, por la barra)
# 3. el diseño en la cuenta (paso-cuenta.sh, como el usuario y dentro de su sesión)
# 4. inicio de sesión (SDDM con el tema de Coucou)
# 5. animación de arranque (Plymouth con Mochi, sin letras encima)
set -uo pipefail
DIR=$1; DISENO=$2; MODO=${3:-claro}; LOGIN=${4:-0}; ARRANQUE=${5:-0}; ACENTO=${6:-}; APPS=${7:-}; REND=${8:-}; VOZ=${9:-1}; LIMPIO=${10:-0}
# Solo existe el diseño de Coucou (los de Windows 11 y CachyOS se quitaron)
case "$DISENO" in coucou|actualizar) ;; *) echo "paso-sistema: diseño desconocido: $DISENO (solo coucou)" >&2; exit 2 ;; esac
elegido() { [[ ",$2," == *",$1,"* ]]; }   # elegido ID LISTA
sin_progreso() { grep -v '^PROGRESO' || true; }   # (sin líneas no es un error)
U=${COUCOU_USUARIO:?}
# La contraseña se aceptó: instalar.sh lo ve en esta línea y no la vuelve a pedir
echo "@@ AUTORIZADO"
UHOME=$(getent passwd "$U" | cut -d: -f6)
LOG=/var/log/coucou-instalador.log
exec > >(tee -a "$LOG") 2>&1
echo "== $(date) usuario=$U diseño=$DISENO modo=$MODO acento=${ACENTO:--} login=$LOGIN arranque=$ARRANQUE apps=${APPS:--} rendimiento=${REND:--} voz=$VOZ"
paso() { echo "@@ $1 $2"; }
RESPALDO=/var/lib/coucou-instalador/respaldo-$(date +%Y%m%d-%H%M%S)
respaldar() { local f; for f in "$@"; do [ -e "$f" ] && { mkdir -p "$RESPALDO$(dirname "$f")"; cp -a "$f" "$RESPALDO$f"; }; done; return 0; }

# 1. Paquetes
# pacman ocupado (el actualizador de CachyOS, otra instalación): se espera a que termine. Un candado
# sin ningún pacman andando no se borra solo (podría ser de algo que no se ve): se avisa cómo seguir.
esperar_pacman() {
  local i
  for i in $(seq 120); do
    [ -e /var/lib/pacman/db.lck ] || return 0
    [ $((i % 6)) = 1 ] && paso 10 "Esperando a que termine otra instalación o actualización…"
    sleep 5
  done
  echo "!! pacman sigue ocupado (/var/lib/pacman/db.lck) después de 10 minutos."
  pgrep -x 'pacman|paru|yay|pamac|packagekitd|octopi' >/dev/null ||
    echo "!! No hay ningún pacman andando: si estás seguro, borra ese archivo con sudo y vuelve a instalar."
  return 1
}
# Sin --needed: con la misma versión ya instalada se vuelven a poner (así llegan los arreglos).
# Los archivos de Coucou que ya estén sueltos en el sistema (puestos a mano para arreglar algo, sin
# ser de ningún paquete) se reemplazan: pacman si no, no instala nada ("archivos en conflicto").
PROPIOS_SUELTOS=(--overwrite '/etc/skel/*' --overwrite '/usr/lib/coucou/*' --overwrite '/usr/bin/coucou*'
                 --overwrite '/usr/share/applications/coucou.desktop' --overwrite '/usr/share/applications/fr.louisraille.coucou.desktop'
                 --overwrite '/usr/share/kde-win11/*' --overwrite '/usr/share/icons/Win11*' --overwrite '/usr/local/bin/win11-*')
instalar_propios() {
  esperar_pacman || return 1
  local out; out=$(mktemp)
  pacman -U --noconfirm "${PROPIOS_SUELTOS[@]}" "${pkgs[@]}" 2>&1 | tee "$out"
  local rc=${PIPESTATUS[0]}
  FALTAN_DEPENDENCIAS=0
  grep -qiE 'no se pudo satisfacer|could not satisfy|unable to satisfy|no se encontró el objetivo|target not found|failed to retrieve|no se pudo obtener' "$out" && FALTAN_DEPENDENCIAS=1
  rm -f "$out"; return $rc
}
# Lo que queda anotado de esta instalación (estado.sh lo lee: la próxima vez se actualiza en vez de
# instalar todo de nuevo). Al actualizar se conserva lo elegido la primera vez.
MARCA=/var/lib/coucou-instalador/instalado
anotar() {
  mkdir -p "$(dirname "$MARCA")"
  local version; version=$(tr -d '[:space:]' < "$DIR/VERSION" 2>/dev/null)
  if [ "$DISENO" = actualizar ] && [ -f "$MARCA" ]; then
    sed -i -e "s/^version=.*/version=$version/" -e "s/^fecha=.*/fecha=$(date '+%Y-%m-%d %H:%M')/" "$MARCA"
    grep -q '^version=' "$MARCA" || echo "version=$version" >> "$MARCA"
  elif [ "$DISENO" = actualizar ]; then
    # Instalado con un instalador viejo (sin anotar lo elegido): solo la versión, el resto no se sabe
    printf 'version=%s\nfecha=%s\nusuario=%s\n' "$version" "$(date '+%Y-%m-%d %H:%M')" "$U" > "$MARCA"
  else
    printf 'version=%s\nfecha=%s\nusuario=%s\ndiseno=%s\nmodo=%s\nlogin=%s\narranque=%s\nacento=%s\napps=%s\nrendimiento=%s\nvoz=%s\n' \
      "$version" "$(date '+%Y-%m-%d %H:%M')" "$U" "$DISENO" "$MODO" "$LOGIN" "$ARRANQUE" "$ACENTO" "$APPS" "$REND" "$VOZ" > "$MARCA"
  fi
  # El historial (copia.sh ver / desinstalar.sh --ver) y las copias: quedan las 10 más nuevas
  local tipo=instalación
  [ "$DISENO" = actualizar ] && tipo=actualización
  [ "$LIMPIO" = 1 ] && tipo=reinstalación
  bash "$DIR/copia.sh" anotar "$tipo" "$version" "$U"
  bash "$DIR/copia.sh" podar /var/lib/coucou-instalador
  bash "$DIR/copia.sh" podar "$UHOME/.local/share/coucou-instalador"
}

# Antes de cambiar nada: la copia de cómo estaba la PC antes de Coucou (solo la primera vez: nunca
# se pisa ni se borra; la usa desinstalar.sh) y, al actualizar, la copia de la cuenta de cada vez
# (al instalar la hace paso-cuenta.sh)
bash "$DIR/copia.sh" original "$U"
if [ "$DISENO" = actualizar ]; then
  runuser -u "$U" -- bash "$DIR/copia.sh" cuenta "$UHOME" "$UHOME/.local/share/coucou-instalador/respaldo-$(date +%Y%m%d-%H%M%S)"
fi

# El fondo que trae el instalador: en el sistema (para que quede aunque se borre esta carpeta) y
# armado como fondo de Plasma (contents/images/ANCHOxALTO.ext + metadata.json): el tema de Coucou
# lo nombra como fondo por defecto, así una pantalla que se conecta tiene el de Coucou, no el de
# Windows 11. También al actualizar (en instalaciones viejas no estaba armado).
fondo_sistema() {
  local d=/usr/share/wallpapers/coucou f wh
  for f in "$DIR"/perfil/fondo.*; do
    [ -f "$f" ] && install -Dm644 "$f" "$d/$(basename "$f")"
  done
  f=$(ls "$d"/fondo.png "$d"/fondo.jpg "$d"/fondo.jpeg 2>/dev/null | head -1)
  [ -n "$f" ] || return 0
  wh=$(python3 - "$f" <<'PYW'
import struct, sys
b = open(sys.argv[1], "rb").read()
if b[:8] == b"\x89PNG\r\n\x1a\n":
    w, h = struct.unpack(">II", b[16:24]); print(f"{w}x{h}")
elif b[:2] == b"\xff\xd8":
    i = 2
    while i < len(b):
        if b[i] != 0xFF: i += 1; continue
        m = b[i + 1]
        if m in (0xC0, 0xC1, 0xC2):
            h, w = struct.unpack(">HH", b[i + 5:i + 9]); print(f"{w}x{h}"); break
        i += 2 + struct.unpack(">H", b[i + 2:i + 4])[0]
PYW
)
  [ -n "$wh" ] || return 0
  rm -rf "$d/contents"
  mkdir -p "$d/contents/images"
  ln -s "../../$(basename "$f")" "$d/contents/images/$wh.${f##*.}"
  printf '{\n  "KPlugin": { "Id": "coucou", "Name": "Coucou", "Authors": [{ "Name": "Coucou" }], "License": "MIT" },\n  "KPackageStructure": "Wallpaper/Images"\n}\n' > "$d/metadata.json"
}
fondo_sistema

# Sesión X11 para AnyDesk. Plasma 6.8 ya no tiene X11 y AnyDesk no comparte la pantalla en
# Wayland ("Display server not supported"): con AnyDesk (elegido o ya instalado) se suma al inicio
# de sesión "Xfce (X11)", un Xfce sencillo (/usr/lib/coucou/sesion-x11). La pantalla
# de inicio muestra solo esa y Plasma (Wayland): las sesiones salen de /usr/share/coucou/xsessions y
# /usr/share/coucou/wayland-sessions (un enlace a la de Plasma).
sesion_x11() {
  X11CONF=/etc/sddm.conf.d/coucou-x11.conf
  if elegido anydesk "$APPS" || elegido anydesk "$(bash "$DIR/apps-instaladas.sh" "$U" 2>/dev/null)"; then
    # La misma que usa la Tienda (Coucou nuevo); la de abajo, para un Coucou que todavía no la trae
    if [ -x /usr/lib/coucou/tienda-nativo-root ]; then
      paso 42 "Revisando la sesión X11 para AnyDesk"
      /usr/lib/coucou/tienda-nativo-root sesion-x11 2>&1 | sin_progreso
      return 0
    fi
    if ! command -v startxfce4 >/dev/null || ! command -v xrandr >/dev/null; then
      paso 42 "Agregando la sesión X11 para AnyDesk"
      esperar_pacman
      pacman -S --needed --noconfirm xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-settings xfconf xorg-xrandr xorg-xinput xorg-xset xorg-setxkbmap </dev/null \
        || echo "!! no se pudo instalar Xfce (la sesión X11 para AnyDesk)"
    fi
    if command -v startxfce4 >/dev/null && [ -f /usr/share/coucou/xsessions/coucou-x11.desktop ]; then
      mkdir -p /etc/sddm.conf.d
      # (Xfce trae también sus sesiones, X11 y Wayland: no se muestran; solo Plasma y la de Coucou)
      printf '%s\n' "# Coucou: la sesión X11 para AnyDesk (y no las de Xfce tal cual; ver /usr/lib/coucou/sesion-x11)" \
        "[X11]" "SessionDir=/usr/share/coucou/xsessions" \
        "[Wayland]" "SessionDir=/usr/share/coucou/wayland-sessions" > "$X11CONF"
      echo "Sesión X11 para AnyDesk: se elige al iniciar sesión (\"Xfce (X11)\")"
    fi
  fi
}

paso 10 "Instalando Coucou, sus aplicaciones y los temas"
pkgs=("$DIR"/paquetes/*.pkg.tar.zst)
if [ "$DISENO" = actualizar ]; then
  # Solo los paquetes más nuevos que los instalados: los iguales no se tocan y nunca se baja de versión
  mapfile -t pkgs < <(bash "$DIR/estado.sh" "$DIR" | sed -n 's/^paquete=//p')
  if [ ${#pkgs[@]} = 0 ]; then
    # Solo el instalador es más nuevo (arreglos en sus pasos): se anota la versión y listo
    sesion_x11
    anotar
    paso 98 "Paquetes al día: se aplican los arreglos del instalador"
    exit 0
  fi
  paso 10 "Actualizando Coucou (${#pkgs[@]} paquete$([ ${#pkgs[@]} = 1 ] || echo s))"
fi
if ! instalar_propios; then
  # Solo si faltan dependencias (lista de paquetes vieja) vale la pena actualizar el sistema; otro
  # error (un archivo en conflicto…) no se arregla actualizando: se dice y se termina
  if [ "${FALTAN_DEPENDENCIAS:-0}" != 1 ]; then
    echo "!! no se pudieron instalar los paquetes de Coucou (el motivo está arriba)"; exit 1
  fi
  # En un CachyOS recién instalado la lista de paquetes puede estar vieja (pacman no encuentra las
  # dependencias): se actualiza TODO el sistema (en Arch no se actualizan partes sueltas). Solo si
  # fallan las firmas se ponen al día las llaves, y enseguida otra vez todo. El llavero no se rehace
  # solo: si hiciera falta, se dice cómo.
  paso 15 "Actualizando el sistema primero (puede tardar varios minutos)"
  esperar_pacman || exit 1
  act=$(mktemp)
  if ! pacman -Syu --noconfirm 2>&1 | tee "$act"; then
    if grep -qiE 'signature|firma|keyring|llavero|PGP' "$act"; then
      echo "(firmas viejas: se actualizan las llaves y el sistema)"
      { pacman -S --needed --noconfirm archlinux-keyring cachyos-keyring && pacman -Su --noconfirm; } || {
        echo "!! No se pudo actualizar el sistema por las firmas. Prueba: sudo pacman-key --init && sudo pacman-key --populate archlinux cachyos"
        rm -f "$act"; exit 1; }
    else
      echo "!! no se pudo actualizar el sistema"; rm -f "$act"; exit 1
    fi
  fi
  rm -f "$act"
  paso 35 "Instalando Coucou, sus aplicaciones y los temas"
  instalar_propios || { echo "!! no se pudieron instalar los paquetes de Coucou"; exit 1; }
fi

# Actualizar: listo. Los ganchos de los paquetes ya rehicieron lo que hacía falta (la pantalla de
# bloqueo, el inicio de sesión); el diseño, el fondo, las apps y el arranque quedan como estaban.
if [ "$DISENO" = actualizar ]; then
  sesion_x11
  anotar
  paso 98 "Terminando"
  exit 0
fi

# Reinstalar limpio: los archivos de Coucou que no son de ningún paquete instalado (quedaron de
# versiones viejas, o puestos a mano para arreglar algo) se apartan a la copia de respaldo. Los de
# los paquetes ya quedaron recién puestos. Nada se borra: todo va a $RESPALDO/huerfanos.
limpiar_sistema() {
  local propios cand n=0 f
  propios=$(mktemp); cand=$(mktemp)
  pacman -Qlq 2>/dev/null | sed 's#/$##' | sort -u > "$propios"
  {
    for d in /usr/lib/coucou /usr/share/coucou /usr/share/kde-win11 /usr/share/sddm/themes/coucou-login /usr/share/plymouth/themes/coucou; do
      [ -d "$d" ] && find "$d" \( -type f -o -type l \)
    done
    for f in /usr/local/bin/win11-* /usr/bin/win11-* /usr/bin/coucou* /etc/xdg/autostart/*coucou* /etc/xdg/autostart/*win11* \
             /usr/lib/systemd/user/coucou* /usr/lib/systemd/system/coucou* /usr/share/applications/*coucou* /usr/share/applications/win11-* \
             /usr/share/libalpm/hooks/coucou-*; do
      [ -e "$f" ] || [ -L "$f" ] && echo "$f"
    done
  } | grep -vxF -e /usr/share/sddm/themes/coucou-login/theme.conf.user | sort -u > "$cand"   # (el fondo del login: se genera, no es viejo)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    mkdir -p "$RESPALDO/huerfanos$(dirname "$f")"
    mv -f "$f" "$RESPALDO/huerfanos$f" && n=$((n + 1)) && echo "  apartado: $f"
  done < <(comm -23 "$cand" "$propios")
  rm -f "$propios" "$cand"
  # Carpetas que quedaron vacías
  for d in /usr/lib/coucou /usr/share/coucou /usr/share/kde-win11; do [ -d "$d" ] && find "$d" -mindepth 1 -type d -empty -delete; done
  systemctl daemon-reload 2>/dev/null
  echo "Archivos viejos apartados del sistema: $n$([ $n -gt 0 ] && echo " (en $RESPALDO/huerfanos)")"
}
if [ "$LIMPIO" = 1 ]; then
  paso 37 "Quitando lo que quedó de instalaciones viejas"
  limpiar_sistema
fi

# 2. Aplicaciones y servicios
# Lo que usa el menú de la barra de Coucou: Bluetooth y perfiles de energía andando siempre
systemctl enable --now bluetooth.service power-profiles-daemon.service 2>&1 | grep -v '^Created symlink' || true
ayudante() { /usr/bin/win11-welcome-helper "$@"; }   # las mismas tareas que Bienvenido
# Una app de la página "Aplicaciones", de donde mejor anda (lo dice /usr/share/coucou/tienda/apps.conf,
# lo mismo que recomienda la Tienda): nativa (CachyOS/Arch o AUR) o Flathub. Después se deja lista
# (servicios, sesión X11…) con lo mismo que usa la Tienda. Si la nativa falla, va la de Flathub.
NATIVO=/usr/lib/coucou/tienda-nativo; NATIVO_ROOT=/usr/lib/coucou/tienda-nativo-root
como_usuario() { runuser -u "$U" -- env HOME="$UHOME" USER="$U" LOGNAME="$U" PATH=/usr/local/bin:/usr/bin "$@"; }
instalar_app() { # $1 = id de Flathub
  local fid=$1 pref="" pkg="" k v resto archivos=() ok=0
  if [ -x "$NATIVO" ] && [ -x "$NATIVO_ROOT" ]; then
    local repo="" aur=""
    while read -r k v resto; do
      case $k in preferido) pref=$v ;; repo) repo=$v ;; aur) aur=$v ;; esac
    done < <(cd / && como_usuario "$NATIVO" buscar "$fid" 2>/dev/null)
    case $pref in repo) pkg=$repo ;; aur) pkg=$aur ;; esac
  fi
  if [ -n "$pkg" ] && [ "$pref" = repo ]; then
    esperar_pacman && "$NATIVO_ROOT" instalar "$pkg" "$fid" | sin_progreso && ok=1
  elif [ -n "$pkg" ] && [ "$pref" = aur ]; then
    echo "$fid: del AUR ($pkg)"
    local falta
    if falta=$(cd / && como_usuario "$NATIVO" deps-aur "$pkg") && ! grep -q '^ERROR' <<<"$falta"; then
      # shellcheck disable=SC2086
      { [ -z "$falta" ] || { esperar_pacman && "$NATIVO_ROOT" deps $falta | sin_progreso; }; } &&
      mapfile -t archivos < <(cd / && como_usuario "$NATIVO" construir-aur "$pkg" | sed -n 's/^ARCHIVO //p') &&
      [ ${#archivos[@]} -gt 0 ] && esperar_pacman && "$NATIVO_ROOT" instalar-archivos "$fid" "${archivos[@]}" | sin_progreso && ok=1
    else
      echo "$falta"
    fi
  fi
  if [ $ok = 1 ]; then
    # Que la Tienda la muestre como suya (en su Biblioteca, "instalada desde…")
    como_usuario bash -c 'mkdir -p ~/.local/share/coucou-tienda && f=~/.local/share/coucou-tienda/nativos.tsv &&
      { grep -vi "^$1 " "$f" 2>/dev/null; echo "$1 $2"; } > "$f.tmp" && mv -f "$f.tmp" "$f"' _ "$fid" "$pkg"
    return 0
  fi
  [ -n "$pkg" ] && echo "!! no se pudo instalar $pkg nativo: va la de Flathub"
  flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo </dev/null >/dev/null 2>&1
  # La salida a un archivo: flatpak deja procesos auxiliares (bwrap) que heredan la salida y
  # mantendrían abierto el registro, y la instalación parecería trabada
  local fl; fl=$(mktemp)
  flatpak install --system -y --noninteractive flathub "$fid" </dev/null >"$fl" 2>&1 || echo "!! Flatpak $fid"
  cat "$fl"; rm -f "$fl"
  [ -x "$NATIVO_ROOT" ] && "$NATIVO_ROOT" arreglar "$fid" | sin_progreso
  return 0
}
# Las que ya están (del sistema o de Flatpak, de la cuenta o del equipo) no se instalan otra vez:
# si no, quedaban dos iguales en el menú
YA=$(bash "$DIR/apps-instaladas.sh" "$U" 2>/dev/null)
nueva() { if elegido "$1" "$YA"; then echo "ya estaba instalada: $1"; return 1; fi; elegido "$1" "$APPS"; }
if [ -n "$APPS$REND" ]; then
  paso 38 "Instalando las aplicaciones y servicios que elegiste"
  elegido juegos "$APPS" && nueva juegos && { esperar_pacman; ayudante gaming || echo "!! juegos"; }
  elegido windows "$APPS" && nueva windows && { esperar_pacman; ayudante "winboat:$U" || echo "!! WinBoat"; }
  if grep -qE "^($(echo "$APPS" | tr ',' '|')) " "$DIR/flatpaks.txt" 2>/dev/null; then
    while read -r id app; do
      case "$id" in ''|'#'*) continue ;; esac
      elegido "$id" "$APPS" || continue
      nueva "$id" || continue
      paso 40 "Instalando $app"
      instalar_app "$app"
    done < "$DIR/flatpaks.txt"
  fi
  elegido ananicy "$REND" && { ayudante enable:ananicy-cpp.service || echo "!! ananicy-cpp"; }
  elegido oomd "$REND" && { ayudante enable:systemd-oomd.service || echo "!! systemd-oomd"; }
  elegido psd "$REND" && { ayudante psd && systemctl --global enable psd.service || echo "!! profile-sync-daemon"; }
fi

sesion_x11

# 3. El diseño en la cuenta
paso 45 "Aplicando el diseño a tu cuenta"
sesion=(HOME="$UHOME" USER="$U" LOGNAME="$U" LANG="${LANG:-es_ES.UTF-8}" XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-KDE}"
        PATH=/usr/local/sbin:/usr/local/bin:/usr/bin)
for v in DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY XAUTHORITY XDG_SESSION_TYPE; do
  [ -n "${!v:-}" ] && sesion+=("$v=${!v}")
done
runuser -u "$U" -- env -i "${sesion[@]}" \
  bash "$DIR/paso-cuenta.sh" "$DIR" "$DISENO" "$MODO" "$ACENTO" "$APPS" "$VOZ" "$LIMPIO" || { echo "!! falló algo al aplicar el diseño (ver arriba)"; CUENTA_FALLO=1; }

# 4. Inicio de sesión
if [ "$LOGIN" = 1 ]; then
  paso 70 "Preparando la pantalla de inicio de sesión"
  respaldar /etc/sddm.conf.d
  # El de Windows 11, si quedó de una instalación vieja, se quita
  rm -f /etc/sddm.conf.d/10-win11.conf
  esperar_pacman; pacman -S --needed --noconfirm sddm qt6-5compat qt6-svg qt6-declarative >/dev/null
  # El mismo fondo que el escritorio: el de Coucou (el que puso paso-cuenta.sh). Antes se tomaba la
  # primera "Image=" de appletsrc, que puede ser de un escritorio viejo (el de CachyOS) y no el de
  # la pantalla principal. Si el diseño no trae fondo, el del escritorio de la pantalla principal.
  fondo=$(cat "$DIR/perfil/fondo" 2>/dev/null); fondo=${fondo#file://}
  if [ ! -f "$fondo" ]; then
    fondo=$(awk '/^\[Containments\]\[[0-9]+\]$/ { c = $0; next }
                 /^lastScreen=0$/ { p[c] = 1 }
                 /^\[Containments\]\[[0-9]+\]\[Wallpaper\]\[org.kde.image\]\[General\]$/ { w = $0; next }
                 /^\[/ { w = "" }
                 w != "" && /^Image=/ { sub(/^Image=/, ""); img[w] = $0 }
                 END { for (k in img) { c = k; sub(/\[Wallpaper\].*/, "", c); if (p[c]) print img[k] } }' \
              "$UHOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | tail -1)
  fi
  /usr/lib/coucou/login-theme coucou-login "$fondo" || echo "!! tema de inicio de sesión de Coucou"
  # SDDM en lugar de Plasma Login Manager (que no admite temas)
  if systemctl cat sddm.service >/dev/null 2>&1; then
    systemctl disable plasmalogin.service 2>/dev/null
    systemctl enable -f sddm.service || echo "!! no se pudo activar SDDM"
  fi
fi

# 5. Animación de arranque
if [ "$ARRANQUE" = 1 ]; then
  paso 80 "Preparando la animación de arranque (tarda un minuto)"
  esperar_pacman; pacman -S --needed --noconfirm plymouth >/dev/null || echo "!! plymouth"
  respaldar /etc/mkinitcpio.conf /etc/plymouth/plymouthd.conf /etc/default/limine /etc/default/grub /etc/sdboot-manage.conf \
            /boot/limine.conf /boot/efi/limine.conf /efi/limine.conf /boot/refind_linux.conf
  # el driver de vídeo dentro de la imagen de arranque (si no, Plymouth espera en negro a que cargue)
  gpu=$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display')
  mods=()
  grep -qiE '\b(amd|ati|radeon)\b' <<<"$gpu" && mods+=(amdgpu)
  grep -qi intel <<<"$gpu" && mods+=(i915)
  grep -qi virtio <<<"$gpu" && mods+=(virtio_gpu)
  grep -qi vmware <<<"$gpu" && mods+=(vmwgfx)
  python3 - /etc/mkinitcpio.conf "${mods[@]}" <<'PY'
import re, sys
p, mods = sys.argv[1], sys.argv[2:]
text = open(p).read()
def lista(clave):
    m = re.search(rf'(?m)^{clave}=\((.*)\)', text)
    return m, (m.group(1).split() if m else [])
m, actuales = lista("MODULES")
nuevos = actuales + [x for x in mods if x not in actuales]
if m: text = text[:m.start()] + f"MODULES=({' '.join(nuevos)})" + text[m.end():]
m, hooks = lista("HOOKS")
if m and "plymouth" not in hooks:
    i = hooks.index("kms") + 1 if "kms" in hooks else len(hooks)
    for h in ("sd-encrypt", "encrypt", "lvm2", "filesystems"):
        if h in hooks: i = min(i, hooks.index(h))
    hooks.insert(i, "plymouth")
    text = text[:m.start()] + f"HOOKS=({' '.join(hooks)})" + text[m.end():]
open(p, "w").write(text)
PY
  mkdir -p /etc/plymouth
  printf '[Daemon]\nTheme=coucou\nShowDelay=0\nDeviceTimeout=12\n' > /etc/plymouth/plymouthd.conf
  # "splash" y sin mensajes encima de la animación, en el gestor de arranque que haya
  # (no se cambia el tiempo del menú: en un equipo ya instalado puede haber otros sistemas)
  python3 - <<'PY'
import re
from pathlib import Path
EXTRA = "splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto vt.global_cursor_default=0".split()
def agregar(params):
    lista = params.split(); claves = {p.split("=")[0] for p in lista}
    return " ".join(lista + [p for p in EXTRA if p.split("=")[0] not in claves])
def editar(path, patron, cambio=lambda m: m.group(1) + agregar(m.group(2)) + m.group(3)):
    p = Path(path)
    if not p.is_file(): return None
    p.write_text(re.sub(patron, cambio, p.read_text(), flags=re.M)); print("editado", path); return p
lim = editar("/etc/default/limine", r'^(KERNEL_CMDLINE\[default\]\+?=")(.*)(")$')
if lim:
    m = re.search(r'^ESP_PATH="(.*)"', lim.read_text(), re.M)
    editar(str(Path(m.group(1) if m else "/boot") / "limine.conf"), r'^(\s*cmdline:\s*)(.*)()$')
editar("/etc/default/grub", r'^(GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(")$')
for base in ("/boot", "/efi"):
    for e in sorted(Path(base, "loader/entries").glob("*.conf")):
        editar(str(e), r'^(options\s+)(.*)()$')
editar("/etc/sdboot-manage.conf", r'^(LINUX_OPTIONS=")(.*)(")$')
editar("/boot/refind_linux.conf", r'^("[^"]*"\s+")(.*)(")$')
PY
  [ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null && { grub-mkconfig -o /boot/grub/grub.cfg >/dev/null || echo "!! grub-mkconfig"; }
  paso 88 "Rehaciendo la imagen de arranque"
  if command -v limine-mkinitcpio >/dev/null; then rehacer=limine-mkinitcpio; else rehacer="mkinitcpio -P"; fi
  plymouth-set-default-theme coucou || echo "!! tema de Plymouth"
  if ! $rehacer; then
    if [ "$rehacer" != "mkinitcpio -P" ]; then
      echo "(limine-mkinitcpio no pudo; se rehace con mkinitcpio)"
      mkinitcpio -P || echo "!! no se pudo rehacer la imagen de arranque"
    else
      echo "!! no se pudo rehacer la imagen de arranque"
    fi
  fi
fi

# Teléfono › Pantalla › iPhone (AirPlay): avahi anuncia la PC y, con ufw prendido, se abren
# solo los puertos de UxPlay (perfil "Coucou AirPlay"; la entrada lleva un PIN)
systemctl enable --now avahi-daemon.service >/dev/null 2>&1 || echo "!! avahi"
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow "Coucou AirPlay" >/dev/null 2>&1 || echo "!! ufw: AirPlay"
fi

[ -d "$RESPALDO" ] && echo "Copia de los archivos del sistema que se cambiaron: $RESPALDO"
anotar
paso 98 "Terminando"
# El diseño en la cuenta falló: se termina lo demás, pero se avisa (no se da por bueno)
[ "${CUENTA_FALLO:-0}" = 1 ] && exit 4
exit 0
