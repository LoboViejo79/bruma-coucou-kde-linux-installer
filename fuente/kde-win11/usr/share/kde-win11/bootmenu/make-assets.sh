#!/usr/bin/env bash
# Genera los recursos del menú de arranque estilo Windows (ya están generados en el repositorio;
# solo hace falta volver a ejecutarlo tras cambiar un ícono de src/ o el color de fondo).
#   grub/win11/   tema de GRUB: fuentes Selawik (.pf2), íconos por clase y resaltado de la selección
#   limine/       fondo de Limine
# Necesita: grub (grub-mkfont), librsvg (rsvg-convert), imagemagick y la fuente Selawik.
set -euo pipefail
cd "$(dirname "$0")"
BLUE="#0a58ab"          # el mismo azul en theme.txt, win11-bootmenu e iso-bootmenu.py
SEL=${SELAWIK:-$(dirname "$(fc-match -f '%{file}' 'Selawik')")}
[ -f "$SEL/selawk.ttf" ] || { echo "no encuentro Selawik (SELAWIK=carpeta-con-los-ttf)"; exit 1; }

G=grub/win11
rm -rf "$G/icons"; mkdir -p "$G/icons" limine
rm -f "$G"/*.pf2 "$G"/select_*.png "$G"/scroll_*.png

# Fuentes: título (Light), opciones (Regular) y textos de ayuda (Regular pequeña)
RANGES=0x20-0x7e,0xa0-0x17f,0x2013-0x2026
grub-mkfont -n "Selawik Light" -s 40 -r $RANGES -o "$G/selawik-light-40.pf2" "$SEL/selawkl.ttf"
grub-mkfont -n "Selawik" -s 24 -r $RANGES -o "$G/selawik-24.pf2" "$SEL/selawk.ttf"
grub-mkfont -n "Selawik" -s 18 -r $RANGES -o "$G/selawik-18.pf2" "$SEL/selawk.ttf"

# Íconos (GRUB elige el de la primera clase de cada entrada que tenga archivo)
icon() { # svg clase...
  local src=$1; shift
  for c in "$@"; do rsvg-convert -w 40 -h 40 "src/$src.svg" -o "$G/icons/$c.png"; magick "$G/icons/$c.png" "PNG32:$G/icons/$c.png"; done
}
icon windows windows
icon linux linux gnu-linux gnu os
icon memtest memtest memtest86
icon efi efi uefi-firmware
icon shutdown shutdown poweroff
icon restart restart reboot
icon options options submenu
# Logo de CachyOS en blanco
rsvg-convert -w 40 -h 40 src/cachyos.svg -o "$G/icons/cachyos.png"
magick "$G/icons/cachyos.png" -alpha extract -background white -alpha shape "PNG32:$G/icons/cachyos.png"
cp "$G/icons/cachyos.png" "$G/icons/arch.png"

# Resaltado de la opción elegida: rectángulo blanco translúcido con esquinas de 4 px, en 9 piezas
T=$(mktemp -d)
magick -size 12x12 xc:none -fill "rgba(255,255,255,0.20)" -draw "roundrectangle 0,0 11,11 4,4" "PNG32:$T/s.png"
crop() { magick "$T/s.png" -crop "$2" +repage "PNG32:$G/select_$1.png"; }
crop nw 4x4+0+0; crop n 4x4+4+0; crop ne 4x4+8+0
crop w 4x4+0+4;  crop c 4x4+4+4; crop e 4x4+8+4
crop sw 4x4+0+8; crop s 4x4+4+8; crop se 4x4+8+8
# Barra de desplazamiento fina
magick -size 4x4 xc:"rgba(255,255,255,0.55)" "PNG32:$G/scroll_thumb_c.png"
for p in n s; do magick -size 4x2 xc:"rgba(255,255,255,0.55)" "PNG32:$G/scroll_thumb_$p.png"; done
magick -size 4x4 xc:"rgba(255,255,255,0.12)" "PNG32:$G/scroll_frame_c.png"
for p in n s; do magick -size 4x2 xc:"rgba(255,255,255,0.12)" "PNG32:$G/scroll_frame_$p.png"; done
rm -rf "$T"

# Limine: fondo azul liso (el menú lo dibuja Limine encima, en blanco)
magick -size 1920x1080 xc:"$BLUE" -depth 8 "PNG24:limine/win11-limine.png"
echo "recursos generados"
