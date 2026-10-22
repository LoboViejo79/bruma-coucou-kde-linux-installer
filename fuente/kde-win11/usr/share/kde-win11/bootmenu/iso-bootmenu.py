#!/usr/bin/env python3
"""Menú de arranque de la ISO con el aspecto del de Windows.

Uso: iso-bootmenu.py <carpeta archiso del proyecto CachyOS-Live-ISO>

Lo ejecuta build-iso.sh sobre el proyecto oficial recién descargado:
  - grub/ (arranque UEFI): copia el tema win11 y rehace grub.cfg con las mismas líneas de arranque
    (linux/initrd) que trae CachyOS, pero con el menú de Windows:
        CachyOS
        CachyOS en modo seguro (gráficos básicos)
        Otras opciones  ->  kernel LTS, prueba de memoria, shell y firmware UEFI, apagar, reiniciar
  - syslinux/ (arranque BIOS): mismos colores, fondo y textos en español.
Si el formato del proyecto oficial cambia, falla con un mensaje en vez de dejar un menú roto.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BLUE = "#0a58ab"
THEME = "/boot/grub/themes/win11"


def fail(msg):
    sys.exit(f"iso-bootmenu: {msg}")


def entry(cfg, ident):
    """Cuerpo (líneas entre llaves) del menuentry con --id 'ident'."""
    m = re.search(r"(?ms)^menuentry [^\n]*--id '" + re.escape(ident) + r"'[^\n]*\{\n(.*?)^\}", cfg)
    if not m:
        fail(f"no encuentro la entrada '{ident}' en grub.cfg")
    return m.group(1)


def grub(archiso):
    g = archiso / "grub"
    cfg = (g / "grub.cfg").read_text()

    # Cabecera: módulos, fuente, terminal gráfica y consola serie (hasta la entrada por defecto)
    head, sep, _ = cfg.partition("# Set default menu entry")
    if not sep:
        fail("grub.cfg sin '# Set default menu entry'")
    # Herramientas: desde Memtest hasta el final (bloques if con sus menuentry)
    i = cfg.find("if [ \"${grub_platform}\" == 'efi' -a \"${grub_cpu}\" == 'x86_64' -a -f '/boot/memtest86+")
    if i < 0:
        fail("no encuentro el bloque de Memtest86+ en grub.cfg")
    tools = cfg[i:].rstrip() + "\n"
    for old, new in (("'Run Memtest86+ (RAM test)'", "'Prueba de memoria (Memtest86+)'"),
                     ("'UEFI Shell'", "'Shell UEFI'"),
                     ("'UEFI Firmware Settings' --id", "'Configuración del firmware UEFI' --class efi --id"),
                     ("'System shutdown'", "'Apagar el equipo'"),
                     ("'System restart'", "'Reiniciar el equipo'"),
                     ("'System shutting down...'", "'Apagando...'"),
                     ("'System rebooting...'", "'Reiniciando...'")):
        if old not in tools:
            fail(f"no encuentro {old} en grub.cfg")
        tools = tools.replace(old, new)
    tools = "\n".join(("    " + l) if l.strip() else l for l in tools.split("\n"))

    default, lts, safe = entry(cfg, "cachyos"), entry(cfg, "cachyos-lts"), entry(cfg, "cachyos-fallback")
    cls = "--class cachyos --class arch --class gnu-linux --class os"

    out = head.rstrip() + f"""

# Tema estilo Windows ("Elegir un sistema operativo")
# (sin terminal gráfica, GRUB ignora el tema y muestra el menú en texto)
loadfont {THEME}/selawik-light-40.pf2
loadfont {THEME}/selawik-24.pf2
loadfont {THEME}/selawik-18.pf2
insmod png
insmod gfxmenu
set theme={THEME}/theme.txt
export theme

# Set default menu entry
default=cachyos
timeout=10
timeout_style=menu

menuentry "CachyOS" {cls} --id 'cachyos' {{
{default}}}

menuentry "CachyOS en modo seguro" {cls} --id 'cachyos-fallback' {{
{safe}}}

