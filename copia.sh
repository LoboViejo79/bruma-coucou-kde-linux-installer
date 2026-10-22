#!/usr/bin/env bash
# Instalar Bruma Coucou: las copias de seguridad y el historial de lo que se hizo en este equipo.
#   copia.sh original <usuario>          (root) la copia de cómo estaba la PC ANTES de Coucou. Se hace
#                                        una sola vez, la primera vez que se instala, y nunca se pisa ni
#                                        se borra. Si Coucou ya estaba instalado (con un instalador viejo,
#                                        sin esta copia) se arma con las copias más viejas que haya.
#   copia.sh cuenta <home> <destino>     copia de los ajustes de una cuenta (lo que el diseño cambia)
#   copia.sh anotar <tipo> <versión> <usuario>   (root) una línea más en el historial
#   copia.sh podar <carpeta>             de las copias respaldo-* de esa carpeta deja las 10 más nuevas
#                                        (la original está aparte y no se toca nunca)
#   copia.sh ver [usuario]               primera instalación, historial y copias (no cambia nada)
# La usan instalar.sh (por paso-sistema.sh y paso-cuenta.sh) y desinstalar.sh.
set -uo pipefail
SIS=/var/lib/coucou-instalador
ORIG=$SIS/original
HIST=$SIS/historial
GUARDAR=10

# Lo que el diseño cambia en la cuenta: de ~/.config ...
CONFIG=(kdeglobals kwinrc plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc kcminputrc ksplashrc
        kscreenlockerrc kglobalshortcutsrc dolphinrc konsolerc mimeapps.list gtk-3.0 gtk-4.0 Kvantum coucou win11rc
        autostart kwinrulesrc breezerc xsettingsd coucouiconosrc win11 win11-kde win11-firstrun-done win11-seeded xfce4)
# ... y de ~/.local/share
LOCAL=(plasma applications kxmlgui5 color-schemes aurorae icons wallpapers)

cuenta() { # $1 = carpeta personal, $2 = destino
  local H=$1 R=$2 f
  mkdir -p "$R/local-share" || return 1
  (cd "$H/.config" 2>/dev/null && cp -a "${CONFIG[@]}" "$R"/ 2>/dev/null)
  (cd "$H/.local/share" 2>/dev/null && cp -a "${LOCAL[@]}" "$R/local-share"/ 2>/dev/null)
  [ -f "$H/.local/bin/dolphin" ] && { mkdir -p "$R/local-bin"; cp -a "$H/.local/bin/dolphin" "$R/local-bin/"; }
  # Qué había en ~/.config: al volver a como estaba, lo de la lista que no estaba se quita
  for f in "${CONFIG[@]}"; do [ -e "$H/.config/$f" ] && echo "$f"; done > "$R/.habia"
  echo "Copia de tu configuración: $R"
}

# Archivos del sistema que cambia la instalación (inicio de sesión, arranque, cuentas nuevas)
SISTEMA=(/etc/sddm.conf /etc/sddm.conf.d /etc/mkinitcpio.conf /etc/plymouth/plymouthd.conf /etc/default/limine
         /etc/default/grub /etc/sdboot-manage.conf /boot/limine.conf /boot/efi/limine.conf /efi/limine.conf
         /boot/refind_linux.conf /boot/loader/entries /efi/loader/entries /etc/skel)

# El gestor de inicio de sesión que está activado (plasmalogin, sddm…)
gestor() { basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null; }

