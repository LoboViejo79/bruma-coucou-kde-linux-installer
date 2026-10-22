#!/usr/bin/env bash
# Desinstalar Bruma Coucou: deja la PC como estaba antes de instalar Coucou, con la copia que se hizo la
# primera vez (/var/lib/coucou-instalador/original, ver copia.sh).
#
#   ./desinstalar.sh              muestra el historial, pregunta y desinstala (contraseña una vez)
#   ./desinstalar.sh --simular    dice qué haría, sin cambiar nada
#   ./desinstalar.sh --ver        primera instalación, historial y copias (no cambia nada)
#   ./desinstalar.sh --con-apps   también quita las apps que se instalaron con Coucou (Steam, Discord…)
#   sudo ./desinstalar.sh [...] [--usuario NOMBRE]
#   (--ventana: lo usa la ventana del instalador; sin preguntar ni terminal, con líneas "@@ N texto"
#    para su barra de progreso)
#
# Qué hace: quita los paquetes de Coucou (y lo que se instaló solo para ellos), vuelve a poner el
# inicio de sesión y la animación de arranque de antes, saca del arranque lo que agregó Coucou y deja
# los ajustes de tu cuenta (temas, barra, atajos…) como estaban. Las apps que elegiste se quedan
# (salvo --con-apps). Tus archivos y los chats de Coucou (~/.local/share/coucou) no se tocan.
# Antes de cambiar nada guarda una copia de cómo está ahora: /var/lib/coucou-instalador/desinstalado-<fecha>
set -uo pipefail
DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
[ -n "${COUCOU_VENTANA_CACHE:-}" ] && unset QML_DISABLE_DISK_CACHE COUCOU_VENTANA_CACHE
unset COUCOU_VENTANA
if [ -n "${LD_PRELOAD:-}" ]; then
  LD_PRELOAD=$(tr ': ' '\n\n' <<<"$LD_PRELOAD" | grep -v 'libcoucou-ventana' | paste -sd: -)
  [ -n "$LD_PRELOAD" ] && export LD_PRELOAD || unset LD_PRELOAD
fi
SIS=/var/lib/coucou-instalador
ORIG=$SIS/original

SIMULAR=0; APPS=0; VER=0; U=""; CONFIRMADO=0; VENTANA=0
while [ $# -gt 0 ]; do
  case "$1" in
    --simular) SIMULAR=1 ;;
    --con-apps) APPS=1 ;;
    --ver) VER=1 ;;
    --usuario) U=${2:-}; shift ;;
    --confirmado) CONFIRMADO=1 ;;   # (interno: ya se preguntó antes de pedir la contraseña)
    --ventana) VENTANA=1; CONFIRMADO=1 ;;   # (la ventana del instalador ya preguntó)
    -h|--help) sed -n '5,9p' "$0" | sed 's/^#  //'; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

# Con doble clic (sin terminal): se abre en una terminal para ver qué pasa
if [ $VENTANA = 0 ] && [ ! -t 0 ] && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v konsole >/dev/null; then
  extra=(); [ $SIMULAR = 1 ] && extra+=(--simular); [ $APPS = 1 ] && extra+=(--con-apps); [ $VER = 1 ] && extra+=(--ver)
  exec konsole --hold -e bash "$DIR/desinstalar.sh" "${extra[@]}"
fi

if [ "$(id -u)" = 0 ]; then
  [ -n "$U" ] || U=${COUCOU_USUARIO:-${SUDO_USER:-}}
  [ -n "$U" ] || { [ -n "${PKEXEC_UID:-}" ] && U=$(id -nu "$PKEXEC_UID" 2>/dev/null); }
  [ -n "$U" ] && [ "$U" != root ] && id "$U" >/dev/null 2>&1 ||
    { echo "Como superusuario hay que decir para qué cuenta es: sudo ./desinstalar.sh --usuario NOMBRE" >&2; exit 2; }
else
  [ -z "$U" ] || [ "$U" = "$USER" ] || { echo "--usuario solo sirve como superusuario (sudo)" >&2; exit 2; }
  U=$USER
fi
UHOME=$(getent passwd "$U" | cut -d: -f6)

if [ $VER = 1 ]; then bash "$DIR/copia.sh" ver "$U"; exit 0; fi

