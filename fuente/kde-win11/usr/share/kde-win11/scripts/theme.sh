#!/usr/bin/env bash
# Modo claro/oscuro, color de énfasis y transparencia al estilo Windows 11.
# No toca la barra de tareas ni los atajos (eso lo hace apply.sh).
#
#   theme.sh [--mode light|dark] [--accent '#RRGGBB'] [--transparency on|off]
#   theme.sh --get            muestra el estado actual
#
# El estado se guarda en ~/.config/win11rc.
set -euo pipefail

bash "$(dirname "$0")/seed-user.sh"   # copias del usuario si los temas son del sistema
RC=~/.config/win11rc
get() { kreadconfig6 --file "$RC" --group Appearance --key "$1" --default "$2"; }
set_() { kwriteconfig6 --file "$RC" --group Appearance --key "$1" "$2"; }
kw() { kwriteconfig6 "$@"; }

MODE=$(get mode light); ACCENT=$(get accent '#0078D4'); TRANSP=$(get transparency on)
PREV_TRANSP=$TRANSP
CHANGED_MODE=0
while (($#)); do
  case "$1" in
    --mode) [ "$2" != "$MODE" ] && CHANGED_MODE=1; MODE=$2; shift ;;
    --accent) ACCENT=$2; shift ;;
    --transparency) TRANSP=$2; shift ;;
    --get) echo "mode=$MODE"; echo "accent=$ACCENT"; echo "transparency=$TRANSP"; exit 0 ;;
    --force) CHANGED_MODE=1 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$MODE" in light) Vc=Light ;; dark) Vc=Dark ;; *) echo "modo inválido: $MODE" >&2; exit 2 ;; esac
