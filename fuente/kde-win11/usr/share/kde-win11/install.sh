#!/usr/bin/env bash
# Instala temas, iconos, cursores y fuente estilo Windows 11 (solo en $HOME) y aplica la configuración.
# Uso: ./install.sh [light|dark]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=~/.cache/dotfiles-src; mkdir -p "$SRC"

echo "==> Paquetes del sistema recomendados (requieren sudo):"
for p in kvantum kwin-effect-rounded-corners cmake extra-cmake-modules sassc; do pacman -Q "$p" >/dev/null 2>&1 || echo "   falta: $p  ->  sudo pacman -S $p"; done

echo "==> Copia de seguridad de la configuración actual"
B="$HERE/../backup/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$B"
(cd ~/.config && cp -a kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc \
   kcminputrc ksplashrc kscreenlockerrc kglobalshortcutsrc dolphinrc mimeapps.list gtk-3.0 gtk-4.0 Kvantum "$B"/ 2>/dev/null || true)
cp -a ~/.local/share/user-places.xbel "$B"/ 2>/dev/null || true

# Versiones fijas de cada tema (las probadas con estos scripts). Para actualizar uno, cambia su commit.
# Sin conexión se usa la copia ya descargada, si existe.
fetch() { # usuario/repo commit
  local d="$SRC/${1#*/}"
  if [ ! -d "$d/.git" ]; then
    rm -rf "$d"; git init -q "$d"; git -C "$d" remote add origin "https://github.com/$1.git"
  fi
  if git -C "$d" cat-file -e "$2^{commit}" 2>/dev/null || git -C "$d" fetch -q --depth 1 origin "$2"; then
    git -C "$d" -c advice.detachedHead=false checkout -q "$2"
  elif git -C "$d" rev-parse -q --verify HEAD >/dev/null; then
    echo "   aviso: no se pudo descargar $1; se usa la copia local ($(git -C "$d" rev-parse --short HEAD))"
  else
    echo "   error: no se pudo descargar $1 (¿hay conexión?)"; exit 1
  fi
}
echo "==> Descargando temas"
fetch yeyushengfan258/Win11OS-kde        9f021c3e71da7baf59a0614ab858d53b1e455fd5
fetch yeyushengfan258/Win11-icon-theme   a5b460a407da143b32f19a503d7fcebb3edf2371
fetch vinceliuice/Fluent-icon-theme      c8a244f571ef8fb47812bdc9dbce76546cedce69
fetch vinceliuice/Fluent-gtk-theme       7a49a464b0188c340101c52965c18190b1c694cf
fetch mops1k/kde6-win11-plasmoids        86c1944b195db12d043fc21be89449f4930c70d3

echo "==> Instalando temas"
bash "$SRC/Win11OS-kde/install.sh"
# El tema trae hojas de estilo sobrantes que pisan los colores dinámicos de Plasma
# (p. ej. globos de ayuda blancos con texto claro en modo oscuro): se eliminan
python3 "$HERE/scripts/fix-theme-colors.py" --fix ~/.local/share/plasma/desktoptheme/Win11OS-* >/dev/null
rm -f ~/.cache/plasma_theme_*.kcache; rm -rf ~/.cache/ksvg-elements
(cd "$SRC/Win11-icon-theme" && bash install.sh)
(cd "$SRC/Fluent-icon-theme/cursors" && bash install.sh)
(cd "$SRC/Fluent-gtk-theme" && bash install.sh -t all -c light -c dark -s standard --tweaks round)

echo "==> Menú Inicio Windows 11 (menu.11.next adaptado: compacto, en español, sin efectos pesados)"
kpackagetool6 -t Plasma/Applet -u "$HERE/plasma/menu.11.next" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$HERE/plasma/menu.11.next"
# Huecos de la barra: clic derecho -> "Administrador de tareas" y "Configuración de la barra de tareas"
kpackagetool6 -t Plasma/Applet -u "$HERE/plasma/win11-spacer" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "$HERE/plasma/win11-spacer"

