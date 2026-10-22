#!/usr/bin/env bash
# Coucou: el esqueleto de un widget nuevo (escritorio de Plasma) en fuente/coucou-claro.
#
#   fuente/nuevo-widget.sh <id> "<Nombre>" "<Descripción>" <icono> <categoría> [opciones…]
#
# Cada opción es "nombre Tipo valor-por-defecto" (Tipo: String, Int, Double, Bool). Siempre
# lleva "estilo" (el color, ver org.coucou.widgets/Paletas.qml). Crea metadata.json,
# contents/config/{main.xml,config.qml}; el main.qml y el ConfigGeneral.qml se escriben a mano
# (sirven de ejemplo los de cualquier org.coucou.* que ya esté). Si el widget ya existe, solo
# rehace su main.xml con las opciones dadas.
set -euo pipefail
[ $# -ge 5 ] || { sed -n '4,11p' "$0"; exit 2; }
F=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
id=$1; nombre=$2; desc=$3; icono=$4; cat=$5; shift 5
d="$F/coucou-claro/usr/share/plasma/plasmoids/org.coucou.$id"
mkdir -p "$d/contents/ui" "$d/contents/config"
if [ ! -f "$d/metadata.json" ]; then
  python3 - "$d/metadata.json" "$id" "$nombre" "$desc" "$icono" "$cat" <<'PY'
import json, sys
p, i, n, d, ic, c = sys.argv[1:]
json.dump({"KPackageStructure": "Plasma/Applet",
           "KPlugin": {"Authors": [{"Name": "Coucou"}], "Category": c, "Description": d, "Icon": ic,
                       "Id": "org.coucou." + i, "License": "GPL-2.0+", "Name": "Coucou: " + n, "Version": "1.0",
                       "Website": "https://github.com/Louis-CFM/coucou"},
           "X-Plasma-API-Minimum-Version": "6.0"}, open(p, "w"), ensure_ascii=False, indent=4)
PY
  printf 'import QtQuick\nimport org.kde.plasma.configuration\n\nConfigModel {\n    ConfigCategory { name: "General"; icon: "configure"; source: "ConfigGeneral.qml" }\n}\n' > "$d/contents/config/config.qml"
fi
{ echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.kde.org/standards/kcfg/1.0 http://www.kde.org/standards/kcfg/1.0/kcfg.xsd">'
  echo '  <kcfgfile name=""/>'
  echo '  <group name="General">'
  echo '    <entry name="estilo" type="String"><default>coucou</default></entry>'
  for e in "$@"; do
    n=${e%% *}; r=${e#* }; t=${r%% *}; v=${r#* }; [ "$r" = "$t" ] && v=""
    v=${v//&/&amp;}; v=${v//</&lt;}
    echo "    <entry name=\"$n\" type=\"$t\"><default>$v</default></entry>"
  done
  echo '  </group>'
  echo '</kcfg>'; } > "$d/contents/config/main.xml"
echo "listo: $d"
