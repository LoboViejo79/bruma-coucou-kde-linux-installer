#!/usr/bin/env bash
# Explorador de archivos (Dolphin) al estilo Windows 11:
#  - arriba ← → ↑ ⟳, la dirección en una caja (⌂ › …) y buscar; debajo Nuevo | cortar copiar pegar
#    cambiar nombre eliminar | Ordenar | Ver | Filtro | Ver más … Detalles (a la derecha)
#  - vista Detalles con las columnas de Windows: Nombre, Fecha de modificación, Tipo, Tamaño
#  - panel lateral en el orden de Windows, sin las secciones Recientes y Etiquetas
#  - doble clic para abrir y atajos de Windows (Ctrl+Mayús+N, Alt+D, Alt+P…)
# Cierra las ventanas de Dolphin abiertas (si no, sobrescribirían la configuración al salir).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
kw() { kwriteconfig6 "$@"; }

echo "==> Explorador de archivos (Dolphin)"
for s in $(qdbus6 2>/dev/null | grep -E '^ ?org\.kde\.dolphin' || true); do
  qdbus6 "$s" /MainApplication quit >/dev/null 2>&1 || true
done
for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x dolphin >/dev/null || break; sleep 0.3; done

# Barra de herramientas. KXMLGUI solo usa la copia del usuario si su versión es >= la de Dolphin:
# se toma la versión de la interfaz que trae el ejecutable (comprimida con zstd en sus recursos).
UI=~/.local/share/kxmlgui5/dolphin/dolphinui.rc
mkdir -p "$(dirname "$UI")"
VER=$(python3 -I - /usr/bin/dolphin <<'EOF' 2>/dev/null || true
import re, subprocess, sys
d = open(sys.argv[1], 'rb').read()
best = 0
for m in re.finditer(rb'\x28\xb5\x2f\xfd', d):
    o = subprocess.run(['zstd', '-dcq'], input=d[m.start():m.start() + 300000], capture_output=True).stdout
    g = re.search(rb'<gui[^>]*name="dolphin"[^>]*version="(\d+)"', o)
    if g: best = max(best, int(g.group(1)))
print(best or '')
EOF
)
sed -E "s/(<gui name=\"dolphin\" version=)\"[0-9]+\"/\1\"${VER:-49}\"/" "$HERE/dolphin/dolphinui.rc" > "$UI"
[ -n "$VER" ] && [ "$VER" != 49 ] && echo "   aviso: Dolphin usa la interfaz v$VER (la plantilla es de la v49); revisa dolphin/dolphinui.rc"

# Disposición como Windows 11: barra superior, barra de comandos debajo en toda la anchura y solo el
# panel Lugares visible. KXMLGUI no aplica newline="true" del .rc, así que se escribe el estado de
# ventana de Qt (generado con dolphin/dolphin-state.cpp).
DOLPHIN_STATE='AAAA/wAAAAD9AAAAAwAAAAAAAADIAAACaPwCAAAAAvsAAAAUAHAAbABhAGMAZQBzAEQAbwBjAGsBAAAAIgAAAmgAAAATAP////sAAAAWAGYAbwBsAGQAZQByAHMARABvAGMAawAAAAAA/////wAAABMA////AAAAAQAAAAAAAAAA/AIAAAAB+wAAABAAaQBuAGYAbwBEAG8AYwBrAAAAAAD/////AAAAEwD///8AAAADAAAAAAAAAAD8AQAAAAH7AAAAGAB0AGUAcgBtAGkAbgBhAGwARABvAGMAawAAAAAA/////wAAADQA////AAADGgAAAmgAAAAEAAAABAAAAAgAAAAI/AAAAAIAAAACAAAAAQAAABYAbQBhAGkAbgBUAG8AbwBsAEIAYQByAQAAAAD/////AAAAAAAAAAAAAAACAAAAAQAAABQAYwBvAG0AbQBhAG4AZABCAGEAcgEAAAAA/////wAAAAAAAAAA'
kw --file dolphinrc --group MainWindow --key State "$DOLPHIN_STATE"
# Barra superior: flechas solo icono (priority 0 en el .rc); "Buscar" con texto (Dolphin sin parchear)
kw --file dolphinrc --group MainWindow --group "Toolbar mainToolBar" --key ToolButtonStyle TextBesideIcon
kw --file dolphinrc --group MainWindow --group "Toolbar mainToolBar" --key IconSize 16   # a 20-24 px el tema mezcla iconos a color
# Barra de comandos: texto al lado del icono solo en Nuevo, Ordenar, Ver y Detalles
kw --file dolphinrc --group MainWindow --group "Toolbar commandBar" --key ToolButtonStyle TextBesideIcon
kw --file dolphinrc --group MainWindow --group "Toolbar commandBar" --key IconSize 16
kw --file dolphinrc --group MainWindow --key MenuBar Disabled