echo "==> Barra de tareas, bandeja (ajustes rápidos) y reloj Windows 11 (compilados en ~/.local)"
if command -v cmake >/dev/null; then
  # Cambios propios: tarjeta multimedia y pie en los ajustes rápidos, traducción al español,
  # fecha en blanco y campana siempre visible en el reloj
  P11="$SRC/kde6-win11-plasmoids"
  git -C "$P11" checkout -q -- . && rm -rf "$P11/win11tray/po/es" "$P11/win11tray/contents/ui/components/MediaCard.qml"
  git -C "$P11" apply "$HERE/plasma/win11-plasmoids.patch"
  "$SRC/kde6-win11-plasmoids/scripts/install.sh" --only win11tasks,win11tray,win11clock --no-switch --no-restart
else
  echo "   (falta cmake: sudo pacman -S --needed base-devel cmake extra-cmake-modules plasma-wayland-protocols plasma-activities-stats libksysguard)"
fi

echo "==> Avisos de volumen y brillo encima de la barra de tareas (script de KWin)"
kpackagetool6 -t KWin/Script -u "$HERE/kwin/win11-osd" >/dev/null 2>&1 || kpackagetool6 -t KWin/Script -i "$HERE/kwin/win11-osd" >/dev/null
kwriteconfig6 --file kwinrc --group Plugins --key win11-osdEnabled true
# Abrir apps como en macOS: la ventana sale del icono o del punto del clic (sustituye a "scale")
kpackagetool6 -t KWin/Effect -u "$HERE/kwin/win11-open" >/dev/null 2>&1 || kpackagetool6 -t KWin/Effect -i "$HERE/kwin/win11-open" >/dev/null
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

echo "==> App Configuración estilo Windows 11"
if command -v cmake >/dev/null; then
  cmake -S "$HERE/settings-app" -B "$HERE/settings-app/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null
  cmake --build "$HERE/settings-app/build" -j"$(nproc)" && cmake --install "$HERE/settings-app/build" >/dev/null
  mkdir -p ~/.local/share/applications
  sed "s|^Exec=win11-settings|Exec=$HOME/.local/bin/win11-settings|" "$HERE/settings-app/win11-settings.desktop" > ~/.local/share/applications/win11-settings.desktop
  # Todo lo que abría "Preferencias del sistema" de KDE (favoritos, KRunner, etc.) abre ahora la app nueva.
  # La de KDE sigue disponible con "Más opciones (KDE)" dentro de la app.
  cat > ~/.local/share/applications/systemsettings.desktop <<EOD
[Desktop Entry]
Type=Application
Name=Configuración
Exec=$HOME/.local/bin/win11-settings
Icon=preferences-system
NoDisplay=true
EOD
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
fi

echo "==> Microsoft Store (tienda de apps con Flathub)"
if ! command -v flatpak >/dev/null; then
  echo "   falta flatpak  ->  sudo pacman -S flatpak   (y vuelve a ejecutar este script)"
elif command -v cmake >/dev/null; then
  # Flathub para el usuario: la tienda instala sin pedir contraseña
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  cmake -S "$HERE/store-app" -B "$HERE/store-app/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null
  cmake --build "$HERE/store-app/build" -j"$(nproc)" && cmake --install "$HERE/store-app/build" >/dev/null
  mkdir -p ~/.local/share/applications
  sed "s|^Exec=win11-store|Exec=$HOME/.local/bin/win11-store|" "$HERE/store-app/win11-store.desktop" > ~/.local/share/applications/win11-store.desktop
  # El tema de iconos Win11 no trae el de la Store: sin esto la barra de tareas muestra un icono en blanco
  for t in Win11 Win11-dark; do
    [ -d ~/.local/share/icons/$t/apps/scalable ] || continue
    install -m644 "$HERE/store-app/icons/win11-store.svg" ~/.local/share/icons/$t/apps/scalable/win11-store.svg
    gtk-update-icon-cache -f -q ~/.local/share/icons/$t 2>/dev/null || true
  done
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
  # Las apps de Flatpak (GTK) con el mismo tema, iconos y cursor que el escritorio
  flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=~/.themes:ro --filesystem=~/.local/share/icons:ro --filesystem=~/.icons:ro
fi