original() { # $1 = usuario
  local U=$1 UHOME d f
  [ -f "$ORIG/info" ] && return 0
  UHOME=$(getent passwd "$U" | cut -d: -f6)
  rm -rf "$ORIG"; mkdir -p "$ORIG/sistema" "$ORIG/cuenta"; chmod 700 "$ORIG/cuenta"
  if pacman -Q coucou-claro >/dev/null 2>&1 || [ -f "$SIS/instalado" ]; then
    sembrar "$U" "$UHOME"; return
  fi
  for f in "${SISTEMA[@]}"; do
    [ -e "$f" ] && { mkdir -p "$ORIG/sistema$(dirname "$f")"; cp -a "$f" "$ORIG/sistema$f"; }
  done
  pacman -Qq > "$ORIG/paquetes.txt"
  pacman -Qqe > "$ORIG/explicitos.txt"
  systemctl list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$ORIG/servicios.txt"
  systemctl --global list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$ORIG/servicios-cuenta.txt"
  flatpak list --app --columns=application 2>/dev/null | sort -u > "$ORIG/flatpaks.txt"
  gestor > "$ORIG/gestor-de-inicio.txt"
  cuenta "$UHOME" "$ORIG/cuenta/$U" >/dev/null
  printf 'fecha=%s\nusuario=%s\ncomo=antes\n' "$(date '+%Y-%m-%d %H:%M')" "$U" > "$ORIG/info"
  echo "Copia de cómo estaba la PC antes de Coucou: $ORIG (se guarda para siempre)"
}

# Coucou ya estaba instalado y no había copia original: se arma con lo más viejo que hay. La lista de
# paquetes de antes sale de /var/log/pacman.log (lo instalado y quitado hasta la primera instalación).
sembrar() { # $1 = usuario, $2 = carpeta personal
  local U=$1 UHOME=$2 t0 s c
  t0=$(grep -m1 -E '\[ALPM\] (installed|instalado) coucou-claro' /var/log/pacman.log 2>/dev/null | sed -E 's/^\[([^]]+)\].*/\1/')
  if [ -n "$t0" ]; then
    python3 - "$t0" > "$ORIG/paquetes.txt" <<'PY'
import re, sys
t0, hay = sys.argv[1], set()
for l in open("/var/log/pacman.log", errors="replace"):
    m = re.match(r"\[([^]]+)\] \[ALPM\] (installed|instalado|removed|eliminado) (\S+)", l)
    if not m: continue
    if m.group(1) >= t0: break
    (hay.add if m.group(2) in ("installed", "instalado") else hay.discard)(m.group(3))
print("\n".join(sorted(hay)))
PY
  fi
  # Lo de sistema y de la cuenta: de las copias más viejas (las de la primera instalación)
  s=$(ls -d "$SIS"/respaldo-* 2>/dev/null | sort | head -1)
  [ -n "$s" ] && cp -a "$s"/. "$ORIG/sistema"/
  # (en esa copia el inicio de sesión ya tenía lo de Coucou: eso no era de antes)
  find "$ORIG/sistema/etc/sddm.conf.d" -maxdepth 1 \( -iname '*coucou*' -o -iname '*win11*' \) -delete 2>/dev/null
  c=$(ls -d "$UHOME"/.local/share/coucou-instalador/respaldo-* 2>/dev/null | sort | head -1)
  if [ -n "$c" ]; then
    cp -a "$c" "$ORIG/cuenta/$U"
    ls -A "$c" | grep -vx -e local-share -e local-bin -e .habia > "$ORIG/cuenta/$U/.habia"
  fi
  # El de antes era el de CachyOS con Plasma (el instalador lo cambia por SDDM)
  if grep -qx plasma-login-manager "$ORIG/paquetes.txt" 2>/dev/null || systemctl cat plasmalogin.service >/dev/null 2>&1; then
    echo plasmalogin.service > "$ORIG/gestor-de-inicio.txt"
  fi
  printf 'fecha=%s\nusuario=%s\ncomo=reconstruida\n' "$(sed -E 's/T([0-9:]{5}).*/ \1/' <<<"${t0:-?}")" "$U" > "$ORIG/info"
  echo "Copia de cómo estaba la PC antes de Coucou, armada con las copias de la primera instalación: $ORIG"
}

