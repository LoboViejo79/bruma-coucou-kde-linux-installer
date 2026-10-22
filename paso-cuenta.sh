#!/usr/bin/env bash
# Instalar Bruma Coucou, parte de la cuenta (la corre paso-sistema.sh como el usuario, dentro de su sesión):
#   paso-cuenta.sh <carpeta> coucou <claro|oscuro> [acento #RRGGBB] [apps,…] [voz 0|1] [limpio 0|1]
# La estética la pone /usr/lib/coucou/estilo, lo mismo que usa Configuración al cambiar de barra:
# la base de kde-win11 (iconos, cursores, fuentes, Explorador) + todo el diseño de Coucou.
# Antes guarda una copia de la configuración de ahora.
set -uo pipefail
DIR=$1; DISENO=$2; MODO=$3; ACENTO=${4:-}; APPS=${5:-}; VOZ=${6:-1}; LIMPIO=${7:-0}
[ "$DISENO" = coucou ] || { echo "paso-cuenta: diseño desconocido: $DISENO (solo coucou)" >&2; exit 2; }
[ "$MODO" = oscuro ] && V=dark || V=light
K=/usr/share/kde-win11
cd "$HOME" 2>/dev/null || cd /   # runuser deja la carpeta de root: varios comandos fallaban ahí
paso() { echo "@@ $1 $2"; }
elegido() { [[ ",$APPS," == *",$1,"* ]]; }
cfg=~/.config
# Sin sesión gráfica (terminal sin escritorio): todo se guarda en archivos y Plasma lo toma al entrar.
# Las variables de sesión vacías se quitan: D-Bus las tomaría como "/run/user/UID/bus"
for v in DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY XAUTHORITY; do
  [ -n "${!v:-}" ] || unset "$v"
done
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || export WIN11_OFFLINE=1
ESTILO=coucou
export COUCOU_ACENTO="$ACENTO" COUCOU_ESTILO_SALIDA=1   # estilo: el color elegido y su detalle a este registro

# Copia de seguridad de lo que se va a cambiar (copia.sh: la misma lista que usa desinstalar.sh)
R=~/.local/share/coucou-instalador/respaldo-$(date +%Y%m%d-%H%M%S)
bash "$DIR/copia.sh" cuenta "$HOME" "$R"

