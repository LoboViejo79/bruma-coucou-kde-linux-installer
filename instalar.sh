#!/usr/bin/env bash
# Instalar Bruma Coucou: instala el diseño de Coucou en un CachyOS con KDE Plasma 6: paquetes, temas,
# iconos, ajustes, apps, inicio de sesión y arranque.
#
#   ./instalar.sh                                   abre la ventana para elegir
#   ./instalar.sh --diseno coucou [--modo claro|oscuro] [--acento '#RRGGBB']
#                 [--apps juegos,windows,tienda,vscode,discord,spotify,anydesk,vlc]
#                 [--rendimiento ananicy,oomd,psd] [--sin-login] [--sin-arranque] [--sin-voz]
#   ./instalar.sh --actualizar                      ya instalado: solo lo nuevo (sin tocar tu diseño)
#   ./instalar.sh --reinstalar --diseno …           ya instalado: hacer todo de nuevo, limpio
#   sudo ./instalar.sh [...] [--usuario NOMBRE]     como superusuario: no pide ninguna contraseña
#
# Si Coucou ya está instalado, no se instala todo de nuevo: se actualizan solo los paquetes más
# nuevos que trae esta carpeta (nunca se baja de versión) y se reinicia la barra. Tu diseño, fondo,
# colores, apps, inicio de sesión y arranque quedan como estaban. Para hacer todo de nuevo:
# --reinstalar (o "Reinstalar todo" en la ventana): reinstala limpio, apartando antes (con copia de
# respaldo) lo que quedó de instalaciones viejas: archivos de Coucou que ya no son de ningún paquete,
# sus ajustes viejos en tu cuenta, accesos y servicios que apuntan a cosas que ya no existen.
#
# Con tu usuario pide la contraseña de administrador una sola vez (si se escribe mal, lo dice y la
# vuelve a pedir). Antes de cambiar nada guarda una copia de la configuración en
# ~/.local/share/coucou-instalador. Todo lo que pasa queda en coucou-instalador.log, en esta misma
# carpeta (si no se puede escribir en ella, en la carpeta personal).
set -uo pipefail
DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# Abierto desde la ventana: lo que ella apagó para sí (libcoucou-ventana) no sigue a lo demás
[ -n "${COUCOU_VENTANA_CACHE:-}" ] && unset QML_DISABLE_DISK_CACHE COUCOU_VENTANA_CACHE
unset COUCOU_VENTANA
if [ -n "${LD_PRELOAD:-}" ]; then
  LD_PRELOAD=$(tr ': ' '\n\n' <<<"$LD_PRELOAD" | grep -v 'libcoucou-ventana' | paste -sd: -)
  [ -n "$LD_PRELOAD" ] && export LD_PRELOAD || unset LD_PRELOAD
fi