# Comportamiento
kw --file kdeglobals --group KDE --key SingleClick false                 # doble clic para abrir
kw --file dolphinrc --group General --key ShowFullPath false             # ruta en "migas de pan"
kw --file dolphinrc --group General --key EditableUrl false
kw --file dolphinrc --group General --key ShowZoomSlider false
kw --file dolphinrc --group General --key RememberOpenedTabs false       # abre en Inicio, como Windows
kw --file dolphinrc --group General --key OpenNewTabAfterLastTab true
kw --file dolphinrc --group General --key ConfirmClosingMultipleTabs false
kw --file dolphinrc --group General --key BrowseThroughArchives true     # los .zip se abren como carpetas
kw --file dolphinrc --group General --key GlobalViewProps false          # cada carpeta recuerda su vista
kw --file dolphinrc --group DetailsMode --key ExpandableFolders false
# Mismo tamaño de icono con y sin vistas previas (Inicio va sin ellas, ver más abajo)
kw --file dolphinrc --group IconsMode --key IconSize 64
kw --file dolphinrc --group IconsMode --key PreviewSize 64

# Vista por defecto de las carpetas: Detalles. Las carpetas sin vista propia toman la de "global";
# ViewPropsTimestamp hace que las vistas guardadas antes de ahora vuelvan a ese valor.
NOW=$(date +%Y,%-m,%-d,%-H,%-M,%-S)
G=~/.local/share/dolphin/view_properties/global
mkdir -p "$G"
cat > "$G/.directory" <<EOF
[Dolphin]
Timestamp=$NOW
Version=4
ViewMode=1
VisibleRoles=Icons_text,Compact_text,Details_text,Details_modificationtime,Details_type,Details_size
SortFoldersFirst=true

[Settings]
HiddenFilesShown=false
EOF
kw --file dolphinrc --group General --key ViewPropsTimestamp "$NOW"

# Inicio (carpeta personal) sin vistas previas: con ellas Dolphin muestra primero el icono genérico
# de carpeta y ~0,4 s después el propio de Descargas, Documentos… (espera al proceso de miniaturas).
# Las demás carpetas mantienen las miniaturas. Dolphin guarda la vista de cada carpeta en un xattr.
python3 -I - "$HOME" "$NOW" <<'PY'
import os, re, sys
path, now = sys.argv[1], sys.argv[2]
name = 'user.kde.fm.viewproperties#1'
try:
    cur = os.getxattr(path, name).decode()
except OSError:
    cur = '[Dolphin]\nVersion=4\n'
lines = [l for l in cur.split('\n') if not re.match(r'(PreviewsShown|Timestamp|ViewMode|VisibleRoles)=', l)]
i = lines.index('[Dolphin]') + 1 if '[Dolphin]' in lines else 0
if i == 0:
    lines[:0] = ['[Dolphin]']; i = 1
# Cuadrícula de iconos (la vista compacta de Dolphin pone todo en una columna)
lines[i:i] = ['PreviewsShown=false', 'Timestamp=' + now, 'ViewMode=0', 'VisibleRoles=Icons_text,Compact_text,Details_text']
try:
    os.setxattr(path, name, '\n'.join(lines).encode())
except OSError as e:
    print('   aviso: no se pudo guardar la vista de Inicio:', e)
PY

# Panel lateral: orden de Windows (Inicio, Escritorio, Descargas, Documentos, Imágenes, Música,
# Vídeos) y sin las secciones Recientes y Etiquetas (en Windows están en Inicio, no en el panel)
P=~/.local/share/user-places.xbel
[ -f "$P" ] && python3 -I - "$P" <<'EOF'
import sys, os
import xml.etree.ElementTree as ET
from urllib.parse import unquote
p = sys.argv[1]
ET.register_namespace('bookmark', 'http://www.freedesktop.org/standards/desktop-bookmarks')
ET.register_namespace('kdepriv', 'http://www.kde.org/kdepriv')
ET.register_namespace('mime', 'http://www.freedesktop.org/standards/shared-mime-info')
tree = ET.parse(p); root = tree.getroot()
home = os.path.expanduser('~')
xdg = {}
try:
    for l in open(os.path.join(home, '.config/user-dirs.dirs')):
        if l.startswith('XDG_') and '=' in l:
            k, v = l.strip().split('=', 1)
            xdg[k] = v.strip('"').replace('$HOME', home)
except OSError:
    pass
