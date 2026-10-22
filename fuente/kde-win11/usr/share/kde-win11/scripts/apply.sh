#!/usr/bin/env bash
# Aplica el aspecto Windows 11 a KDE Plasma 6 (Wayland).
# Uso: apply.sh [light|dark]   (por defecto: light)
# Perfil de efectos: WIN11_PROFILE=auto|light|full (auto = ligero con renderizado por software o en máquina virtual)
set -euo pipefail

VARIANT=${1:-light}
case "$VARIANT" in
  light) V=light; Vc=Light ;;
  dark)  V=dark;  Vc=Dark ;;
  *) echo "Uso: $0 [light|dark]"; exit 1 ;;
esac

HERE=$(cd "$(dirname "$0")/.." && pwd)
bash "$HERE/scripts/seed-user.sh"   # copias del usuario si los temas son del sistema
kw() { kwriteconfig6 "$@"; }
TAB=$'\t'

PROFILE=${WIN11_PROFILE:-auto}
if [ "$PROFILE" = auto ]; then
  R=$(qdbus6 org.kde.KWin /KWin supportInformation 2>/dev/null || glxinfo -B 2>/dev/null || true)
  R=$(grep -i 'renderer string' <<<"$R" || true)
  # Solo llvmpipe/softpipe/swrast dibujan con la CPU. Ojo: "SVGA3D … LLVM" (VirtualBox/VMware con 3D)
  # sí usa la GPU del anfitrión, aunque glxinfo diga "Accelerated: no".
  if [[ "$R" =~ llvmpipe|softpipe|swrast ]]; then PROFILE=light
  # En una máquina virtual el 3D se traduce a la GPU del anfitrión: funciona, pero con más
  # latencia y el controlador de VirtualBox (vmwgfx) es inestable con efectos pesados
  elif systemd-detect-virt -q --vm 2>/dev/null; then PROFILE=light
  else PROFILE=full; fi
fi
case "$PROFILE" in light|full) ;; *) echo "WIN11_PROFILE inválido: $PROFILE (auto|light|full)"; exit 1 ;; esac
L() { [ "$PROFILE" = light ] && echo "$1" || echo "$2"; }   # valor según perfil: L ligero completo
# Animaciones de ventana tipo macOS (escala al abrir/cerrar, lámpara mágica al minimizar): baratas
# para cualquier GPU, también la de una máquina virtual; solo se quitan si se dibuja con la CPU.
# WIN11_ANIM=on|off fuerza el valor.
ANIM=${WIN11_ANIM:-auto}
if [ "$ANIM" = auto ]; then
  [[ "${R:-$(qdbus6 org.kde.KWin /KWin supportInformation 2>/dev/null | grep -i 'renderer string')}" =~ llvmpipe|softpipe|swrast ]] && ANIM=off || ANIM=on
fi
A() { [ "$ANIM" = off ] && echo "$1" || echo "$2"; }   # valor según animaciones: A sin con

echo "==> Tema global ($VARIANT)"
plasma-apply-colorscheme "Win11OS$Vc" || true
plasma-apply-desktoptheme "Win11OS-$V" || kw --file plasmarc --group Theme --key name "Win11OS-$V"
CURSORS=$([ "$V" = dark ] && echo Fluent-dark-cursors || echo Fluent-cursors)
plasma-apply-cursortheme "$CURSORS" || kw --file kcminputrc --group Mouse --key cursorTheme "$CURSORS"
ICONS=$([ "$V" = dark ] && echo Win11-dark || echo Win11)
kw --file kdeglobals --group Icons --key Theme "$ICONS"
/usr/lib/plasma-changeicons "$ICONS" 2>/dev/null || true

echo "==> Estilo de aplicaciones"
if command -v kvantummanager >/dev/null; then
  mkdir -p ~/.config/Kvantum
  kw --file ~/.config/Kvantum/kvantum.kvconfig --group General --key theme "Win11OS-$V"
  kw --file kdeglobals --group KDE --key widgetStyle kvantum
else
  echo "   (Kvantum no instalado: se usa Breeze. Instala con: sudo pacman -S kvantum)"
  kw --file kdeglobals --group KDE --key widgetStyle Breeze
fi

echo "==> Fuentes (Selawik ~ Segoe UI)"
kw --file kdeglobals --group General --key font "Selawik,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key menuFont "Selawik,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key toolBarFont "Selawik,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group General --key smallestReadableFont "Selawik,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kw --file kdeglobals --group WM --key activeFont "Selawik Semibold,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1"

echo "==> Decoración de ventanas (botones a la derecha: _ □ X)"
kw --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
kw --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__Win11OS-$V"
kw --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
kw --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "IAX"
kw --file kwinrc --group org.kde.kdecoration2 --key BorderSize Normal