# Preguntar (con tu usuario, antes de pedir la contraseña)
if [ $SIMULAR = 0 ] && [ $CONFIRMADO = 0 ]; then
  bash "$DIR/copia.sh" ver "$U"; echo
  if ! pacman -Q coucou-claro >/dev/null 2>&1 && [ ! -f "$SIS/instalado" ]; then
    echo "Coucou no está instalado en este equipo: no hay nada que desinstalar."; exit 0
  fi
  [ -f "$ORIG/info" ] || [ "$(id -u)" = 0 ] ||
    echo "(Todavía no hay copia de cómo estaba antes: se arma ahora con las copias de la primera instalación.)"
  echo "Esto quita Coucou y deja la PC como estaba antes de instalarlo."
  [ $APPS = 1 ] && echo "También se quitan las apps que se instalaron con Coucou." ||
    echo "Las apps que elegiste (Steam, Discord…) se quedan (para quitarlas también: --con-apps)."
  read -r -p "¿Desinstalar Bruma Coucou? Escribe si y Enter: " r
  [ "${r,,}" = si ] || [ "${r,,}" = sí ] || { echo "No se cambió nada."; exit 0; }
fi

# Lo de administrador: con tu usuario se pide la contraseña una sola vez
if [ $SIMULAR = 0 ] && [ "$(id -u)" != 0 ]; then
  extra=(--confirmado); [ $APPS = 1 ] && extra+=(--con-apps); [ $VENTANA = 1 ] && extra+=(--ventana)
  exec pkexec env COUCOU_USUARIO="$U" LANG="${LANG:-}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" DISPLAY="${DISPLAY:-}" \
    XAUTHORITY="${XAUTHORITY:-}" bash "$DIR/desinstalar.sh" "${extra[@]}"
fi

# ---------------------------------------------------------------------------------------------
if [ $SIMULAR = 0 ] && ! pacman -Q coucou-claro >/dev/null 2>&1 && [ ! -f "$SIS/instalado" ]; then
  echo "@@ Coucou no está instalado en este equipo: no hay nada que desinstalar."; exit 3
fi
FECHA=$(date +%Y%m%d-%H%M%S)
BK=$SIS/desinstalado-$FECHA
if [ $SIMULAR = 0 ]; then
  LOG=/var/log/coucou-desinstalador.log
  touch "$DIR/coucou-desinstalador.log" 2>/dev/null && chown "$U": "$DIR/coucou-desinstalador.log"
  exec > >(tee -a "$LOG" "$DIR/coucou-desinstalador.log" 2>/dev/null) 2>&1
  echo "===== Desinstalar Coucou: $(date '+%Y-%m-%d %H:%M:%S') · usuario: $U$([ $APPS = 1 ] && echo ' · con las apps')"
else
  echo "SIMULACIÓN: no se cambia nada. Esto es lo que haría:"
fi
hacer() { if [ $SIMULAR = 1 ]; then echo "  · $*"; else "$@"; fi; }
apartar() { # mueve algo a la copia de antes de desinstalar (nada se borra)
  local f=$1
  [ -e "$f" ] || [ -L "$f" ] || return 0
  if [ $SIMULAR = 1 ]; then echo "  · quitar $f"; return 0; fi
  mkdir -p "$BK/quitado$(dirname "$f")" && mv -f "$f" "$BK/quitado$f"
}
como_usuario() {
  local e=(HOME="$UHOME" USER="$U" LOGNAME="$U" PATH=/usr/local/bin:/usr/bin) v
  for v in DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY XAUTHORITY; do [ -n "${!v:-}" ] && e+=("$v=${!v}"); done
  runuser -u "$U" -- env "${e[@]}" "$@"
}
# paso PORCENTAJE TEXTO: en la ventana, su barra de progreso; en la terminal, un título
paso() { if [ $VENTANA = 1 ]; then echo "@@ $1 $2"; else echo; echo "== $2"; fi; }

# La copia de cómo estaba antes (si es de un instalador viejo, se arma ahora)
if [ ! -f "$ORIG/info" ]; then
  if [ $SIMULAR = 1 ]; then echo "  · armar la copia de cómo estaba antes con las copias de la primera instalación"
  else bash "$DIR/copia.sh" original "$U"; fi
fi
ANTES="$ORIG/cuenta/$U"
en_original() { grep -qx "$1" "$ORIG/paquetes.txt" 2>/dev/null; }
HAY_LISTA=0; [ -s "$ORIG/paquetes.txt" ] && HAY_LISTA=1

