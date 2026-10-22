#!/usr/bin/env bash
# Aplica el aspecto de Windows 11 a las cuentas DURANTE la instalación (lo ejecuta el instalador de la
# ISO en el sistema nuevo, como root). Así el primer inicio de sesión ya es Windows 11, sin esperar a
# que win11-firstrun cambie Plasma en marcha.
#   - todo lo que apply.sh escribe en archivos (tema, colores, iconos, fuentes, ventanas, atajos,
#     Explorador, GTK…), sin D-Bus (WIN11_OFFLINE=1)
#   - la barra y el fondo: tema global "Windows 11" (org.kde.win11.desktop), cuyo diseño crea Plasma
#     al iniciar por primera vez. Se borra el diseño de CachyOS que copia /etc/skel.
# Uso: install-user.sh [usuario...]   (sin argumentos: todas las cuentas normales, UID 1000-59999)
set -uo pipefail
K=/usr/share/kde-win11
users=("$@")
[ ${#users[@]} -gt 0 ] || mapfile -t users < <(awk -F: '$3>=1000 && $3<60000 && $7!~/nologin|false/ {print $1}' /etc/passwd)
[ ${#users[@]} -gt 0 ] || { echo "install-user: no hay cuentas de usuario"; exit 0; }

rc=0
for u in "${users[@]}"; do
  home=$(getent passwd "$u" | cut -d: -f6)
  [ -d "$home" ] || { echo "install-user: $u sin carpeta personal"; continue; }
  echo "==> Windows 11 para $u"
  rm -f "$home/.config/plasma-org.kde.plasma.desktop-appletsrc" "$home/.config/plasmashellrc"
  runuser -u "$u" -- env -i HOME="$home" USER="$u" LOGNAME="$u" PATH=/usr/local/bin:/usr/bin \
      LANG="${LANG:-C.UTF-8}" QT_QPA_PLATFORM=offscreen WIN11_OFFLINE=1 \
      dbus-run-session --config-file="$K/scripts/install-user-dbus.conf" -- bash "$K/scripts/install-user-session.sh" || { echo "install-user: falló para $u"; rc=1; }
done
sleep 3   # theme.sh termina de guardar el factor de animación en segundo plano
exit $rc