# Reinstalar limpio: lo de Coucou que quedó de instalaciones viejas se va (ya está en la copia de
# arriba) y lo pone de nuevo el diseño. No se toca nada tuyo: archivos, chats de Coucou
# (~/.local/share/coucou), contraseñas guardadas, ni la configuración de otras apps.
if [ "$LIMPIO" = 1 ]; then
  paso 48 "Dejando tu cuenta limpia de instalaciones viejas"
  # La barra, cerrada: si no, al cerrarse volvería a escribir sus ajustes viejos
  pkill -x coucou 2>/dev/null; sleep 1
  rm -rf "$cfg/coucou" ~/.cache/coucou ~/.cache/coucou-* ~/.cache/win11-*
  # Accesos del menú y del inicio automático que pusieron Coucou o Windows 11 (los rehace el diseño)
  n=0
  for f in ~/.local/share/applications/*.desktop "$cfg"/autostart/*.desktop; do
    [ -f "$f" ] || continue
    if grep -qE 'X-Coucou|^Exec=.*(/usr/(local/)?bin/)?(win11-|coucou)' "$f" || [[ "$(basename "$f")" =~ ^(coucou|win11-|systemsettings\.desktop$|cachyos-hello\.desktop$) ]]; then
      rm -f "$f" && n=$((n + 1))
    fi
  done
  update-desktop-database ~/.local/share/applications 2>/dev/null
  # La copia de la pantalla de bloqueo de Coucou (se rehace con el diseño)
  SH=~/.local/share/plasma/shells/org.kde.plasma.desktop
  [ -f "$SH/.coucou-lockscreen" ] && rm -rf "$SH"
  # Servicios de la cuenta que apuntan a algo que ya no existe (de versiones viejas)
  find ~/.config/systemd/user -xtype l \( -name '*coucou*' -o -name '*win11*' \) -print -delete 2>/dev/null | sed 's/^/  quitado: /'
  systemctl --user daemon-reload 2>/dev/null
  rm -f "$cfg/win11-firstrun-done" "$cfg/win11-seeded"
  echo "Cuenta limpia: ajustes de Coucou y $n accesos viejos quitados (todo quedó en la copia: $R)"
fi

# El primer inicio de kde-win11 no tiene que volver a aplicar Windows 11 encima de lo elegido
# (apply.sh enlaza el tema GTK dentro de gtk-3.0 y gtk-4.0: en una cuenta nueva no existen)
mkdir -p "$cfg/autostart" "$cfg/gtk-3.0" "$cfg/gtk-4.0" "$cfg/coucou" ~/.local/share/applications
touch "$cfg/win11-firstrun-done" "$cfg/win11-seeded"

# 1. Base del diseño (de kde-win11): temas, iconos, cursores, fuentes, Explorador y atajos.
paso 50 "Aplicando la base del diseño (temas, iconos, cursores y fuentes)"
printf '[Desktop Entry]\nType=Application\nName=Configuración\nExec=/usr/bin/win11-settings\nIcon=preferences-system\nNoDisplay=true\n' \
  > ~/.local/share/applications/systemsettings.desktop
printf '[Desktop Entry]\nType=Application\nName=CachyOS Hello\nExec=/usr/bin/win11-welcome\nIcon=org.cachyos.hello\nNoDisplay=true\n' \
  > ~/.local/share/applications/cachyos-hello.desktop
rm -f "$cfg/autostart/cachyos-hello.desktop"
update-desktop-database ~/.local/share/applications 2>/dev/null
kwriteconfig6 --file kglobalshortcutsrc --group services --group win11-taskmgr.desktop --key _launch "Ctrl+Shift+Esc"
if [ -n "${WIN11_OFFLINE:-}" ]; then dbus-run-session bash "$K/scripts/apply.sh" "$V"; else bash "$K/scripts/apply.sh" "$V"; fi || echo "!! apply.sh"
# Anotado igual sin sesión: estilo lo lee para saber que la base ya está y no aplicarla de nuevo;
# enseguida pone el tema global de Coucou encima (org.coucou.code)
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.win11.desktop

# 2. Ajustes de la barra de Coucou del diseño original (posición, vidrio, apps fijadas…)
# Lo del diseño solo donde no hay nada propio: los paneles y ajustes que ya tenga la cuenta se respetan
if [ -d "$DIR/perfil/coucou" ]; then
  (cd "$DIR/perfil/coucou" && find . -type f) | while read -r f; do
    [ "${f#./}" = settings.json ] && continue
    [ -e "$cfg/coucou/$f" ] || { mkdir -p "$(dirname "$cfg/coucou/$f")"; cp -a "$DIR/perfil/coucou/$f" "$cfg/coucou/$f"; }
  done
fi
python3 - "$cfg/coucou/settings.json" "$ESTILO" "$DIR/perfil/coucou/settings.json" <<'PY'
import json, sys
p, barra, diseno = sys.argv[1], sys.argv[2], sys.argv[3]
try: s = json.load(open(p))
except Exception: s = {}
try: base = json.load(open(diseno))
except Exception: base = {}
for k, v in base.items():          # del diseño, solo lo que falta (lo propio no se pisa)
    s.setdefault(k, v)
s["taskbar"] = barra
json.dump(s, open(p, "w"), indent=2)
PY

# 3. La estética del diseño (la barra la pone instalar.sh al final, desde la sesión)
paso 60 "Aplicando el diseño de Coucou"
/usr/lib/coucou/estilo "$ESTILO" "$MODO" --sin-barra || { echo "!! el diseño $ESTILO tuvo pasos que fallaron (ver arriba)"; FALLO=1; }
FONDO=$(cat "$DIR/perfil/fondo" 2>/dev/null)
[ -f "${FONDO#file://}" ] && plasma-apply-wallpaperimage "${FONDO#file://}" >/dev/null 2>&1
echo "$ESTILO" > "$cfg/coucou/.arrancar-instalador"

# Tienda de aplicaciones: en el menú Inicio solo si se eligió. Después del diseño: los colores de Coucou
# escriben su propia entrada ("Tienda") y la volverían a mostrar.
TIENDA=~/.local/share/applications/win11-store.desktop
if elegido tienda; then
  [ -f "$TIENDA" ] && grep -q '^NoDisplay=true' "$TIENDA" && sed -i '/^NoDisplay=true$/d' "$TIENDA"
  grep -q 'X-Coucou-Override' "$TIENDA" 2>/dev/null || rm -f "$TIENDA"
elif [ -f "$TIENDA" ]; then
  grep -q '^NoDisplay=true' "$TIENDA" || sed -i '/^\[Desktop Entry\]$/a NoDisplay=true' "$TIENDA"
else
  printf '[Desktop Entry]\nType=Application\nName=Tienda\nExec=win11-store %%u\nNoDisplay=true\n' > "$TIENDA"
fi
update-desktop-database ~/.local/share/applications 2>/dev/null

# 4. Avisos por voz (Sebastián): la voz se baja ahora, así anda desde el primer inicio de sesión
QUIERE=~/.config/systemd/user/graphical-session.target.wants
activar_voz() {   # (sin sesión, systemctl --user no anda: el enlace a mano)
  systemctl --user enable coucou-voz.service 2>/dev/null ||
    { mkdir -p "$QUIERE" && ln -sf /usr/lib/systemd/user/coucou-voz.service "$QUIERE/coucou-voz.service"; }
}
if [ "$VOZ" = 1 ]; then
  paso 64 "Preparando los avisos por voz"
  if /usr/lib/coucou/coucou-voz --preparar; then
    activar_voz
    systemctl --user restart coucou-voz.service 2>/dev/null
    echo "Avisos por voz: listos"
  else
    echo "!! no se pudo bajar la voz (¿internet?): se vuelve a intentar sola al iniciar sesión"
    activar_voz
  fi
else
  systemctl --user disable --now coucou-voz.service 2>/dev/null; rm -f "$QUIERE/coucou-voz.service"
fi
paso 66 "Diseño aplicado"
exit ${FALLO:-0}