submenu "Otras opciones" --class options --id 'opciones' {{
    set theme={THEME}/theme-options.txt
    menuentry "CachyOS con kernel LTS" {cls} --id 'cachyos-lts' {{
{indent(lts)}    }}
{tools}}}
"""
    (g / "grub.cfg").write_text(out)

    # Tema: el mismo título cambia a "Elegir una opción" dentro de Otras opciones
    dst = g / "themes" / "win11"
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(HERE / "grub" / "win11", dst)
    t = (dst / "theme.txt").read_text()
    (dst / "theme-options.txt").write_text(t.replace('"Elegir un sistema operativo"', '"Elegir una opción"'))
    # El splash de CachyOS ya no se usa
    (g / "splash.png").unlink(missing_ok=True)
    # Comprobación de sintaxis con el propio GRUB
    chk = subprocess.run(["grub-script-check", str(g / "grub.cfg")], capture_output=True, text=True)
    if chk.returncode:
        fail("grub.cfg generado no es válido: " + chk.stdout + chk.stderr)


def indent(body):
    return "".join("    " + l + "\n" if l.strip() else "\n" for l in body.rstrip("\n").split("\n"))


def syslinux(archiso):
    s = archiso / "syslinux"
    head = s / "archiso_head.cfg"
    h = head.read_text()
    h = re.sub(r"(?m)^MENU TITLE .*$", "MENU TITLE Elegir un sistema operativo", h)
    h = re.sub(r"(?m)^MENU BACKGROUND .*$", "MENU RESOLUTION 1024 768\nMENU BACKGROUND splash.png", h)
    # Colores: texto blanco sobre el azul, opción elegida resaltada en azul claro
    h = re.sub(r"(?m)^MENU COLOR .*\n", "", h)
    h = re.sub(r"(?m)^MENU WIDTH .*$", "MENU WIDTH 60", h)
    h = re.sub(r"(?m)^MENU MARGIN .*$", "MENU MARGIN 0", h)
    h = h.replace("# Refer to", """MENU COLOR screen       37;44   #ffffffff #00000000 none
MENU COLOR border       30;44   #00000000 #00000000 none
MENU COLOR title        1;37;44 #ffffffff #00000000 none
MENU COLOR sel          7;37;44 #ffffffff #40ffffff none
MENU COLOR unsel        37;44   #ffffffff #00000000 none
MENU COLOR hotsel       7;37;44 #ffffffff #40ffffff none
MENU COLOR hotkey       37;44   #ffffffff #00000000 none
MENU COLOR help         37;44   #ffd6e6f8 #00000000 none
MENU COLOR timeout_msg  37;44   #ffd6e6f8 #00000000 none
MENU COLOR timeout      1;37;44 #ffffffff #00000000 none
MENU COLOR msg07        37;44   #ffffffff #00000000 none
MENU COLOR tabmsg       37;44   #ffd6e6f8 #00000000 none
MENU TABMSG Tab: editar la opción
MENU AUTOBOOT Se iniciará automáticamente en # s

# Refer to""")
    head.write_text(h)

    sl = s / "archiso_sys-linux.cfg"
    c = sl.read_text()
    for old, new in (("MENU LABEL CachyOS default (%ARCH%, BIOS)", "MENU LABEL CachyOS"),
                     ("MENU LABEL CachyOS Fallback (nomodeset, BIOS)",
                      "MENU LABEL CachyOS en modo seguro (gráficos básicos)")):
        if old not in c:
            fail(f"no encuentro '{old}' en {sl.name}")
        c = c.replace(old, new)
    c = re.sub(r"(?s)TEXT HELP\nBoot the CachyOS install medium on BIOS\.\n.*?ENDTEXT",
               "TEXT HELP\nProbar CachyOS o instalarlo en este equipo.\nENDTEXT", c)
    c = re.sub(r"(?s)TEXT HELP\nBoot the CachyOS install medium on Bios in fallback mode\n.*?ENDTEXT",
               "TEXT HELP\nUsalo si la pantalla queda en negro o se congela al iniciar.\nENDTEXT", c)
    sl.write_text(c)

    tail = s / "archiso_tail.cfg"
    t = tail.read_text()
    for old, new in (("MENU LABEL Boot existing OS", "MENU LABEL Iniciar el sistema que ya está instalado"),
                     ("MENU LABEL Run Memtest86+ (RAM test)", "MENU LABEL Prueba de memoria (Memtest86+)"),
                     ("MENU LABEL Hardware Information (HDT)", "MENU LABEL Información del hardware (HDT)"),
                     ("MENU LABEL Reboot", "MENU LABEL Reiniciar el equipo"),
                     ("MENU LABEL Power Off", "MENU LABEL Apagar el equipo")):
        t = t.replace(old, new)   # opcionales: si alguna cambia, queda en inglés
    t = re.sub(r"(?s)TEXT HELP\n.*?ENDTEXT\n", "", t)
    tail.write_text(t)

    # Fondo 1024x768 azul liso
    subprocess.run(["magick", "-size", "1024x768", f"xc:{BLUE}", "-depth", "8",
                    f"PNG24:{s / 'splash.png'}"], check=True)
    (s / "splash1.png").unlink(missing_ok=True)


def main():
    if len(sys.argv) != 2:
        fail("uso: iso-bootmenu.py <carpeta archiso>")
    archiso = Path(sys.argv[1])
    grub(archiso)
    syslinux(archiso)
    print("menú de arranque estilo Windows listo")


if __name__ == "__main__":
    main()