# 1. Copia de cómo está ahora (por si hay que volver a Coucou)
paso 5 "Guardando una copia de cómo está ahora"
if [ $SIMULAR = 0 ]; then
  mkdir -p "$BK/sistema"
  bash "$DIR/copia.sh" cuenta "$UHOME" "$BK/cuenta" >/dev/null
  for f in /etc/sddm.conf /etc/sddm.conf.d /etc/mkinitcpio.conf /etc/plymouth/plymouthd.conf /etc/default/limine /etc/default/grub \
           /etc/sdboot-manage.conf /boot/limine.conf /boot/refind_linux.conf /boot/loader/entries "$SIS/instalado"; do
    [ -e "$f" ] && { mkdir -p "$BK/sistema$(dirname "$f")"; cp -a "$f" "$BK/sistema$f"; }
  done
  pacman -Q > "$BK/paquetes.txt"
  echo "Copia: $BK"
else echo "  · copia de la cuenta y del sistema en $BK"; fi

# 2. La cuenta: los ajustes como estaban
paso 15 "Dejando tu cuenta como estaba"
if [ $SIMULAR = 0 ]; then
  pkill -u "$U" -f '^(/usr)?/bin/bash /usr/bin/coucou-launch' 2>/dev/null
  pkill -u "$U" -x coucou 2>/dev/null
  # Plasma guarda la barra al cerrarse: se cierra antes de poner la de antes (y se abre al final)
  PLASMA=0
  if pgrep -u "$U" -x plasmashell >/dev/null; then
    PLASMA=1; como_usuario kquitapp6 plasmashell >/dev/null 2>&1
    for _ in $(seq 10); do pgrep -u "$U" -x plasmashell >/dev/null || break; sleep 1; done
    pkill -u "$U" -x plasmashell 2>/dev/null
  fi
fi
CFG=$UHOME/.config; LS=$UHOME/.local/share
# Los ajustes que cambia el diseño: los de ahora se apartan y vuelven los de antes (los que no
# estaban, no vuelven). Inicio automático y accesos del menú: solo se quitan los de Coucou.
mapfile -t LISTA < <(bash "$DIR/copia.sh" lista)
for f in "${LISTA[@]}"; do
  [ "$f" = autostart ] && continue
  apartar "$CFG/$f"
  if [ -e "$ANTES/$f" ]; then hacer cp -a "$ANTES/$f" "$CFG/$f"; fi