echo "==> Efectos y comportamiento tipo Windows"
kw --file kwinrc --group Plugins --key blurEnabled true
kw --file kwinrc --group Plugins --key contrastEnabled true
# Abrir/cerrar: efecto propio win11-open (kwin/win11-open), la ventana sale del icono de la barra
# o del punto donde se hizo clic, como en macOS; el "scale" de KWin solo crece desde el centro
kw --file kwinrc --group Plugins --key scaleEnabled false
kw --file kwinrc --group Plugins --key win11-openEnabled "$(A false true)"
kw --file kwinrc --group Plugins --key wobblywindowsEnabled false
# Minimizar: "lámpara mágica" (el genio de macOS) con GPU; en el perfil ligero "squash", que solo
# encoge la ventana hacia la barra (barato)
kw --file kwinrc --group Plugins --key magiclampEnabled "$(A false true)"
kw --file kwinrc --group Plugins --key squashEnabled "$(A true false)"
kw --file kwinrc --group Effect-magiclamp --key AnimationDuration 450
kw --file kwinrc --group Plugins --key overviewEnabled true
# Perfil completo: escala+fundido al abrir/cerrar, menús que se deslizan, maximizar animado.
# Perfil ligero (sin GPU, llvmpipe): solo fundidos cortos; cada efecto de transformación
# o sombreado redibuja ventanas enteras en la CPU.
echo "   perfil de efectos: $PROFILE, animaciones: $ANIM"
kw --file kdeglobals --group KDE --key AnimationDurationFactor "$(A 0.4 0.6)"
# Abrir/cerrar como macOS: la ventana crece desde el 75 % con fundido (curva OutCubic) y al cerrar
# se encoge al 85 % (InCubic). Duración real = Duration × AnimationDurationFactor (≈ 390 ms): más
# corta no se llega a ver al abrir una app por primera vez, porque el primer fotograma tarda en llegar
kw --file kwinrc --group Effect-scale --key Duration 650
kw --file kwinrc --group Effect-scale --key InScale 0.75
kw --file kwinrc --group Effect-scale --key OutScale 0.85
kw --file kwinrc --group Plugins --key fadeEnabled "$(A true false)"
kw --file kwinrc --group Plugins --key glideEnabled false
kw --file kwinrc --group Plugins --key maximizeEnabled "$(A false true)"
kw --file kwinrc --group Plugins --key slidingpopupsEnabled "$(A false true)"
kw --file kwinrc --group Plugins --key fadingpopupsEnabled true
kw --file kwinrc --group Plugins --key slideEnabled true
kw --file kwinrc --group Plugins --key fadedesktopEnabled false
kw --file kwinrc --group Plugins --key dimscreenEnabled "$(L false true)"
kw --file kwinrc --group Plugins --key windowapertureEnabled false
kw --file kwinrc --group Effect-slide --key HorizontalGap 0
kw --file kwinrc --group Effect-slide --key SlideBackground false
if find /usr/lib/qt6/plugins -iname '*shapecorners*' 2>/dev/null | grep -q .; then
  # Las esquinas redondeadas son un shader por ventana: con cualquier GPU (también la de una máquina
  # virtual), no con renderizado por CPU. El paquete debe estar compilado para la KWin instalada; si
  # no carga, recompilar con kwin/rounded-corners-pkg (makepkg -si)
  kw --file kwinrc --group Plugins --key kwin4_effect_shapecornersEnabled "$(A false true)"
  kw --file kwinrc --group Round-Corners --key Size 8
  kw --file kwinrc --group Round-Corners --key InactiveCornerRadius 8
  kw --file kwinrc --group Round-Corners --key ActiveOutlineEnabled false
  kw --file kwinrc --group Round-Corners --key InactiveOutlineEnabled false
fi
# Alt+Tab con miniaturas en cuadrícula (como Windows 11)
kw --file kwinrc --group TabBox --key LayoutName thumbnail_grid
# Doble clic en barra de título = maximizar; Win+flechas ya ajusta (snap)
kw --file kwinrc --group Windows --key ElectricBorderMaximize true
kw --file kwinrc --group Windows --key ElectricBorderTiling true
# Esquina superior izquierda sin acción (Windows no tiene "hot corner")
kw --file kwinrc --group Effect-overview --key BorderActivate 9
kw --file kwinrc --group ElectricBorders --key TopLeft None

echo "==> Atajos tipo Windows"
kw --file kglobalshortcutsrc --group kwin --key Overview "Meta+Tab,Meta+W,Alternar vista general"
# Win+Arriba maximiza / Win+Abajo minimiza (se quita el mosaico arriba/abajo que usaba esas teclas)
kw --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,Meta+Up,Mosaico arriba"
kw --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Bottom" "none,Meta+Down,Mosaico abajo"
kw --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up${TAB}Meta+PgUp,Meta+PgUp,Maximizar la ventana"
kw --file kglobalshortcutsrc --group kwin --key "Window Minimize" "Meta+Down${TAB}Meta+PgDown,Meta+PgDown,Minimizar la ventana"
kw --file kglobalshortcutsrc --group services --group org.kde.dolphin.desktop --key _launch "Meta+E"
kw --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key RectangularRegionScreenShot "Meta+Shift+S${TAB}Meta+Shift+Print"
# Win+I abre "Configuración" estilo Windows 11 (o Preferencias de KDE si no está instalada)
if [ -f ~/.local/share/applications/win11-settings.desktop ] || [ -f /usr/share/applications/win11-settings.desktop ]; then
  kw --file kglobalshortcutsrc --group services --group systemsettings.desktop --key _launch "none"
  kw --file kglobalshortcutsrc --group services --group win11-settings.desktop --key _launch "Meta+I"