order = [home] + [xdg.get('XDG_%s_DIR' % k) for k in ('DESKTOP', 'DOWNLOAD', 'DOCUMENTS', 'PICTURES', 'MUSIC', 'VIDEOS')]
bms = [b for b in root if b.tag == 'bookmark']
def path(b):
    h = b.get('href', '')
    return unquote(h[7:]).rstrip('/') if h.startswith('file://') else None
known = [b for o in order for b in bms if o and path(b) == o]
if known:
    first = min(list(root).index(b) for b in known)
    for b in known: root.remove(b)
    for i, b in enumerate(known): root.insert(first + i, b)
for e in root.iter():
    if e.tag in ('GroupState-RecentlySaved-IsHidden', 'GroupState-Tags-IsHidden'):
        e.text = 'true'
body = ET.tostring(root, encoding='unicode')
open(p, 'w', encoding='utf-8').write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE xbel>\n' + body + '\n')
EOF

# Lanzador que abre Dolphin con la hoja de estilos del panel de navegación (theme.sh).
# ~/.local/bin va antes que /usr/bin en el PATH de la sesión: cubre menú, barra y KRunner.
# "Mostrar en carpeta" desde otras apps arranca Dolphin por systemd: se redirige igual.
mkdir -p ~/.local/bin ~/.config/systemd/user/plasma-dolphin.service.d
cat > ~/.local/bin/dolphin <<'SH'
#!/bin/sh
# Explorador estilo Windows 11 (kde-win11/scripts/explorer.sh)
BIN=/usr/bin/dolphin
# Dolphin parcheado (scripts/build-dolphin.sh), solo si es de la misma versión que el del sistema:
# usa su libdolphinprivate. Tras actualizar Dolphin con pacman se usa el normal hasta recompilar.
# Primero la copia del usuario (build-dolphin.sh) y si no la del sistema (paquete kde-win11)
V=$(pacman -Q dolphin 2>/dev/null | cut -d' ' -f2 | cut -d- -f1)
for P in "$HOME/.local/opt/dolphin-win11" /opt/dolphin-win11; do
  if [ -x "$P/bin/dolphin" ] && [ "$(cat "$P/version" 2>/dev/null)" = "$V" ]; then
    BIN="$P/bin/dolphin"; break
  fi
done
QSS="$HOME/.config/win11/dolphin.qss"
[ -f "$QSS" ] && exec "$BIN" -stylesheet "$QSS" "$@"
exec "$BIN" "$@"
SH
chmod +x ~/.local/bin/dolphin
cat > ~/.config/systemd/user/plasma-dolphin.service.d/win11.conf <<'INI'
[Service]
ExecStart=
ExecStart=%h/.local/bin/dolphin --daemon
INI
systemctl --user daemon-reload 2>/dev/null || true

# Panel lateral con los nombres de Windows. Dolphin no permite quitar los encabezados de sección,
# así que se renombran con una traducción propia de KIO (~/.local/share/locale tiene prioridad
# sobre /usr/share/locale). Afecta también a los diálogos de abrir/guardar, que comparten el panel.
MO=/usr/share/locale/es/LC_MESSAGES/kio6.mo
if [[ "${LANG:-}" == es* ]] && [ -f "$MO" ] && command -v msgunfmt >/dev/null; then
  mkdir -p ~/.local/share/locale/es/LC_MESSAGES
  msgunfmt "$MO" | python3 -I -c '
import sys
po = sys.stdin.read()
for ctx, mid, new in [
    # Sin título (espacio de ancho cero): el panel de Windows 11 no tiene encabezados, solo separación
    ("@item", "Places", "\u200b"),
    ("@item", "Devices", "Este equipo"),
    ("@item", "Removable Devices", "Unidades extraíbles"),
    # El grupo de red se separa con una línea, como el panel de Windows 11
    ("@item", "Remote", "\u2500" * 24),
    ("KFile System Bookmarks", "Home", "Inicio"),
]:
    i = po.find("msgctxt \"%s\"\nmsgid \"%s\"\nmsgstr \"" % (ctx, mid))
    if i < 0: sys.exit("kio6: no se encuentra " + mid)
    j = po.index("msgstr \"", i) + 8; k = po.index("\"\n", j)
    po = po[:j] + new + po[k:]
sys.stdout.write(po)' | msgfmt -o ~/.local/share/locale/es/LC_MESSAGES/kio6.mo -
fi