echo "==> Bienvenido a CachyOS (CachyOS Hello con forma de instalación de Windows 11)"
if command -v cmake >/dev/null; then
  cmake -S "$HERE/welcome-app" -B "$HERE/welcome-app/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null
  cmake --build "$HERE/welcome-app/build" -j"$(nproc)" && cmake --install "$HERE/welcome-app/build" >/dev/null
  mkdir -p ~/.local/share/applications
  sed "s|^Exec=win11-welcome|Exec=$HOME/.local/bin/win11-welcome|" "$HERE/welcome-app/win11-welcome.desktop" > ~/.local/share/applications/win11-welcome.desktop
  # CachyOS Hello (menú y autoarranque) abre la versión nueva
  printf '[Desktop Entry]\nType=Application\nName=CachyOS Hello\nExec=%s\nIcon=org.cachyos.hello\nNoDisplay=true\n' \
    "$HOME/.local/bin/win11-welcome" > ~/.local/share/applications/cachyos-hello.desktop
  if [ -f ~/.config/autostart/cachyos-hello.desktop ]; then
    rm -f ~/.config/autostart/cachyos-hello.desktop
    # --first-run: la app borra este autoarranque al abrirse, así solo sale la primera vez
    printf '[Desktop Entry]\nType=Application\nName=Bienvenido\nExec=%s --first-run\nIcon=org.cachyos.hello\n' \
      "$HOME/.local/bin/win11-welcome" > ~/.config/autostart/win11-welcome.desktop
  fi
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
fi

echo "==> Administrador de tareas estilo Windows 11 (Ctrl+Mayús+Esc y clic derecho en la barra)"
if command -v cmake >/dev/null; then
  cmake -S "$HERE/taskmgr-app" -B "$HERE/taskmgr-app/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null
  cmake --build "$HERE/taskmgr-app/build" -j"$(nproc)" && cmake --install "$HERE/taskmgr-app/build" >/dev/null
  mkdir -p ~/.local/share/applications
  # Exec con la ruta completa: KWin solo le da la lista de ventanas ("Aplicaciones") a ese ejecutable
  sed "s|^Exec=win11-taskmgr|Exec=$HOME/.local/bin/win11-taskmgr|" "$HERE/taskmgr-app/win11-taskmgr.desktop" > ~/.local/share/applications/win11-taskmgr.desktop
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
  kwriteconfig6 --file kglobalshortcutsrc --group services --group win11-taskmgr.desktop --key _launch "Ctrl+Shift+Esc"
  # El gestor de atajos no relee el archivo en marcha: se registra también por D-Bus
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel doRegister as 4 \
    win11-taskmgr.desktop _launch "Administrador de tareas" "Administrador de tareas" 2>/dev/null || true
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcutKeys 'asa(ai)' 4 \
    win11-taskmgr.desktop _launch "Administrador de tareas" "Administrador de tareas" 1 1 117440512 2>/dev/null || true
fi

echo "==> \"Elegir otra aplicación\" estilo Windows 11 (clic derecho en un archivo)"
if command -v cmake >/dev/null; then
  cmake -S "$HERE/openwith-app" -B "$HERE/openwith-app/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null
  cmake --build "$HERE/openwith-app/build" -j"$(nproc)" && cmake --install "$HERE/openwith-app/build" >/dev/null
  mkdir -p ~/.local/share/kio/servicemenus
  sed "s|@BIN@|$HOME/.local/bin/win11-openwith|" "$HERE/openwith-app/win11-openwith-servicemenu.desktop" \
    > ~/.local/share/kio/servicemenus/win11-openwith.desktop
  chmod +x ~/.local/share/kio/servicemenus/win11-openwith.desktop   # KDE exige que sea ejecutable
fi

echo "==> Explorador con buscador y barra de comandos de Windows 11 (compila Dolphin, tarda unos minutos)"
if command -v cmake >/dev/null; then
  bash "$HERE/scripts/build-dolphin.sh" || echo "   aviso: no se pudo compilar Dolphin; se usa el normal"
fi

echo "==> Fuente Selawik"
if ! fc-list | grep -qi selawik; then
  mkdir -p "$SRC/selawik" ~/.local/share/fonts/Selawik
  curl -sL https://github.com/microsoft/Selawik/releases/download/1.01/Selawik_Release.zip -o "$SRC/selawik/s.zip"
  bsdtar -xf "$SRC/selawik/s.zip" -C "$SRC/selawik"
  find "$SRC/selawik" -name '*.ttf' -exec cp {} ~/.local/share/fonts/Selawik/ \;
  fc-cache -f >/dev/null
fi

bash "$HERE/scripts/apply.sh" "${1:-light}"

echo "Inicio de sesión estilo Windows 11 (requiere sudo): sudo $HERE/scripts/login-win11.sh ${1:-light}"
echo "Para volver a la configuración anterior: $HERE/scripts/restore.sh"