else
  kw --file kglobalshortcutsrc --group services --group systemsettings.desktop --key _launch "Meta+I"
fi

echo "==> Pantalla de bloqueo (sin pantalla de bienvenida)"
# Sin pantalla de bienvenida: el escritorio aparece en cuanto se inicia sesión
kw --file ksplashrc --group KSplash --key Theme None
kw --file ksplashrc --group KSplash --key Engine none
WP=$(ls ~/.local/share/wallpapers/Win11OS-$V/contents/images/* | head -1)
# Solo se pone el fondo de Windows 11 si no hay uno propio (vacío o ya uno de Win11OS)
CUR_WP=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'var d=desktops()[0]; d.currentConfigGroup=["Wallpaper","org.kde.image","General"]; print(d.readConfig("Image"))' 2>/dev/null || true)
OWN_WP=0; [ -n "$CUR_WP" ] && [[ "$CUR_WP" != *Win11OS-* ]] && OWN_WP=1
# Pantalla de bloqueo (Win+L) igual que el inicio de sesión win11-login: mismo fondo claro de
# Windows 11 en los dos modos, reloj siempre visible y sin controles multimedia
LOCK_WP=$(ls ~/.local/share/wallpapers/Win11OS-light/contents/images/* 2>/dev/null | head -1)
[ "$OWN_WP" = 1 ] || kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://${LOCK_WP:-$WP}"
kw --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock true
kw --file kscreenlockerrc --group Greeter --group LnF --group General --key showMediaControls false

echo "==> GTK (Fluent)"
qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme "Fluent-round-$Vc" 2>/dev/null || true
kw --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-theme-name "Fluent-round-$Vc"
# libadwaita (apps GTK4)
if [ -d ~/.themes/Fluent-round-$Vc/gtk-4.0 ]; then
  for f in gtk.css gtk-dark.css assets; do
    rm -rf ~/.config/gtk-4.0/$f
    ln -sf ~/.themes/Fluent-round-$Vc/gtk-4.0/$f ~/.config/gtk-4.0/$f
  done
fi

bash "$HERE/scripts/explorer.sh"

echo "==> Navegador predeterminado"
# Sin asociación http, el lanzador del navegador de la barra sale como "?"
# (se escribe mimeapps.list directamente: xdg-mime falla en KDE porque busca "qtpaths")
if [ -f /usr/share/applications/firefox.desktop ] && [ -z "$(kreadconfig6 --file mimeapps.list --group 'Default Applications' --key x-scheme-handler/https)" ]; then
  for m in x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; do
    kw --file mimeapps.list --group "Default Applications" --key "$m" firefox.desktop
  done
fi

# Win+A abre los ajustes rápidos (la bandeja): se le quita a "Recorrer las actividades".
# El gestor de atajos no relee el archivo en marcha, así que se hace por D-Bus.
busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcutKeys 'asa(ai)' \
  4 plasmashell "next activity" plasmashell "Recorrer las actividades" 0 2>/dev/null || true

echo "==> Barra de tareas Windows 11"
# Durante la instalación (WIN11_OFFLINE) Plasma no está en marcha: la barra la crea el diseño del
# tema global org.kde.win11.desktop al iniciar por primera vez (install-user.sh)
[ -n "${WIN11_OFFLINE:-}" ] || qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$HERE/plasma/taskbar-win11.js")"

echo "==> Fondo de pantalla"
if [ "$OWN_WP" = 1 ]; then echo "   se mantiene tu fondo: $CUR_WP"; else plasma-apply-wallpaperimage "$WP" || true; fi

echo "==> Modo, color de énfasis y transparencia (theme.sh)"
# Sin GPU (renderizado por CPU) la transparencia (desenfoque) empieza apagada; si no, se respeta el
# ajuste guardado en Configuración
bash "$HERE/scripts/theme.sh" --mode "$V" --force $([ "$ANIM" = off ] && echo --transparency off)

echo "==> Recargando KWin"
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
# reconfigure no descarga efectos ya activos: se cargan/descargan según lo escrito en kwinrc
for e in scale win11-open squash magiclamp maximize slidingpopups dimscreen fade; do
  on=$(kreadconfig6 --file kwinrc --group Plugins --key "${e}Enabled")
  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.$([ "$on" = true ] && echo loadEffect || echo unloadEffect) "$e" >/dev/null 2>&1 || true
done

echo "Listo. Cierra sesión y vuelve a entrar para que se apliquen fuentes, atajos y estilo de apps por completo."