# El historial: se arma la primera vez con los registros que haya (las instalaciones y
# actualizaciones que llegaron al final; las que no cambiaron nada no cuentan)
historial_viejo() { # $1 = carpeta personal
  python3 - "$1"/.local/share/coucou-instalador/*.log /var/log/coucou-instalador.log <<'PY' 2>/dev/null
import re, sys
vistas = {}
for p in sys.argv[1:]:
    try: texto = open(p, errors="replace").read()
    except OSError: continue
    for b in re.split(r"(?m)^(?====== Instalar Coucou )", texto):
        m = re.match(r"===== Instalar Coucou v(\S+): (\d{4}-\d\d-\d\d \d\d:\d\d):\d\d( · reinstalación limpia)? · diseño=(\S+)", b)
        if not m: continue
        v, fecha, limpia, diseno = m.groups()
        if diseno == "actualizar":
            if "@@ 100 Coucou se actualizó" not in b: continue
            tipo = "actualización"
        else:
            if "@@ 100 Listo" not in b: continue
            tipo = "reinstalación" if limpia else "instalación"
        u = re.search(r"usuario: (\S+)", b)
        vistas[fecha] = f"{fecha} · {tipo} · versión {v} · {u.group(1) if u else '?'}"
for k in sorted(vistas): print(vistas[k])
PY
}

anotar() { # $1 = tipo, $2 = versión, $3 = usuario
  mkdir -p "$SIS"
  if [ ! -s "$HIST" ]; then
    historial_viejo "$(getent passwd "$3" | cut -d: -f6)" > "$HIST"
  fi
  echo "$(date '+%Y-%m-%d %H:%M') · $1 · versión $2 · $3" >> "$HIST"
}

podar() { # $1 = carpeta con respaldo-*
  local d
  ls -d "$1"/respaldo-* 2>/dev/null | sort -r | tail -n +$((GUARDAR + 1)) | while read -r d; do rm -rf "$d"; done
}

ver() { # $1 = usuario
  local U=${1:-$(id -un)} UHOME primera
  UHOME=$(getent passwd "$U" | cut -d: -f6)
  echo "COUCOU EN ESTE EQUIPO"
  if pacman -Q coucou-claro >/dev/null 2>&1; then echo "  Instalado: sí ($(pacman -Q coucou-claro kde-win11 2>/dev/null | paste -sd' '))"
  else echo "  Instalado: no"; fi
  primera=$(grep -m1 -E '· (instalación|reinstalación) ·' "$HIST" 2>/dev/null)
  [ -n "$primera" ] || primera=$(historial_viejo "$UHOME" | head -1)
  echo "  Primera instalación: ${primera:-(no se sabe)}"
  if [ -f "$ORIG/info" ]; then
    echo "  Copia de cómo estaba antes de Coucou: $ORIG"
    echo "    del $(sed -n 's/^fecha=//p' "$ORIG/info")$([ "$(sed -n 's/^como=//p' "$ORIG/info")" = reconstruida ] && echo ' (armada con las copias de la primera instalación)')"
  else
    echo "  Copia de cómo estaba antes de Coucou: todavía no (se hace al instalar o actualizar)"
  fi
  echo
  echo "HISTORIAL (lo más nuevo arriba)"
  if [ -s "$HIST" ]; then tac "$HIST"; else historial_viejo "$UHOME" | tac; fi | sed 's/^/  /'
  echo
  echo "COPIAS DE CADA INSTALACIÓN Y ACTUALIZACIÓN (las $GUARDAR más nuevas)"
  ls -d "$UHOME"/.local/share/coucou-instalador/respaldo-* 2>/dev/null | sort -r | sed 's/^/  cuenta:  /'
  ls -d "$SIS"/respaldo-* "$SIS"/desinstalado-* 2>/dev/null | sort -r | sed 's/^/  sistema: /'
  echo
  echo "Para dejar la PC como estaba antes de Coucou: desinstalar.sh (o \"Desinstalar Bruma Coucou\")"
}

case "${1:-}" in
  original) original "${2:?usuario}" ;;
  cuenta) cuenta "${2:?carpeta personal}" "${3:?destino}" ;;
  anotar) anotar "${2:?tipo}" "${3:?versión}" "${4:?usuario}" ;;
  podar) podar "${2:?carpeta}" ;;
  ver) ver "${2:-}" ;;
  lista) printf '%s\n' "${CONFIG[@]}" ;;   # (para desinstalar.sh: lo de ~/.config que vuelve a como estaba)
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