# "Disco local (/)" (luego "Este equipo", ver más abajo) antes de la Papelera
# (el disco del sistema no aparece entre los dispositivos)
[ -f "$P" ] && python3 -I - "$P" <<'PY'
import sys
import xml.etree.ElementTree as ET
p = sys.argv[1]
NS = 'http://www.freedesktop.org/standards/desktop-bookmarks'
ET.register_namespace('bookmark', NS)
tree = ET.parse(p); root = tree.getroot()
bms = [b for b in root if b.tag == 'bookmark']
if not any(b.get('href') == 'file:///' for b in bms):
    b = ET.fromstring(
        '<bookmark xmlns:bookmark="%s" href="file:///"><title>Disco local (/)</title><info>'
        '<metadata owner="http://freedesktop.org"><bookmark:icon name="drive-harddisk"/></metadata>'
        '<metadata owner="http://www.kde.org"><ID>win11-root</ID></metadata></info></bookmark>' % NS)
    trash = [x for x in bms if x.get('href') == 'trash:/']
    root.insert(list(root).index(trash[0]) if trash else len(root), b)
    open(p, 'w', encoding='utf-8').write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE xbel>\n'
                                         + ET.tostring(root, encoding='unicode') + '\n')
PY

# Iconos a color en el panel, como Windows 11: el tema solo los tiene así en tamaño grande
# (scalable); a 16 px usa iconos grises. Se copian con otro nombre a hicolor y el panel los usa.
IC=~/.local/share/icons/hicolor/scalable/places
SRCI=~/.local/share/icons/Win11-dark/places/scalable
mkdir -p "$IC"
# La casa de Inicio es propia (icons/win11-user-home.svg): la del tema parece una pantalla
cp -f "$HERE/icons/win11-user-home.svg" "$IC/win11-user-home.svg"
for n in user-desktop folder-download folder-documents folder-pictures folder-music folder-videos; do
  [ -e "$SRCI/$n.svg" ] && cp -fL "$SRCI/$n.svg" "$IC/win11-$n.svg"
done
# Este equipo, Red y Papelera a color (en el tema están en devices@2x, apps@2x y places@2x)
for pair in computer:devices@2x/scalable/computer network:apps@2x/scalable/network-workgroup user-trash:places@2x/scalable/user-trash; do
  f=~/.local/share/icons/Win11-dark/${pair#*:}.svg
  [ -e "$f" ] && cp -fL "$f" "$IC/win11-${pair%%:*}.svg"
done
[ -f "$P" ] && python3 -I - "$P" "$HOME" <<'PY'
import os, sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote
p, home = sys.argv[1], sys.argv[2]
NS = 'http://www.freedesktop.org/standards/desktop-bookmarks'
ET.register_namespace('bookmark', NS)
xdg = {}
try:
    for l in open(os.path.join(home, '.config/user-dirs.dirs')):
        if l.startswith('XDG_') and '=' in l:
            k, v = l.strip().split('=', 1)
            xdg[k] = v.strip('"').replace('$HOME', home)
except OSError:
    pass
icons = {home: 'win11-user-home'}
for k, n in (('DESKTOP', 'user-desktop'), ('DOWNLOAD', 'folder-download'), ('DOCUMENTS', 'folder-documents'),
             ('PICTURES', 'folder-pictures'), ('MUSIC', 'folder-music'), ('VIDEOS', 'folder-videos')):
    if xdg.get('XDG_%s_DIR' % k):
        icons[xdg['XDG_%s_DIR' % k]] = 'win11-' + n
tree = ET.parse(p); root = tree.getroot()
by_href = {'trash:/': 'win11-user-trash', 'remote:/': 'win11-network', 'file:///': 'win11-computer'}
for b in root.iter('bookmark'):
    h = b.get('href', '')
    path = unquote(h[7:]).rstrip('/') if h.startswith('file://') and h != 'file:///' else None
    name = icons.get(path) or by_href.get(h)
    if name:
        for ic in b.iter('{%s}icon' % NS):
            ic.set('name', name)
    if h == 'file:///':
        # "Disco local (/)" pasa a ser "Este equipo", como en Windows 11
        b.find('title').text = 'Este equipo'
# Orden como Windows 11: … Vídeos, Papelera, Este equipo (y la red en su grupo, tras una línea)
items = list(root)
trash = next((b for b in items if b.tag == 'bookmark' and b.get('href') == 'trash:/'), None)
comp = next((b for b in items if b.tag == 'bookmark' and b.get('href') == 'file:///'), None)
if trash is not None and comp is not None and items.index(trash) > items.index(comp):
    root.remove(trash)
    root.insert(list(root).index(comp), trash)
open(p, 'w', encoding='utf-8').write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE xbel>\n'
                                     + ET.tostring(root, encoding='unicode') + '\n')
PY

echo "   listo (se aplica al abrir el Explorador)"