# ¿Está completa la carpeta? (un zip a medio bajar o a medio extraer, algo borrado sin querer).
# Se revisa antes de nada: si falta algo se dice qué, también con doble clic (sin terminal).
# La ventana del instalador busca instalar.sh, estado.sh, apps-instaladas.sh, VERSION e imagenes/
# aquí mismo, junto a esta carpeta: no se pueden mover a otra.
carpeta_incompleta() {
  local f p falta=() roto=()
  for f in VERSION estado.sh apps-instaladas.sh paso-sistema.sh paso-cuenta.sh copia.sh desinstalar.sh flatpaks.txt \
           bin/coucou-instalador perfil/coucou/settings.json imagenes/mochi.png; do
    [ -e "$DIR/$f" ] || falta+=("$f")
  done
  for p in coucou-claro kde-win11; do
    compgen -G "$DIR/paquetes/$p-[0-9]*.pkg.tar.zst" >/dev/null || falta+=("paquetes/$p-….pkg.tar.zst")
  done
  # Un paquete que pacman no puede leer: bajado o copiado a medias
  for p in "$DIR"/paquetes/*.pkg.tar.zst; do
    [ -f "$p" ] && ! pacman -Qp "$p" >/dev/null 2>&1 && roto+=("paquetes/$(basename "$p")")
  done
  [ ${#falta[@]} = 0 ] && [ ${#roto[@]} = 0 ] && return 1
  local msg="La carpeta del instalador está incompleta o dañada. Vuelve a bajar el instalador y extráelo de nuevo."
  [ ${#falta[@]} -gt 0 ] && msg+=$'\n\nFalta: '"${falta[*]}"
  [ ${#roto[@]} -gt 0 ] && msg+=$'\n\nDañado: '"${roto[*]}"
  echo "$msg" >&2
  [ -t 2 ] || { [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v kdialog >/dev/null && kdialog --title "Instalar Bruma Coucou" --error "$msg"; }
  return 0
}
carpeta_incompleta && exit 1
# Al extraer el zip con algunos programas se pierde el permiso de ejecutar: se devuelve
for f in "$DIR"/bin/coucou-instalador "$DIR"/*.sh; do [ -x "$f" ] || chmod +x "$f" 2>/dev/null; done

uso() { sed -n '5,11p' "$0" | sed 's/^#  //'; }
ACTUALIZAR=0; REINSTALAR=0
DISENO=""; MODO=claro; LOGIN=1; ARRANQUE=1; U=""; ACENTO=""; APPS=""; REND=""; VOZ=1
# Las opciones con valor lo necesitan (sin él, "shift 2" no avanza y se quedaba dando vueltas)
valor() { [ -n "${2:-}" ] && [ "${2#--}" = "$2" ] || { echo "Falta el valor de $1" >&2; uso >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --diseno|--modo|--usuario|--acento|--apps|--rendimiento) valor "$1" "${2:-}" ;;
  esac
  case "$1" in
    --diseno) DISENO=${2:-}; shift 2 ;;
    --modo) MODO=${2:-}; shift 2 ;;
    --sin-login) LOGIN=0; shift ;;
    --sin-arranque) ARRANQUE=0; shift ;;
    --sin-voz) VOZ=0; shift ;;
    --actualizar) ACTUALIZAR=1; shift ;;
    --reinstalar) REINSTALAR=1; shift ;;
    --usuario) U=${2:-}; shift 2 ;;
    --acento) ACENTO=${2:-}; shift 2 ;;
    --apps) APPS=${2:-}; shift 2 ;;
    --rendimiento) REND=${2:-}; shift 2 ;;
    -h|--help) uso; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; uso >&2; exit 2 ;;
  esac
done
# Solo existe el diseño de Coucou (los de Windows 11 y CachyOS se quitaron). Se revisa antes de
# todo: si no, con Coucou ya instalado un --diseno viejo pasaba callado a "actualizar"
case "$DISENO" in ''|coucou) ;; windows|cachyos|ambos) echo "El diseño $DISENO ya no existe: solo está el de Coucou (--diseno coucou)" >&2; exit 2 ;; *) echo "Diseño: coucou" >&2; exit 2 ;; esac

# ¿Para qué cuenta? Con tu usuario, la tuya. Como superusuario (sudo, pkexec o root), la que lo
# llamó o la de --usuario; y como sudo quita las variables de la sesión gráfica, se toman las de su
# escritorio (plasmashell) para poder hablar con Plasma y abrir la barra de Coucou en su pantalla.
SUPER=0
if [ "$(id -u)" = 0 ]; then
  SUPER=1
  [ -n "$U" ] || U=${SUDO_USER:-}
  [ -n "$U" ] || { [ -n "${PKEXEC_UID:-}" ] && U=$(id -nu "$PKEXEC_UID" 2>/dev/null); }
  [ -n "$U" ] || U=$(logname 2>/dev/null)
  if [ -z "$U" ] || [ "$U" = root ] || ! id "$U" >/dev/null 2>&1; then
    echo "Como superusuario hay que decir para qué cuenta es: sudo ./instalar.sh --usuario NOMBRE" >&2; exit 2
  fi
  UHOME=$(getent passwd "$U" | cut -d: -f6)
  SESION=()   # todo el entorno de su escritorio, para lo que se corre como esa cuenta
  pid=$(pgrep -u "$U" -x plasmashell | head -1)
  if [ -n "$pid" ]; then
    mapfile -d '' SESION < "/proc/$pid/environ"
    for v in DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY XAUTHORITY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP LANG; do
      val=$(printf '%s\n' "${SESION[@]}" | sed -n "s/^$v=//p" | head -1)
      [ -n "$val" ] && export "$v=$val"
    done
  fi
else
  [ -z "$U" ] || [ "$U" = "$USER" ] || { echo "--usuario solo sirve como superusuario (sudo)" >&2; exit 2; }
  U=$USER; UHOME=$HOME
fi
# ¿Hay escritorio donde mostrar Coucou? (la sesión del usuario o la de esta terminal)
hay_pantalla() {
  [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && return 0
  declare -p SESION >/dev/null 2>&1 && [ "${#SESION[@]}" -gt 0 ] && printf '%s\n' "${SESION[@]}" | grep -qE '^(DISPLAY|WAYLAND_DISPLAY)=.+'
}

# Corre algo como la cuenta, dentro de su sesión
como_usuario() {
  if [ $SUPER = 1 ]; then
    if [ ${#SESION[@]} -gt 0 ]; then runuser -u "$U" -- env -i "${SESION[@]}" "$@"
    else runuser -u "$U" -- env HOME="$UHOME" USER="$U" "$@"; fi
  else "$@"; fi
}

# Reinstalar: siempre limpio (lo viejo apartado antes de instalar de nuevo)
LIMPIO=0
# ¿Ya está instalado? Entonces se actualiza (salvo que se pida reinstalar con un diseño)
YA_INSTALADO=0
# (en una variable: con pipefail, un "| grep -q" corta la salida y daba "no instalado")
ESTADO=$(bash "$DIR/estado.sh" "$DIR" 2>/dev/null)
grep -qx 'instalado=1' <<<"$ESTADO" && YA_INSTALADO=1
if [ $ACTUALIZAR = 1 ] && [ -n "$DISENO" ]; then echo "--actualizar no lleva --diseno (para elegir otro: --reinstalar)" >&2; exit 2; fi
if [ $YA_INSTALADO = 1 ] && [ -n "$DISENO" ] && [ $REINSTALAR = 0 ]; then
  echo "Coucou ya está instalado: se actualiza sin tocar tu diseño. Para hacer todo de nuevo con ese diseño: --reinstalar" >&2
  DISENO=""; ACTUALIZAR=1
fi

# Sin opciones: la ventana (si hay escritorio). Como superusuario también: así no pide contraseña.
if [ -z "$DISENO" ] && [ $ACTUALIZAR = 0 ]; then
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ -x "$DIR/bin/coucou-instalador" ]; then
    log="$DIR/coucou-instalador.log"; touch "$log" 2>/dev/null || log="$UHOME/coucou-instalador.log"
    [ $SUPER = 1 ] && [ -e "$log" ] && chown "$U": "$log"
    export COUCOU_INSTALADOR_USUARIO="$U" COUCOU_INSTALADOR_LOG="$log"
    # Sus pantallas de fuente/ventana (con las copias de seguridad): la biblioteca va por
    # LD_PRELOAD, que corta en los espacios ("Bruma Coucou"), así que se usa una copia en /tmp
    if [ -f "$DIR/bin/ventana.rcc" ] && [ -f "$DIR/bin/libcoucou-ventana.so" ] && [ -f "$DIR/bin/libcoucou-ventana-qt.so" ]; then
      lib=/tmp/coucou-ventana-$(id -u)/libcoucou-ventana.so
      if mkdir -p "$(dirname "$lib")" 2>/dev/null && [ -O "$(dirname "$lib")" ] &&
         cp -f "$DIR/bin/libcoucou-ventana.so" "$DIR/bin/libcoucou-ventana-qt.so" "$(dirname "$lib")"/ 2>/dev/null; then
        export COUCOU_VENTANA="$DIR/bin/ventana.rcc" LD_PRELOAD="$lib${LD_PRELOAD:+:$LD_PRELOAD}"
      fi
    fi
    exec "$DIR/bin/coucou-instalador"
  fi
  # Sin ventana: ya instalado → se actualiza; si no, hay que decir el diseño
  if [ $YA_INSTALADO = 1 ]; then ACTUALIZAR=1; else uso; exit 2; fi
fi
[ $REINSTALAR = 1 ] && [ $YA_INSTALADO = 1 ] && LIMPIO=1
if [ $ACTUALIZAR = 1 ]; then
  [ $YA_INSTALADO = 1 ] || { echo "Coucou no está instalado en este equipo: hay que instalarlo (--diseno …)" >&2; exit 2; }
  DISENO=actualizar
fi
[ -z "$ACENTO" ] || [[ "$ACENTO" =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "Acento: un color como '#6574F6'" >&2; exit 2; }
for x in ${APPS//,/ }; do case $x in juegos|windows|tienda|vscode|discord|spotify|anydesk|vlc) ;; *) echo "App desconocida: $x" >&2; exit 2 ;; esac; done
for x in ${REND//,/ }; do case $x in ananicy|oomd|psd) ;; *) echo "Rendimiento desconocido: $x" >&2; exit 2 ;; esac; done
case "$MODO" in claro|oscuro) ;; *) echo "Modo: claro u oscuro" >&2; exit 2 ;; esac

# Registro completo de la instalación junto al instalador (y una copia del sistema en /var/log).
# Si la carpeta no se puede escribir (un USB de solo lectura…), en la carpeta personal.
LOG="$DIR/coucou-instalador.log"
touch "$LOG" 2>/dev/null || LOG="$UHOME/coucou-instalador.log"
touch "$LOG" && [ $SUPER = 1 ] && chown "$U": "$LOG"
# Y una copia en la cuenta que no se pierde al borrar la carpeta del instalador: la lee
# Configuración › Actualizaciones › Registro de errores
COPIA="$UHOME/.local/share/coucou-instalador/instalador.log"
mkdir -p "$(dirname "$COPIA")" 2>/dev/null && touch "$COPIA" 2>/dev/null || COPIA=/dev/null
[ $SUPER = 1 ] && [ "$COPIA" != /dev/null ] && chown "$U": "$(dirname "$COPIA")" "$COPIA"
exec > >(tee -a "$LOG" "$COPIA") 2>&1
echo "===== Instalar Coucou v$(cat "$DIR/VERSION" 2>/dev/null || echo '?'): $(date '+%Y-%m-%d %H:%M:%S')$([ $LIMPIO = 1 ] && echo ' · reinstalación limpia') · diseño=$DISENO modo=$MODO acento=${ACENTO:--} login=$LOGIN arranque=$ARRANQUE apps=${APPS:--} rendimiento=${REND:--} voz=$VOZ"
echo "      equipo: $(uname -n) · $(grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2) · usuario: $U$([ $SUPER = 1 ] && echo " (como superusuario)")"
paso() { echo "@@ $1 $2"; }
falla() { echo "@@ $1" ; echo "ERROR: $1" >&2; exit 1; }

command -v pacman >/dev/null || falla "Este instalador es para CachyOS o Arch Linux."
command -v plasmashell >/dev/null || falla "Hace falta CachyOS con el escritorio KDE Plasma (el que viene por defecto). Este equipo no lo tiene instalado."
ls "$DIR"/paquetes/*.pkg.tar.zst >/dev/null 2>&1 || falla "Falta la carpeta paquetes junto a instalar.sh."

if [ "$DISENO" = actualizar ]; then
  EST=$(bash "$DIR/estado.sh" "$DIR")
  antes=$(sed -n 's/^version_instalada=//p' <<<"$EST")
  [ "$antes" = "?" ] && antes="un instalador anterior" || antes="la versión $antes"
  echo "Coucou ya está instalado (con $antes). Este instalador es la versión $(sed -n 's/^version_instalador=//p' <<<"$EST")."
  sed -n 's/^cambio=/  · /p' <<<"$EST"
  # Nada más nuevo: ni contraseña hace falta
  if [ "$(sed -n 's/^nuevos=//p' <<<"$EST")" = 0 ]; then
    echo "Todo lo de este instalador ya está instalado (o tienes algo más nuevo): no se cambia nada."
    paso 100 "Coucou ya está al día"
    exit 0
  fi
fi

paso 3 "Revisando la conexión a internet"
curl -sfI -m 15 https://cachyos.org >/dev/null ||
  echo "!! No se pudo comprobar la conexión con cachyos.org: se sigue igual (si falta internet, la instalación de paquetes lo va a decir)"

# Minutos que faltan para que se destrabe la cuenta (pam_faillock: tras varios intentos con la
# contraseña equivocada la bloquea un rato y rechaza hasta la correcta). 0 = no está bloqueada.
bloqueo() {
  faillock --user "$U" 2>/dev/null | python3 -c '
import sys, re, time, datetime
conf = {"deny": 3, "fail_interval": 900, "unlock_time": 600}
try:
    for l in open("/etc/security/faillock.conf"):
        m = re.match(r"\s*(deny|fail_interval|unlock_time)\s*=\s*(\d+)", l)
        if m: conf[m.group(1)] = int(m.group(2))
except OSError: pass
ahora = time.time()
fallos = []
for l in sys.stdin:
    m = re.match(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\s.*\sV\s*$", l)
    if m: fallos.append(datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S").timestamp())
recientes = [t for t in fallos if ahora - t <= conf["fail_interval"]]
if conf["deny"] and len(recientes) >= conf["deny"] and conf["unlock_time"]:
    falta = max(recientes) + conf["unlock_time"] - ahora
    print(max(0, int(falta // 60) + (1 if falta % 60 else 0)))
else:
    print(0)'
}

# Una sola contraseña: la parte de administrador también aplica el diseño a esta cuenta, con las
# variables de la sesión (D-Bus, pantalla) para hablar con Plasma. paso-sistema.sh dice
# "@@ AUTORIZADO" en cuanto arranca: así se sabe si la contraseña se aceptó, y no se vuelve a pedir.
# (No sirve que root escriba un archivo en /tmp: fs.protected_regular se lo impide si es de otro usuario.)
MARCA=$(mktemp); trap 'rm -f "$MARCA"' EXIT
intento=0
if [ $SUPER = 1 ]; then
  paso 6 "Como superusuario: no hace falta contraseña"
  env COUCOU_USUARIO="$U" LANG="${LANG:-}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-KDE}" XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}" \
    bash "$DIR/paso-sistema.sh" "$DIR" "$DISENO" "$MODO" "$LOGIN" "$ARRANQUE" "$ACENTO" "$APPS" "$REND" "$VOZ" "$LIMPIO" 2>&1 | grep -vx '@@ AUTORIZADO'
  rc=${PIPESTATUS[0]}
fi
while [ $SUPER = 0 ]; do
  intento=$((intento + 1))
  m=$(bloqueo)
  if [ "${m:-0}" -gt 0 ]; then
    # Bloqueada: esperar avisando cuánto falta, y volver a pedirla sola
    while [ "${m:-0}" -gt 0 ]; do
      echo "@@ 6 Hubo varios intentos con la contraseña equivocada y por seguridad la cuenta quedó bloqueada un rato. Se vuelve a pedir sola en $m minuto$([ "$m" = 1 ] || echo s)."
      sleep 20
      m=$(bloqueo)
    done
  fi
  if [ $intento = 1 ]; then paso 6 "Escribe tu contraseña de administrador"
  else paso 6 "La contraseña no era correcta. Escríbela de nuevo (con cuidado con las mayúsculas)."; fi
  : > "$MARCA"
  pkexec env \
    COUCOU_USUARIO="$USER" LANG="${LANG:-}" \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    DISPLAY="${DISPLAY:-}" \
    XAUTHORITY="${XAUTHORITY:-}" \
    XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-KDE}" \
    XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}" \
    bash "$DIR/paso-sistema.sh" "$DIR" "$DISENO" "$MODO" "$LOGIN" "$ARRANQUE" "$ACENTO" "$APPS" "$REND" "$VOZ" "$LIMPIO" 2>&1 |
  while IFS= read -r linea; do
    if [ "$linea" = "@@ AUTORIZADO" ]; then echo ok > "$MARCA"; else printf '%s\n' "$linea"; fi
  done
  rc=${PIPESTATUS[0]}
  [ -s "$MARCA" ] && break                      # la contraseña se aceptó: rc es el de la instalación
  # Cerró la ventana porque la cuenta estaba bloqueada (rechazaba hasta la correcta): esperar
  if [ $rc = 126 ] && [ "$(bloqueo)" -gt 0 ]; then continue; fi
  if [ $rc = 126 ]; then                        # se cerró la ventana de la contraseña
    echo "@@ Hace falta la contraseña de administrador para instalar. No se cambió nada."
    exit 126
  fi
  [ $intento -lt 10 ] || { echo "@@ No se pudo comprobar la contraseña. No se cambió nada."; exit 127; }
  sleep 1                                       # equivocada (o la cuenta se bloqueó): otra vez
done
# La barra que abre el instalador la vigila coucou-launch, que toma toda caída en el primer minuto
# por un problema de la tarjeta de video y anota el "modo seguro" para todo este arranque de la PC.
# Al terminar se pide cerrar sesión: la barra pierde la pantalla, coucou-launch (suelto con setsid,
# sobrevive a la sesión) lo anotaba como caída y al volver a entrar la barra se abría en modo seguro
# nivel 2, sin DMA-BUF: en AMD/Intel se pinta a pedazos. Por eso:
#  - antes de abrirla se olvida el modo seguro viejo (la versión nueva se prueba en modo normal);
#  - cuando ya anduvo un rato se quita ese vigilante (la barra sigue abierta): la caída al cerrar
#    sesión no se anota, y al entrar de nuevo la abre el inicio de sesión como siempre.
SEGURO_DIR="$UHOME/.config/coucou"
olvidar_modo_seguro() {
  rm -f "$SEGURO_DIR/arranque-seguro" "$SEGURO_DIR/arranque-seguro.arranque" "$SEGURO_DIR"/.reintentos-* "$SEGURO_DIR"/.caidas-* "$SEGURO_DIR"/.pantalla-*
}
soltar_vigilante() {
  pgrep -u "$U" -x coucou >/dev/null || return 0
  # coucou-launch desde coucou-claro 1.0.37-42 distingue "perdió la pantalla" (cerrar sesión, cambio
  # de pantalla) de un fallo de video: ese se deja, porque si KWin corta la barra al moverla de
  # pantalla, es el que la vuelve a abrir
  grep -q 'coucou-salida' /usr/bin/coucou-launch 2>/dev/null && return 0
  pkill -u "$U" -f '^(/usr)?/bin/bash /usr/bin/coucou-launch' 2>/dev/null
  sleep 1
  # Si en ese rato se cayó, lo anotado es de verdad (la tarjeta de video): se deja
  pgrep -u "$U" -x coucou >/dev/null && olvidar_modo_seguro
  return 0
}

# Coucou: se arranca desde aquí, en la sesión del usuario (con su idioma, pantalla y D-Bus), y se
# comprueba que quedó andando. Si no, igual arranca solo al próximo inicio de sesión.
ARRANCAR="$UHOME/.config/coucou/.arrancar-instalador"
if { [ $rc = 0 ] || [ $rc = 4 ]; } && [ -f "$ARRANCAR" ]; then
  read -r barra extra < "$ARRANCAR"; rm -f "$ARRANCAR"
  paso 99 "Poniendo la barra"
  olvidar_modo_seguro
  como_usuario env COUCOU_ESTILO_SALIDA=1 /usr/lib/coucou/estilo "$barra" --solo-barra $extra
  if [ "$barra" = coucou ] || [ -n "$extra" ]; then
    for _ in $(seq 20); do pgrep -u "$U" -x coucou >/dev/null && break; sleep 1; done
    sleep 5   # que ande unos segundos (si se cae al arrancar se ve abajo; coucou-launch la reabre sola)
    if pgrep -u "$U" -x coucou >/dev/null; then echo "Coucou está andando (barra: $barra)"; soltar_vigilante
    elif ! hay_pantalla; then
      # Instalado desde una consola sin escritorio: no hay dónde mostrarlo todavía
      echo "Sin pantalla gráfica ahora: Coucou se abre solo al iniciar sesión en el escritorio"
    else
      echo "!! Coucou se cerró o no arrancó: mira las líneas de abajo"
      [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && rc=3   # con escritorio abierto tendría que estar andando
    fi
    echo "--- últimas líneas del registro de Coucou (~/.local/share/coucou/coucou.log):"
    tail -n 15 "$UHOME/.local/share/coucou/coucou.log" 2>/dev/null || echo "(Coucou todavía no escribió su registro)"
    echo "--- panel en uso: $(cat "$UHOME/.config/coucou/taskbar-style" 2>/dev/null || echo '?')"
    echo "--- arranque de Coucou según la tarjeta de video (~/.cache/coucou-launch.log):"
    tail -n 5 "$UHOME/.cache/coucou-launch.log" 2>/dev/null || echo "(sin datos)"
    lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/^/    /'
  else
    echo "Barra: $barra (Coucou no queda en pantalla; se elige en Configuración › Barra de tareas)"
  fi
fi

# Actualizado: la barra se reinicia con la versión nueva (si estaba andando)
if [ "$DISENO" = actualizar ] && [ $rc = 0 ] && pgrep -u "$U" -x coucou >/dev/null; then
  paso 99 "Reiniciando la barra"
  # (primero el lanzador viejo: si no, reabría la barra a su manera, sin lo nuevo de coucou-launch)
  pkill -u "$U" -f '^(/usr)?/bin/bash /usr/bin/coucou-launch' 2>/dev/null
  pkill -u "$U" -x coucou; sleep 1
  olvidar_modo_seguro
  como_usuario setsid coucou-launch </dev/null >/dev/null 2>&1 &
  for _ in $(seq 15); do pgrep -u "$U" -x coucou >/dev/null && break; sleep 1; done
  sleep 5    # que ande unos segundos (si se cae apenas arranca, coucou-launch pasa al modo seguro y se ve)
  if pgrep -u "$U" -x coucou >/dev/null; then echo "La barra volvió con la versión nueva"; soltar_vigilante
  else echo "!! la barra no volvió: se abre sola al iniciar sesión"; fi
fi

# El efecto de abrir ventanas (win11-open) se recarga: KWin sigue con el viejo en memoria hasta
# volver a entrar (el nuevo ya no anima la barra de Coucou al cambiar de pantalla)
if { [ $rc = 0 ] || [ $rc = 4 ]; } && hay_pantalla &&
   [ "$(como_usuario qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded win11-open 2>/dev/null)" = true ]; then
  como_usuario qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect win11-open >/dev/null 2>&1
  como_usuario qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect win11-open >/dev/null 2>&1
fi
# La barra de Coucou entre pantallas (efecto coucou-barra): sin el vidrio vacío ni el parpadeo
# mientras se rehace, y entrando desde su borde. Activado y cargado ya (o al volver a entrar).
if { [ $rc = 0 ] || [ $rc = 4 ]; } && [ -d /usr/share/kwin/effects/coucou-barra ]; then
  como_usuario kwriteconfig6 --file kwinrc --group Plugins --key coucou-barraEnabled true
  if hay_pantalla; then
    como_usuario qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect coucou-barra >/dev/null 2>&1
    como_usuario qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect coucou-barra >/dev/null 2>&1
  fi
fi

# Iconos (Papirus con carpetas violetas) y ventanas GTK (Breeze con los colores de Coucou): ya, sin
# volver a entrar. Respeta los iconos que haya elegido la persona en Configuración.
if { [ $rc = 0 ] || [ $rc = 4 ]; } && hay_pantalla; then
  [ -x /usr/lib/coucou/coucou-iconos ] && como_usuario /usr/lib/coucou/coucou-iconos apply >/dev/null 2>&1
  [ -x /usr/lib/coucou/coucou-colors ] && como_usuario /usr/lib/coucou/coucou-colors gtk >/dev/null 2>&1
  [ -x /usr/lib/coucou/control-atajo ] && como_usuario /usr/lib/coucou/control-atajo >/dev/null 2>&1
fi

# La Tienda se llama "Tienda" en el menú (antes "Tienda de aplicaciones"): también en las cuentas
# que ya tenían la entrada de Coucou, sin esperar a que se vuelvan a aplicar los colores
TIENDA="$UHOME/.local/share/applications/win11-store.desktop"
if { [ $rc = 0 ] || [ $rc = 4 ]; } && grep -qs '^X-Coucou-Override=true' "$TIENDA"; then
  como_usuario sed -i 's/^Name=Tienda de aplicaciones$/Name=Tienda/' "$TIENDA"
fi

# El mismo fondo de Coucou en todas las pantallas (las que quedaron con el de Windows 11)
if { [ $rc = 0 ] || [ $rc = 4 ]; } && [ -x /usr/lib/coucou/fondos-pantallas ] && hay_pantalla; then
  n=$(como_usuario /usr/lib/coucou/fondos-pantallas 2>/dev/null | tail -1)
  [ "${n:-0}" -gt 0 ] 2>/dev/null && echo "Fondo de Coucou puesto en $n pantalla$([ "$n" = 1 ] || echo s) más"
fi

case $rc in
  0) echo "Registro de la instalación: $LOG"
     [ "$DISENO" = actualizar ] && { paso 100 "Coucou se actualizó"; exit 0; }
     # El inicio de sesión de Coucou es de SDDM, que queda activado para el próximo arranque: el
     # login que está corriendo (Plasma Login Manager) sigue hasta reiniciar. Cerrando sesión se
     # volvía a ver el de Plasma, no el de Coucou: en ese caso hay que reiniciar.
     if [ "$LOGIN" = 1 ] && systemctl is-enabled -q sddm.service 2>/dev/null && ! systemctl is-active -q sddm.service; then
       paso 100 "Listo. Reinicia el equipo para ver el diseño completo y el inicio de sesión de Coucou."
     else
       paso 100 "Listo. Cierra sesión y vuelve a entrar para ver el diseño completo."
     fi ;;
  3) echo "@@ Se instaló todo, pero la barra de Coucou no quedó andando. El detalle está en $LOG"; exit 3 ;;
  4) echo "@@ Se instaló todo, pero algunos pasos del diseño fallaron. El detalle está en $LOG"; exit 4 ;;
  *) echo "@@ Algo salió mal. El detalle está en $LOG"; exit $rc ;;
esac
