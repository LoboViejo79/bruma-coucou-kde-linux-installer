#!/usr/bin/env bash
# Primer inicio de sesión con el paquete kde-win11 (instalación desde la ISO): aplica el aspecto de
# Windows 11 a la cuenta y abre Bienvenido. Lo lanza /etc/xdg/autostart/win11-firstrun.desktop y
# solo actúa una vez por usuario (~/.config/win11-firstrun-done).
# Hace lo mismo que la parte por usuario de install.sh, pero con todo ya instalado en /usr.
set -uo pipefail
DONE=~/.config/win11-firstrun-done
[ -f "$DONE" ] && exit 0
K=/usr/share/kde-win11
mkdir -p ~/.cache ~/.config
exec >~/.cache/win11-firstrun.log 2>&1

# Cuenta preparada durante la instalación (install-user.sh): el aspecto ya está aplicado y la barra
# la creó Plasma; aquí solo queda lo que necesita la sesión en marcha
SEEDED=0; [ -f ~/.config/win11-seeded ] && SEEDED=1
# ...salvo que después algo le haya vuelto a copiar /etc/skel encima (barra y tema de CachyOS)
if [ "$SEEDED" = 1 ] && ! grep -Eq '^LookAndFeelPackage=(org.kde.win11.desktop|org.coucou.code)' ~/.config/kdeglobals 2>/dev/null; then
  echo "la configuración de CachyOS pisó la preparada: se aplica todo de nuevo"
  SEEDED=0
fi
echo "preparada en la instalación: $SEEDED"

# Esperar a que la barra de Plasma esté lista: apply.sh la rehace por D-Bus
for _ in $( [ "$SEEDED" = 1 ] && echo 1 || seq 60 ); do
  qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
  sleep 1
done
[ "$SEEDED" = 1 ] || sleep 3

mkdir -p ~/.local/share/applications ~/.config/autostart
# Lo que abría "Preferencias del sistema" (favoritos, KRunner…) abre Configuración estilo Windows 11
cat > ~/.local/share/applications/systemsettings.desktop <<'EOD'
[Desktop Entry]
Type=Application
Name=Configuración
Exec=/usr/bin/win11-settings
Icon=preferences-system
NoDisplay=true
EOD
# CachyOS Hello (menú) abre Bienvenido; su autoarranque se sustituye por el de Bienvenido
printf '[Desktop Entry]\nType=Application\nName=CachyOS Hello\nExec=/usr/bin/win11-welcome\nIcon=org.cachyos.hello\nNoDisplay=true\n' \
  > ~/.local/share/applications/cachyos-hello.desktop
rm -f ~/.config/autostart/cachyos-hello.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true

# Microsoft Store: Flathub para el usuario (instala sin contraseña) y apps Flatpak con el mismo tema
if command -v flatpak >/dev/null; then
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
  flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=~/.themes:ro --filesystem=~/.local/share/icons:ro --filesystem=~/.icons:ro || true
fi

# Administrador de tareas con Ctrl+Mayús+Esc
kwriteconfig6 --file kglobalshortcutsrc --group services --group win11-taskmgr.desktop --key _launch "Ctrl+Shift+Esc"
busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel doRegister as 4 \
  win11-taskmgr.desktop _launch "Administrador de tareas" "Administrador de tareas" 2>/dev/null || true
busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcutKeys 'asa(ai)' 4 \
  win11-taskmgr.desktop _launch "Administrador de tareas" "Administrador de tareas" 1 1 117440512 2>/dev/null || true

# Todo el aspecto (barra, menú Inicio, temas, atajos, Explorador, efectos…). Modo claro, como Windows 11
[ "$SEEDED" = 1 ] || bash "$K/scripts/apply.sh" light

touch "$DONE"
# Bienvenido solo esta vez (--first-run: no se añade a los siguientes inicios de sesión)
[ -e /etc/coucou-iso/sin-bienvenido ] || setsid /usr/bin/win11-welcome --first-run >/dev/null 2>&1 &
[ "$SEEDED" = 1 ] || ! command -v notify-send >/dev/null || notify-send -a "Windows 11" -i preferences-desktop-theme \
  "Todo listo" "Cierra sesión y vuelve a entrar para que las fuentes y el estilo se apliquen en todas las apps." || true
