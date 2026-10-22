#!/usr/bin/env bash
# Instalación de sistema (paquete kde-win11): los temas están en /usr/share. apply.sh y theme.sh
# trabajan sobre las copias del usuario (las modifican con el color de énfasis, la barra de título
# opaca, etc.), así que aquí se crean las que falten. Con install.sh ya existen y no se toca nada.
# Solo lectura -> enlace; lo que los scripts modifican -> copia.
set -euo pipefail
link() { [ -e "$2" ] || [ ! -e "$1" ] || { mkdir -p "$(dirname "$2")"; ln -s "$1" "$2"; }; }
copy() { [ -e "$2" ] || [ ! -e "$1" ] || { mkdir -p "$(dirname "$2")"; cp -r "$1" "$2"; }; }
for v in light dark; do
  copy /usr/share/plasma/desktoptheme/Win11OS-$v ~/.local/share/plasma/desktoptheme/Win11OS-$v
  copy /usr/share/Kvantum/Win11OS-$v ~/.config/Kvantum/Win11OS-$v
  link /usr/share/aurorae/themes/Win11OS-$v ~/.local/share/aurorae/themes/Win11OS-$v
  link /usr/share/wallpapers/Win11OS-$v ~/.local/share/wallpapers/Win11OS-$v
done
for t in /usr/share/themes/Fluent-round*; do
  [ -d "$t" ] && link "$t" ~/.themes/"$(basename "$t")"
done
true