[[ "$ACCENT" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "color inválido: $ACCENT" >&2; exit 2; }
ACCENT=${ACCENT^^}

set_ mode "$MODE"; set_ accent "$ACCENT"; set_ transparency "$TRANSP"

# Windows usa un tono más claro del énfasis en modo oscuro y uno más oscuro en modo claro.
shade() { # $1=#RRGGBB $2=factor (-1..1; >0 aclara, <0 oscurece)
  python3 -c '
import sys
h=sys.argv[1].lstrip("#"); f=float(sys.argv[2])
c=[int(h[i:i+2],16) for i in (0,2,4)]
c=[round(v+(255-v)*f) if f>0 else round(v*(1+f)) for v in c]
print("#%02X%02X%02X"%tuple(c))' "$1" "$2"
}
# El color de énfasis se usa tal cual en todas partes (el mismo tono que la muestra elegida)
UI_ACCENT=$ACCENT
# Texto legible sobre el énfasis (blanco o negro según su luminosidad), como hace Windows
ACCENT_TEXT=$(python3 -c '
import sys
h=sys.argv[1].lstrip("#"); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
l=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
Y=0.2126*l(r)+0.7152*l(g)+0.0722*l(b)
print("#000000" if Y>0.4 else "#FFFFFF")' "$UI_ACCENT")

# --- Preparación (archivos; nada visible) -------------------------------------
# Kvantum: copia del tema con el azul original sustituido por el énfasis elegido
if command -v kvantummanager >/dev/null && [ ! -d ~/.config/Kvantum/Win11OS-$MODE ]; then
  echo "   aviso: falta el tema Kvantum Win11OS-$MODE (ejecuta install.sh); se deja el estilo actual" >&2
elif command -v kvantummanager >/dev/null; then
  SRC=~/.config/Kvantum/Win11OS-$MODE
  DST=~/.config/Kvantum/Win11OS-$MODE-accent
  rm -rf "$DST"; mkdir -p "$DST"
  for f in "$SRC"/*; do
    b=$(basename "$f"); nb=${b/Win11OS-$MODE/Win11OS-$MODE-accent}
    sed -E "s/#(4bc8ff|007de6|1e82ff)/$UI_ACCENT/Ig" "$f" > "$DST/$nb"
  done
  # Texto de la selección legible sobre el énfasis y enlaces del color de énfasis
  sed -i -E "s/^highlight\.text\.color=.*/highlight.text.color=$ACCENT_TEXT/;
             s/^link\.color=.*/link.color=$UI_ACCENT/" "$DST"/*.kvconfig
  # Menús contextuales (clic derecho): el tema los dibuja al 60 % y con piezas de distinta opacidad
  # (centro, bordes y esquinas), lo que deja un "cuadrado" más oscuro dentro. Todas las piezas
  # (incluido lo que hay dentro de sus grupos) pasan a la misma opacidad.
  # Además, como en Windows 11, el menú es algo más claro que las ventanas y lleva un borde de 1 px
  # para distinguirse de lo que tiene detrás (sin sombra, ver menu_shadow_depth más abajo).
  MENU_OP=1
  if [ "$MODE" = dark ]; then MENU_BG='#2C2C2C'; MENU_BORDER='#474747'; else MENU_BG='#F9F9F9'; MENU_BORDER='#D5D5D5'; fi
  python3 -I - "$MENU_OP" "$MENU_BG" "$MENU_BORDER" "$DST"/*.svg <<'PY'
import re, sys
op, bg, border = sys.argv[1:4]
def fix(block):
    block = re.sub(r'(?<![-\w])opacity:[0-9.]+', 'opacity:' + op, block)
    block = re.sub(r'(?<![-\w])fill:#[0-9a-fA-F]{6}', 'fill:' + bg, block)
    block = re.sub(r'(?<![-\w])fill="#[0-9a-fA-F]{6}"', 'fill="' + bg + '"', block)
    return re.sub(r'(?<![-\w])opacity="[0-9.]+"', 'opacity="1"', block)  # el atributo multiplicaría
def add_border(s):
    # Lado: tira "m X,Y h W v H h -W z" -> línea de 1 px en su lado exterior (x = X).
    # Esquina: cuarto de círculo de radio W con centro (CX, CY) -> arco de 1 px por fuera.
    # top/right/bottom y las otras esquinas son copias giradas (use) de estas dos piezas.
    side = re.search(r'<path[^>]*id="menu-normal-left0"[^>]*?/>', s, re.S)
    if not side:
        return s
    m = re.search(r'd="m ([-0-9.]+),([-0-9.]+) h ([0-9.]+) v ([0-9.]+) h -[0-9.]+ z"', side.group(0))
    if not m:
        return s
    x, y, w, h = map(float, m.groups())
    line = '<rect x="%g" y="%g" width="1" height="%g" style="opacity:%s;fill:%s"/>' % (x, y, h, op, border)
    s = s[:side.end()] + line + s[side.end():]
    grp = s.find('id="menu-normal-topleft"')
    corner = re.search(r'<path[^>]*?d="m ([-0-9.]+),([-0-9.]+) c[^"]*"[^>]*?/>', s[grp:], re.S) if grp >= 0 else None
    if corner:
        cx, top = float(corner.group(1)), float(corner.group(2))
        # Anillo relleno de 1 px (radios w y w-1) dentro de la pieza: un trazo (stroke) sobresaldría
        # medio píxel, cambiaría el tamaño de la pieza y dejaría una línea en las uniones.
        arc = ('<path d="M %g,%g A %g,%g 0 0 0 %g,%g L %g,%g A %g,%g 0 0 1 %g,%g Z" style="opacity:%s;fill:%s"/>'
               % (cx, top, w, w, cx - w, top + w, cx - w + 1, top + w, w - 1, w - 1, cx, top + 1, op, border))
        e = grp + corner.end()
        s = s[:e] + arc + s[e:]
    return s
def end_of_group(s, a):
    depth = 0
    for m in re.finditer(r'<g\b|</g>', s[a:]):
        depth += 1 if m.group(0) == '<g' else -1
        if depth == 0:
            return a + m.end()
    return len(s)
for p in sys.argv[4:]:
    s = open(p).read()
    out, pos = [], 0
    for m in re.finditer(r'<(\w+)\b[^>]*?id="menu-normal[^"]*"[^>]*>', s, re.S):
        if m.start() < pos:
            continue  # ya dentro de un grupo tratado
        end = end_of_group(s, m.start()) if m.group(1) == 'g' and not m.group(0).endswith('/>') else m.end()
        out += [s[pos:m.start()], fix(s[m.start():end])]
        pos = end
    out.append(s[pos:])
    open(p, 'w').write(add_border(''.join(out)))
PY
  # Sin sombra de menú: el tema la dibuja como una franja semitransparente de 10 px con esquinas
  # redondeadas y, sobre un fondo claro, el menú parece un cuadrado sólido dentro de un marco
  # transparente (y con desenfoque, KWin la desenfoca también). Así es un único fondo redondeado.
  sed -i -E 's/^menu_shadow_depth=.*/menu_shadow_depth=0/' "$DST"/*.kvconfig
  # Modo oscuro con los grises neutros de Windows 11 (el tema trae grises azulados, p. ej. #242932)
  if [ "$MODE" = dark ]; then
    sed -i -E 's/^window\.color=.*/window.color=#202020/; s/^base\.color=.*/base.color=#1E1E1E/;
               s/^alt\.base\.color=.*/alt.base.color=#262626/; s/^button\.color=.*/button.color=#2D2D2D/;
               s/^light\.color=.*/light.color=#3A3A3A/; s/^mid\.light\.color=.*/mid.light.color=#333333/;
               s/^dark\.color=.*/dark.color=#1A1A1A/; s/^mid\.color=.*/mid.color=#2A2A2A/' "$DST"/*.kvconfig
  fi
  # El Explorador siempre opaco, como en Windows 11; sin la vista transparente que Kvantum le aplica
  sed -i -E '/^opaque=/{/(=|,)dolphin(,|$)/!s/$/,dolphin/}' "$DST"/*.kvconfig
  sed -i -E 's/^transparent_dolphin_view=.*/transparent_dolphin_view=false/' "$DST"/*.kvconfig
  # Apps y menús de Kvantum siempre sólidos, como en Windows 11. Con cualquier translucidez de
  # Kvantum (translucent_windows, blurring, popup_blurring o reduce_menu_opacity) se ven rendijas en
  # las uniones de las piezas redondeadas del menú, y sin desenfoque se lee lo que hay detrás.
  # La transparencia (ajuste de Configuración) queda para la barra de tareas, el menú Inicio y Plasma.
  sed -i -E 's/^(translucent_windows|blurring|popup_blurring)=.*/\1=false/; s/^reduce_menu_opacity=.*/reduce_menu_opacity=0/' "$DST"/*.kvconfig
  kw --file ~/.config/Kvantum/kvantum.kvconfig --group General --key theme "Win11OS-$MODE-accent"
  kw --file kdeglobals --group KDE --key widgetStyle kvantum
fi

# Explorador como Windows 11: ventana sólida aunque la transparencia esté activada (con Kvantum
# translúcido la lista y la ruta quedaban grises), lista de archivos y panel de navegación algo
# más claro con línea de división. La carga el lanzador ~/.local/bin/dolphin de explorer.sh.
mkdir -p ~/.config/win11
if [ "$MODE" = dark ]; then VIEW='#1E1E1E'; PANE='#26272A'; LINE='#3A3A3A'; else VIEW='#FFFFFF'; PANE='#F9F9F9'; LINE='#EBEBEB'; fi
# Caja de búsqueda como la de Windows 11 (campo redondeado): la real del Dolphin parcheado y,
# con el Dolphin normal, el botón "Buscar" con el mismo aspecto
if [ "$MODE" = dark ]; then FIELD='#2B2B2B'; FIELD_H='#323232'; FIELD_B='#3A3A3A'; FIELD_T='#9A9A9A'; FIELD_TXT='#FFFFFF'
else FIELD='#FFFFFF'; FIELD_H='#F6F6F6'; FIELD_B='#E0E0E0'; FIELD_T='#5F5F5F'; FIELD_TXT='#1A1A1A'; fi
cat > ~/.config/win11/dolphin.qss <<EOF
DolphinMainWindow, KItemListContainer { background-color: $VIEW; }
KFilePlacesView { background-color: $PANE; border: none; border-right: 1px solid $LINE; }
QToolBar#mainToolBar, QToolBar#commandBar { border: none; border-bottom: 1px solid $LINE; }
DolphinUrlNavigator { background-color: $FIELD; border: 1px solid $FIELD_B; border-radius: 4px; margin: 2px 6px; }
DolphinUrlNavigator:focus-within { border-bottom: 2px solid $UI_ACCENT; }
DolphinUrlNavigator KUrlComboBox, DolphinUrlNavigator KUrlComboBox QLineEdit { background: transparent; border: none; color: $FIELD_TXT; }
QLineEdit#win11SearchField { padding: 4px 8px; margin: 2px 6px; color: $FIELD_TXT; background-color: $FIELD;
  border: 1px solid $FIELD_B; border-bottom-color: $FIELD_T; border-radius: 4px; }
QLineEdit#win11SearchField:hover { background-color: $FIELD_H; }
QLineEdit#win11SearchField:focus { background-color: $VIEW; border-bottom: 2px solid $UI_ACCENT; }
QToolButton[text="Buscar"] { min-width: 230px; padding: 4px 10px; margin: 2px 4px; text-align: left; color: $FIELD_T;
  background-color: $FIELD; border: 1px solid $FIELD_B; border-bottom-color: $FIELD_T; border-radius: 4px; }
QToolButton[text="Buscar"]:hover { background-color: $FIELD_H; }
QToolButton[text="Buscar"]:checked { background-color: $VIEW; border-bottom: 2px solid $UI_ACCENT; }
QDockWidget#placesDock, QDockWidget#placesDock > QWidget { background-color: $PANE; }
EOF

# Tema de Plasma (barra de tareas, menú Inicio, ajustes rápidos, calendario, notificaciones…):
#  - siempre una copia propia SIN el archivo "colors" del tema: así Plasma usa el esquema de colores
#    del sistema y el color de énfasis elegido (el tema traía un azul fijo, #4BC8FF)
#  - con transparencia, la variante translúcida (desenfoque detrás); sin ella, la sólida: sin
#    desenfoque los fondos normales (80 % opacos) dejan leer lo que hay detrás
DT=~/.local/share/plasma/desktoptheme
if [ "$TRANSP" = on ]; then DESK="Win11OS-$MODE-blur"; else DESK="Win11OS-$MODE-solid"; fi
# Se alternan dos copias (…-blur / …-blur-b): aplicar la que no está en uso recarga Plasma una sola
# vez, sin parpadeos (aplicar la misma no recarga nada)
[ "$(kreadconfig6 --file plasmarc --group Theme --key name)" = "$DESK" ] && DESK="$DESK-b"
for old in "$DT"/Win11OS-*; do   # quita la copia sobrante del otro modo/variante
  n=$(basename "$old"); case "$n" in Win11OS-dark|Win11OS-light|"$DESK"|"$(kreadconfig6 --file plasmarc --group Theme --key name)") ;; *) rm -rf "$old" ;; esac
done
if [ -d "$DT/Win11OS-$MODE" ]; then
  S="$DT/$DESK"
  rm -rf "$S"; cp -a "$DT/Win11OS-$MODE" "$S"; rm -f "$S/colors"
  if [ "$TRANSP" = off ] && [ -d "$S/solid" ]; then
    rm -rf "$S/translucent"
    (cd "$S/solid" && find . -type f) | while read -r f; do
      rm -f "$S/${f%.*}.svg" "$S/${f%.*}.svgz"; cp "$S/solid/$f" "$S/$f"
    done
    # Fondo sólido de ventanas emergentes (ajustes rápidos, tarjeta de música, menú Inicio,
    # calendario…) y globos de ayuda con el MISMO color que la barra de tareas: el tema usaba el color
    # de botón (gris claro, p. ej. 68,68,68 frente a 30,30,30 de la barra)
    python3 -I - "$S" <<'PY'
import gzip, os, sys
root = sys.argv[1]
for rel in [pre + r for pre in ('', 'solid/') for r in ('dialogs/background', 'widgets/background', 'widgets/tooltip')]:  # solid/: lo pide la barra opaca
    for ext in ('.svg', '.svgz'):
        p = os.path.join(root, rel + ext)
        if not os.path.exists(p):
            continue
        b = gzip.open(p).read() if ext == '.svgz' else open(p, 'rb').read()
        b = b.replace(b'ColorScheme-ButtonBackground', b'ColorScheme-Background')
        if ext == '.svgz':
            with gzip.open(p, 'wb') as g:
                g.write(b)
        else:
            open(p, 'wb').write(b)
PY
  fi
  sed -i -E "s/^(Name|X-KDE-PluginInfo-Name)=.*/\1=$DESK/" "$S/metadata.desktop"
  # El tema dibuja en azul fijo (#4BC8FF) deslizadores, interruptores, casillas, la raya de la
  # bandeja…: se cambia por el color de énfasis (también dentro de los .svgz comprimidos)
  python3 -I - "$S" "$UI_ACCENT" <<'PY'
import gzip, os, re, sys
root, accent = sys.argv[1], sys.argv[2]
pat = re.compile(rb'#4bc8ff', re.I)
for d, _, files in os.walk(root):
    for f in files:
        p = os.path.join(d, f)
        if f.endswith('.svg'):
            b = open(p, 'rb').read()
            if pat.search(b):
                open(p, 'wb').write(pat.sub(accent.encode(), b))
        elif f.endswith('.svgz'):
            b = gzip.open(p).read()
            if pat.search(b):
                with gzip.open(p, 'wb') as g:
                    g.write(pat.sub(accent.encode(), b))
PY
else
  DESK="Win11OS-$MODE"
fi
# --- Transición ---------------------------------------------------------------
# Todo lo anterior solo prepara archivos (no se ve). Desde aquí, lo visible, con el "Fundido de
# cambios" de KWin, que funde suavemente del aspecto anterior al nuevo, como Windows. El fundido se alarga mientras dura el cambio (velocidad de animaciones ×3)
# y luego se restaura la velocidad.
# La velocidad original se guarda en un archivo: si theme.sh se ejecuta otra vez antes de que se
# restaure (cambios seguidos en Configuración), no debe tomar el ×3 temporal como "original".
FACTOR_FILE="${XDG_RUNTIME_DIR:-/tmp}/win11-anim-factor"
if [ -s "$FACTOR_FILE" ]; then FACTOR=$(cat "$FACTOR_FILE")
else
  FACTOR=$(kreadconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor --default 1)
  [ "$FACTOR" = 3 ] && FACTOR=0.5   # valor atascado de una versión anterior
  echo "$FACTOR" > "$FACTOR_FILE"
fi
kw --file kdeglobals --group KDE --key AnimationDurationFactor 3
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true   # que KWin use ya la nueva velocidad
# Se restaura siempre al salir (también si algo falla), cuando el fundido ya ha terminado. setsid:
# que no muera con el proceso que lanzó theme.sh (p. ej. al cerrar Configuración)
trap 'setsid -f sh -c '\''sleep 2.5; f=$(cat "$1" 2>/dev/null) && [ -n "$f" ] || exit 0; rm -f "$1"; kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor "$f"; qdbus6 org.kde.KWin /KWin reconfigure'\'' _ "'"$FACTOR_FILE"'" >/dev/null 2>&1' EXIT
# Sin espera (0 ms): no se congela nada (un vídeo sigue moviéndose); el fundido parte de la imagen
# actual y los cambios aparecen poco a poco mientras dura. Como las ventanas no cambian, solo se ve
# transformarse lo que sí cambia: fondos de la barra, menús y paneles (sólido ↔ translúcido, color)
qdbus6 org.kde.KWin /org/kde/KWin/BlendChanges org.kde.KWin.BlendChanges.start 0 >/dev/null 2>&1 || true

# --- Modo (solo si cambia, porque recarga temas completos) -------------------
if [ "$CHANGED_MODE" = 1 ]; then
  plasma-apply-cursortheme "$([ "$MODE" = dark ] && echo Fluent-dark-cursors || echo Fluent-cursors)" >/dev/null 2>&1 || true
  ICONS=$([ "$MODE" = dark ] && echo Win11-dark || echo Win11)
  kw --file kdeglobals --group Icons --key Theme "$ICONS"
  /usr/lib/plasma-changeicons "$ICONS" >/dev/null 2>&1 || true
  # Barra de título opaca como en Windows 11 (el tema original es 65 % transparente)
  AU=~/.local/share/aurorae/themes
  if [ -d "$AU/Win11OS-$MODE" ]; then
    rm -rf "$AU/Win11OS-$MODE-solid"; mkdir -p "$AU/Win11OS-$MODE-solid"
    for f in "$AU/Win11OS-$MODE"/*; do
      b=$(basename "$f"); nb=${b/Win11OS-${MODE}rc/Win11OS-$MODE-solidrc}
      sed -E 's/opacity:0\.65/opacity:1/g; s/opacity="\.65"/opacity="1"/g' "$f" > "$AU/Win11OS-$MODE-solid/$nb"
    done
    sed -i -E "s/^(X-KDE-PluginInfo-Name|Name)=.*/\1=Win11OS-$MODE-solid/" "$AU/Win11OS-$MODE-solid/metadata.desktop"
    kw --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__Win11OS-$MODE-solid"
  else
    kw --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__Win11OS-$MODE"
  fi
  # Cambia el fondo solo si es uno de los de Windows 11 (respeta un fondo propio)
  CUR=$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'var d=desktops()[0]; d.currentConfigGroup=["Wallpaper","org.kde.image","General"]; print(d.readConfig("Image"))' 2>/dev/null || true)
  if [ -z "$CUR" ] || [[ "$CUR" == *Win11OS-* ]]; then
    WP=$(ls ~/.local/share/wallpapers/Win11OS-$MODE/contents/images/* | head -1)
    plasma-apply-wallpaperimage "$WP" >/dev/null || true
    kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$WP"
  fi
fi

# --- Color de énfasis --------------------------------------------------------
# En segundo plano (es lo más lento): se espera antes de terminar
(
[ "$CHANGED_MODE" = 1 ] && plasma-apply-colorscheme "Win11OS$Vc" >/dev/null 2>&1
plasma-apply-colorscheme --accent-color "$UI_ACCENT" >/dev/null 2>&1 || true
# KDE oscurece el color de selección al aplicar el énfasis (p. ej. #DA3B01 → 163,74,42): se pone el
# tono exacto en la selección, los bordes de foco y lo que está bajo el puntero, con texto legible
rgb() { printf '%d,%d,%d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }
kw --file kdeglobals --group Colors:Selection --key BackgroundNormal "$(rgb "$UI_ACCENT")"
kw --file kdeglobals --group Colors:Selection --key BackgroundAlternate "$(rgb "$UI_ACCENT")"
kw --file kdeglobals --group Colors:Selection --key ForegroundNormal "$(rgb "$ACCENT_TEXT")"
for g in View Window Button Selection Tooltip Complementary Header; do
  kw --file kdeglobals --group "Colors:$g" --key DecorationFocus "$(rgb "$UI_ACCENT")"
  kw --file kdeglobals --group "Colors:$g" --key DecorationHover "$(rgb "$UI_ACCENT")"
done
# Avisar a las apps KDE abiertas de que la paleta ha cambiado (PaletteChanged)
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true
) &
kw --file kdeglobals --group General --key accentColorFromWallpaper false

# GTK: variante de Fluent más cercana al énfasis
FLUENT=$(python3 -c '
import sys,colorsys
h=sys.argv[1].lstrip("#"); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
H,L,S=colorsys.rgb_to_hls(r,g,b); H*=360
if S<0.18: print("grey")
elif H<15 or H>=345: print("red")
elif H<40: print("orange")
elif H<65: print("yellow")
elif H<160: print("green")
elif H<195: print("teal")
elif H<250: print("")
elif H<290: print("purple")
else: print("pink")' "$ACCENT")
GTK="Fluent-round${FLUENT:+-$FLUENT}-$Vc"
[ -d ~/.themes/$GTK ] || GTK="Fluent-round-$Vc"
qdbus6 org.kde.kded6 /modules/gtkconfig org.kde.GtkConfig.setGtkTheme "$GTK" >/dev/null 2>&1 || true
kw --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-theme-name "$GTK"
kw --file ~/.config/gtk-3.0/settings.ini --group Settings --key gtk-application-prefer-dark-theme "$([ "$MODE" = dark ] && echo true || echo false)"
gsettings set org.gnome.desktop.interface color-scheme "$([ "$MODE" = dark ] && echo prefer-dark || echo default)" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "$GTK" 2>/dev/null || true
if [ -d ~/.themes/$GTK/gtk-4.0 ]; then
  mkdir -p ~/.config/gtk-4.0
  for f in gtk.css gtk-dark.css assets; do
    rm -rf ~/.config/gtk-4.0/$f; ln -sf ~/.themes/$GTK/gtk-4.0/$f ~/.config/gtk-4.0/$f
  done
fi

# --- Transparencia -----------------------------------------------------------
B=$([ "$TRANSP" = on ] && echo true || echo false)
# Barra de tareas: siempre translúcida u opaca según el ajuste. En "adaptable" se vuelve opaca con
# una ventana maximizada y sus paneles emergentes (ajustes rápidos, calendario) pasan a sólidos
# mientras el menú Inicio sigue translúcido: no coincidían
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  "panels().forEach(function (p) { p.opacity = '$([ "$TRANSP" = on ] && echo translucent || echo opaque)'; })" >/dev/null 2>&1 || true
kw --file kwinrc --group Plugins --key blurEnabled "$B"
kw --file kwinrc --group Plugins --key contrastEnabled "$B"
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.$([ "$B" = true ] && echo loadEffect || echo unloadEffect) blur >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.$([ "$B" = true ] && echo loadEffect || echo unloadEffect) contrast >/dev/null 2>&1 || true

plasma-apply-desktoptheme "$DESK" >/dev/null 2>&1 || true


wait
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
echo "modo=$MODE énfasis=$ACCENT (interfaz $UI_ACCENT) transparencia=$TRANSP gtk=$GTK"