done
for f in "$CFG"/autostart/*.desktop "$LS"/applications/*.desktop; do
  [ -f "$f" ] || continue
  if grep -qE 'X-Coucou|^Exec=.*(/usr/(local/)?bin/)?(win11-|coucou)' "$f" || [[ "$(basename "$f")" =~ ^(coucou|win11-|systemsettings\.desktop$|cachyos-hello\.desktop$) ]]; then
    apartar "$f"
  fi
done
for d in autostart; do
  for f in "$ANTES/$d"/*.desktop; do [ -f "$f" ] && [ ! -e "$CFG/$d/$(basename "$f")" ] && hacer cp -a "$f" "$CFG/$d/"; done
done
for f in "$ANTES/local-share/applications"/*.desktop; do
  [ -f "$f" ] && [ ! -e "$LS/applications/$(basename "$f")" ] && hacer cp -a "$f" "$LS/applications/"
done
# Temas, iconos y fondos de Coucou y de Windows 11 que se copiaron a la cuenta
for f in "$LS"/icons/* "$LS"/wallpapers/* "$LS"/aurorae/themes/* "$LS"/plasma/desktoptheme/* "$LS"/plasma/look-and-feel/* \
         "$LS"/color-schemes/*; do
  [[ "$(basename "$f")" =~ [Cc]oucou|[Ww]in11 ]] && apartar "$f"
done
[ -f "$LS/plasma/shells/org.kde.plasma.desktop/.coucou-lockscreen" ] && apartar "$LS/plasma/shells/org.kde.plasma.desktop"
apartar "$LS/coucou-tienda"; apartar "$LS/coucou-voz"
grep -qs 'kde-win11' "$UHOME/.local/bin/dolphin" && apartar "$UHOME/.local/bin/dolphin"
# Servicios de la cuenta de Coucou
for f in "$CFG"/systemd/user/*.wants/*coucou* "$CFG"/systemd/user/*.wants/*win11* "$CFG"/systemd/user/*.service.d/win11.conf; do
  [ -e "$f" ] || [ -L "$f" ] && apartar "$f"
done
[ $SIMULAR = 0 ] && find "$CFG/systemd/user" -mindepth 1 -type d -empty -delete 2>/dev/null
[ $SIMULAR = 0 ] && como_usuario update-desktop-database "$LS/applications" 2>/dev/null

# 3. Inicio de sesión: el de antes
paso 30 "Inicio de sesión"
ANTES_DM=$(cat "$ORIG/gestor-de-inicio.txt" 2>/dev/null)
[ -n "$ANTES_DM" ] || { systemctl cat plasmalogin.service >/dev/null 2>&1 && ANTES_DM=plasmalogin.service; }
AHORA_DM=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null)
if [ -n "$ANTES_DM" ] && [ "$ANTES_DM" != "$AHORA_DM" ] && systemctl cat "$ANTES_DM" >/dev/null 2>&1; then
  echo "Vuelve el de antes: $ANTES_DM (en lugar de ${AHORA_DM:-ninguno})"
  [ -n "$AHORA_DM" ] && hacer systemctl disable "$AHORA_DM"
  hacer systemctl enable -f "$ANTES_DM"
else
  echo "Se queda el que está: ${AHORA_DM:-ninguno}"
fi
# Lo de Coucou en /etc/sddm.conf.d (lo que no estaba antes); lo que estaba, como estaba
for f in /etc/sddm.conf.d/*; do
  [ -e "$f" ] || continue
  [ -e "$ORIG/sistema$f" ] || pacman -Qo "$f" >/dev/null 2>&1 || apartar "$f"
done
for f in "$ORIG"/sistema/etc/sddm.conf.d/* "$ORIG"/sistema/etc/sddm.conf; do
  [ -f "$f" ] && hacer cp -a "$f" "${f#"$ORIG"/sistema}"
done

# 4. Arranque: sin lo que agregó Coucou (los parámetros y el driver de video que sumó, su animación)
paso 40 "Arranque"
if [ $SIMULAR = 0 ]; then
  python3 - "$ORIG/sistema" <<'PY'
import re, sys
from pathlib import Path
orig = Path(sys.argv[1])
def leer(p):
    try: return Path(p).read_text()
    except OSError: return None
# mkinitcpio: los módulos de video y el gancho de plymouth que se sumaron (si no estaban antes)
cur, ant = leer("/etc/mkinitcpio.conf"), leer(orig / "etc/mkinitcpio.conf")
if cur:
    def lista(t, k):
        m = re.search(rf'(?m)^{k}=\((.*)\)', t or ""); return m, (m.group(1).split() if m else [])
    t = cur
    m, mods = lista(t, "MODULES"); _, mods0 = lista(ant, "MODULES")
    nuevos = [x for x in mods if x in mods0 or x not in ("amdgpu", "i915", "virtio_gpu", "vmwgfx")]
    if m and nuevos != mods: t = t[:m.start()] + f"MODULES=({' '.join(nuevos)})" + t[m.end():]
    m, hooks = lista(t, "HOOKS"); _, hooks0 = lista(ant, "HOOKS")
    if m and ant is not None and "plymouth" in hooks and "plymouth" not in hooks0:
        hooks.remove("plymouth"); t = t[:m.start()] + f"HOOKS=({' '.join(hooks)})" + t[m.end():]
    if t != cur: Path("/etc/mkinitcpio.conf").write_text(t); print("mkinitcpio.conf: como antes")
# Parámetros del arranque que agregó Coucou y no estaban
EXTRA = "splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto vt.global_cursor_default=0".split()
antes = set()
for f in ("etc/default/limine", "etc/default/grub", "etc/sdboot-manage.conf", "boot/refind_linux.conf", "boot/limine.conf"):
    t = leer(orig / f)
    if t: antes |= set(re.findall(r"[\w.]+=?[\w.]*", t))
hay_copia = bool(antes)
quitar = [p for p in EXTRA if p not in antes and (hay_copia or p != "splash")]
def limpiar(params): return " ".join(p for p in params.split() if p not in quitar)
def editar(path, patron):
    p = Path(path)
    if not p.is_file() or not quitar: return
    t = p.read_text(); n = re.sub(patron, lambda m: m.group(1) + limpiar(m.group(2)) + m.group(3), t, flags=re.M)
    if n != t: p.write_text(n); print("arranque: sin", " ".join(quitar), "en", path)
editar("/etc/default/limine", r'^(KERNEL_CMDLINE\[default\]\+?=")(.*)(")$')
for f in ("/boot/limine.conf", "/boot/efi/limine.conf", "/efi/limine.conf"): editar(f, r'^(\s*cmdline:\s*)(.*)()$')
editar("/etc/default/grub", r'^(GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(")$')
for base in ("/boot", "/efi"):
    for e in sorted(Path(base, "loader/entries").glob("*.conf")): editar(str(e), r'^(options\s+)(.*)()$')
editar("/etc/sdboot-manage.conf", r'^(LINUX_OPTIONS=")(.*)(")$')
editar("/boot/refind_linux.conf", r'^("[^"]*"\s+")(.*)(")$')
PY
else
  echo "  · sacar de /etc/mkinitcpio.conf y de la línea de arranque lo que sumó Coucou (si no estaba antes)"
fi
# La animación de antes
if [ -f "$ORIG/sistema/etc/plymouth/plymouthd.conf" ]; then
  hacer cp -a "$ORIG/sistema/etc/plymouth/plymouthd.conf" /etc/plymouth/plymouthd.conf
elif grep -qs '^Theme=coucou' /etc/plymouth/plymouthd.conf; then
  apartar /etc/plymouth/plymouthd.conf
fi

# 5. Servicios que activó Coucou y antes no estaban
paso 48 "Servicios"
if [ -s "$ORIG/servicios.txt" ]; then
  for s in bluetooth.service power-profiles-daemon.service avahi-daemon.service ananicy-cpp.service systemd-oomd.service; do
    systemctl is-enabled -q "$s" 2>/dev/null && ! grep -qx "$s" "$ORIG/servicios.txt" && hacer systemctl disable --now "$s"
  done
  systemctl --global is-enabled -q psd.service 2>/dev/null && ! grep -qx psd.service "$ORIG/servicios-cuenta.txt" 2>/dev/null &&
    hacer systemctl --global disable psd.service
else
  echo "No se sabe cuáles estaban antes (instalado con un instalador viejo): Bluetooth, energía y los demás quedan como están"
fi
command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Coucou AirPlay' && hacer ufw delete allow "Coucou AirPlay"

# 6. Paquetes
paso 55 "Quitando los paquetes de Coucou"
QUITAR=()
for p in coucou-claro kde-win11 hyper-headset-bin uxplay; do
  pacman -Q "$p" >/dev/null 2>&1 && ! en_original "$p" && QUITAR+=("$p")
done
# Lo que el instalador puso aparte (inicio de sesión, la sesión X11 para AnyDesk, la animación): solo si
# no estaba antes. Sin la lista de antes no se sabe: se deja.
SUELTOS=()
if [ $HAY_LISTA = 1 ]; then
  for p in sddm qt6-5compat xfce4-session xfwm4 xfce4-panel xfdesktop xfce4-settings xfconf xorg-xrandr xorg-xinput xorg-xset xorg-setxkbmap plymouth; do
    pacman -Q "$p" >/dev/null 2>&1 && ! en_original "$p" && SUELTOS+=("$p")
  done
  # SDDM mostrando el inicio de sesión ahora mismo: se deja instalado (desactivado); quitarlo con la
  # sesión abierta encima no conviene. Después de reiniciar se puede quitar: sudo pacman -Rns sddm
  if systemctl is-active -q sddm.service 2>/dev/null; then
    for i in "${!SUELTOS[@]}"; do [ "${SUELTOS[$i]}" = sddm ] && unset 'SUELTOS[i]'; done
    SUELTOS=("${SUELTOS[@]}")
  fi
fi
# Las apps que se eligieron al instalar (solo con --con-apps)
FLATS=()
if [ $APPS = 1 ] && [ $HAY_LISTA = 1 ]; then
  for p in steam cachyos-gaming-meta winboat code visual-studio-code-bin discord vesktop spotify-launcher anydesk-bin anydesk vlc; do
    pacman -Q "$p" >/dev/null 2>&1 && ! en_original "$p" && SUELTOS+=("$p")
  done
  while read -r _ app; do
    [ -n "${app:-}" ] && flatpak info --system "$app" >/dev/null 2>&1 && ! grep -qx "$app" "$ORIG/flatpaks.txt" 2>/dev/null && FLATS+=("$app")
  done < "$DIR/flatpaks.txt"
fi
echo "Paquetes: ${QUITAR[*]:-ninguno}${SUELTOS:+ · también: ${SUELTOS[*]}}"
# Flatpak lo trajo Coucou, pero si hay apps de Flathub instaladas se queda (si no, dejarían de andar)
if pacman -Q flatpak >/dev/null 2>&1 && [ -n "$(flatpak list --app --columns=application 2>/dev/null | grep -vxF -f <(printf '%s\n' "${FLATS[@]}") )" ]; then
  hacer pacman -D --asexplicit flatpak >/dev/null
fi
for app in "${FLATS[@]}"; do hacer flatpak uninstall --system -y --noninteractive "$app"; done
if [ ${#QUITAR[@]} -gt 0 ]; then
  if [ $SIMULAR = 1 ]; then echo "  · pacman -Rns ${QUITAR[*]} (y lo que se instaló solo para ellos)"
  else
    while [ -e /var/lib/pacman/db.lck ]; do echo "Esperando a que termine otra instalación…"; sleep 5; done
    pacman -Rns --noconfirm "${QUITAR[@]}" || { echo "!! no se pudieron quitar con lo suyo: se quitan solos"; pacman -R --noconfirm "${QUITAR[@]}"; }
  fi
fi
for p in "${SUELTOS[@]}"; do
  pacman -Q "$p" >/dev/null 2>&1 || continue
  if [ $SIMULAR = 1 ]; then echo "  · pacman -Rns $p (si nada más lo usa)"
  else pacman -Rns --noconfirm "$p" >/dev/null 2>&1 && echo "quitado: $p" || echo "se queda $p (otra cosa lo usa)"; fi
done

# 7. Lo que quedó de Coucou en el sistema sin ser de ningún paquete (va a la copia, no se borra)
paso 78 "Archivos de Coucou que quedaron sueltos"
for f in /usr/lib/coucou /usr/share/coucou /usr/share/kde-win11 /usr/share/sddm/themes/coucou-login /usr/share/plymouth/themes/coucou \
         /usr/share/wallpapers/coucou /usr/local/bin/win11-* /usr/bin/win11-* /usr/bin/coucou* /etc/xdg/autostart/*coucou* \
         /etc/xdg/autostart/*win11* /usr/share/applications/*coucou* /usr/share/applications/win11-* /usr/share/libalpm/hooks/coucou-*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  pacman -Qo "$f" >/dev/null 2>&1 && continue   # (lo de los paquetes ya lo quitó pacman)
  apartar "$f"
done
# Las cuentas nuevas: lo de antes en /etc/skel (sin pisar lo que haya)
[ -d "$ORIG/sistema/etc/skel" ] && hacer cp -an "$ORIG/sistema/etc/skel/." /etc/skel/

# 8. La imagen de arranque, de nuevo (sin la animación de Coucou)
paso 82 "Rehaciendo la imagen de arranque (tarda un minuto)"
if [ $SIMULAR = 1 ]; then echo "  · limine-mkinitcpio o mkinitcpio -P$([ -f /etc/default/grub ] && echo ' y grub-mkconfig')"
else
  if command -v limine-mkinitcpio >/dev/null; then limine-mkinitcpio || mkinitcpio -P; else mkinitcpio -P; fi || echo "!! no se pudo rehacer la imagen de arranque"
  [ -f /etc/default/grub ] && command -v grub-mkconfig >/dev/null && { grub-mkconfig -o /boot/grub/grub.cfg >/dev/null || echo "!! grub-mkconfig"; }
fi

# 9. Anotado: ya no está instalado (la copia original y las demás se quedan)
if [ $SIMULAR = 0 ]; then
  apartar "$SIS/instalado"
  bash "$DIR/copia.sh" anotar desinstalación "$(tr -d '[:space:]' < "$DIR/VERSION" 2>/dev/null)" "$U"
  # El aviso final primero (antes salía después de abrir el escritorio y a veces no se veía)
  echo
  echo "Listo: Coucou se desinstaló. REINICIA EL EQUIPO para ver todo como estaba (inicio de sesión y arranque)."
  echo "Lo que se quitó y cómo estaba antes de desinstalar: $BK"
  echo "Registro: $LOG"
  # El escritorio, de nuevo (ya con la barra de antes), sin atarlo a esta terminal
  if [ "${PLASMA:-0}" = 1 ]; then
    como_usuario systemctl --user start plasma-plasmashell.service </dev/null >/dev/null 2>&1 ||
      { como_usuario setsid plasmashell </dev/null >/dev/null 2>&1 & }
  fi
  [ $VENTANA = 1 ] && echo "@@ 100 Coucou se desinstaló" || echo "Ya puedes cerrar esta ventana."
  sleep 1   # que el registro termine de escribirse
else
  echo; echo "Fin de la simulación: no se cambió nada."
fi
