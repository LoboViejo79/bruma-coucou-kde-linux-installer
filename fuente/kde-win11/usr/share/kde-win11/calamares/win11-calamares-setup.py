#!/usr/bin/env python3
"""Adapta el instalador de la ISO al aspecto de Windows 11.

Se ejecuta (como root) cada vez que puede cambiar la configuración de Calamares:
  - al arrancar el sistema en vivo (win11-calamares-setup.service)
  - cuando pacman instala o actualiza Calamares (gancho win11-calamares.hook): la ISO reinstala
    cachyos-calamares-next desde el repositorio justo antes de abrir el instalador
  - desde calamares-online.sh, justo antes de abrir Calamares (lo que abre CachyOS Hello)
Así se abra como se abra (Hello, menú, icono), el instalador siempre es el de Windows 11 y siempre
termina instalando el aspecto de Windows 11. No se copian configuraciones fijas: se transforman las
de la versión de Calamares que haya.

  - tema cachyos-win11 (pasos a la izquierda, botón Siguiente azul...)
  - sin el paso "Escritorio": siempre Plasma
  - paso "Arranque" en español, con vistas previas del menú estilo Windows
  - "Programas" sin los demás escritorios y solo con la lista local
  - al final, los pasos que instalan el paquete kde-win11 y lo dejan aplicado (obligatorios)
"""
import re
import shutil
import sys
import traceback
from pathlib import Path

ISO = Path("/usr/share/kde-win11-iso")
ETC = Path("/etc/calamares")
SHARE = Path("/usr/share/calamares")
BRANDING = SHARE / "branding" / "cachyos-win11"
STEPS = ("win11_copy", "win11_setup")


def settings_text(s):
    s = re.sub(r"(?m)^branding:.*$", "branding: cachyos-win11", s)
    s = re.sub(r"(?m)^  - packagechooser@desktop\n", "", s)
    if "shellprocess_win11_copy.conf" not in s:
        extra = "".join(f"- id:       {i}\n  module:   shellprocess\n  config:   shellprocess_{i}.conf\n"
                        for i in STEPS)
        s, n = re.subn(r"(?m)^instances:\n", "instances:\n" + extra, s, count=1)
        if not n:
            s = s.replace("\nsequence:", "\ninstances:\n" + extra + "\nsequence:", 1)
    # Se quitan y se vuelven a poner: una configuración ya adaptada por una versión anterior los tenía
    # antes del "shellprocess" de CachyOS
    s = re.sub(r"(?m)^  - shellprocess@win11_(copy|setup)\n", "", s)
    steps = "  - shellprocess@win11_copy\n  - shellprocess@win11_setup\n"
    # Después del "shellprocess" de CachyOS: copia /etc/skel encima de la cuenta creada (barra,
    # tema y colores de CachyOS) y comprueba el gestor de inicio de sesión. Si nuestros pasos van
    # antes, deshace el aspecto de Windows 11 y SDDM puede no quedar como el elegido.
    s, n = re.subn(r"(?m)^(  - shellprocess\n)", r"\1" + steps, s, count=1)
    if not n:
        s, n = re.subn(r"(?m)^(  - services-systemd\n)", r"\1" + steps, s, count=1)
    if not n:
        s, n = re.subn(r"(?m)^(  - umount\n)", steps + r"\1", s, count=1)
    if not n:
        raise RuntimeError("no encuentro dónde agregar los pasos de Windows 11")
    return s


def settings():
    """settings.conf de Windows 11 en /etc y /usr/share (Calamares usa el primero que exista)."""
    src = SHARE / "settings_online.conf"
    if not src.exists():
        src = ETC / "settings.conf" if (ETC / "settings.conf").exists() else SHARE / "settings.conf"
    s = settings_text(src.read_text())
    ETC.mkdir(parents=True, exist_ok=True)
    (ETC / "settings.conf").write_text(s)
    for name in ("settings.conf", "settings_online.conf", "settings_offline.conf"):
        f = SHARE / name
        if f.exists():
            f.write_text(settings_text(f.read_text()))


def desktops():
    """Ids de los escritorios que ofrecía el paso "Escritorio" (grupos de netinstall)."""
    conf = ETC / "modules" / "packagechooser_desktop.conf"
    ids = set(re.findall(r'(?m)^\s*- id:\s*"?([^"\n]*)"?\s*$', conf.read_text())) if conf.exists() else set()
    ids.discard("")
    ids.discard("KDE-Desktop")
    return ids


def netinstall():
    conf = ETC / "modules" / "netinstall.conf"
    c = conf.read_text()
    c = re.sub(r"(?m)^ - https?://.*netinstall\.yaml\n", "", c)   # solo la lista local
    if "title[es]" not in c:
        c = c.replace(' title: "Additional packages"\n', ' title: "Additional packages"\n title[es]: "Programas adicionales"\n')
    if "sidebar[es]" not in c:
        c = re.sub(r'(?m)^( sidebar: .*\n)', r'\1 sidebar[es]: "Programas"\n', c, count=1)
    conf.write_text(c)

    y = ETC / "modules" / "netinstall.yaml"
    drop = desktops()
    out, group, skip = [], None, False
    for line in y.read_text().split("\n"):
        m = re.match(r'^- name:\s*"?([^"]*)"?', line)
        if m:
            group = m.group(1)
            skip = group in drop
        if skip:
            continue
        if group == "KDE-Desktop":   # Plasma siempre, sin mostrarlo
            line = re.sub(r"^  hidden: false", "  hidden: true", line)
            line = re.sub(r"^  selected: false", "  selected: true", line)
        out.append(line)
    y.write_text("\n".join(out))


# Paso "Arranque": textos en español y vistas previas del menú que se verá al encender el equipo.
# Cada texto dice qué es y cuándo elegirlo; Limine queda elegido por defecto
BOOT = {
    "limine": ("Limine (recomendado)",
               "<p><b>Recomendado.</b> Moderno y rápido. Funciona en equipos UEFI y BIOS, encuentra "
               "Windows si también está instalado y permite volver a un punto anterior del sistema "
               "(instantáneas Btrfs) desde el mismo menú.</p>"
               "<p>Con el menú azul de Windows.</p>", "boot-limine.png"),
    "grub": ("GRUB",
             "<p>El más compatible: funciona en casi cualquier equipo, también con la partición de "
             "arranque cifrada. Encuentra Windows y admite instantáneas Btrfs.</p>"
             "<p>Con el menú «Elegir un sistema operativo» de Windows, con íconos.</p>", "boot-grub.png"),
    "systemd-boot": ("systemd-boot",
                     "<p>El más simple. Solo equipos UEFI, sin instantáneas y con un menú de texto "
                     "(sin el aspecto de Windows).</p>"
                     "<p>Elegilo si tu placa madre (por ejemplo, MSI) da problemas con los otros.</p>",
                     "boot-systemd.png"),
    "refind": ("rEFInd",
               "<p>Menú gráfico que encuentra solo los sistemas de todos los discos. Solo equipos UEFI. "
               "Mantiene su propio aspecto (no el de Windows).</p>", "boot-refind.png"),
}
ORDER = ("limine", "grub", "systemd-boot", "refind")


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def bootloader():
    conf = ETC / "modules" / "packagechooser_bootloader.conf"
    if not conf.exists():
        return
    c = conf.read_text()
    # Ítems que ofrece esta versión de Calamares (con sus restricciones: solo EFI, plataforma)
    items = {}
    for block in re.split(r"(?m)^    - id:", c.split("items:", 1)[1])[1:]:
        ident = block.split("\n", 1)[0].strip().strip('"')
        items[ident] = {k: v for k, v in re.findall(r"(?m)^      (efiOnly|platform):\s*(.*)$", block)}
    mode = re.search(r"(?m)^mode:.*$", c)
    method = re.search(r"(?m)^method:.*$", c)
    default = "limine" if "limine" in items else re.search(r"(?m)^default:\s*(\S+)", c).group(1)

    out = ["# Paso \"Arranque\" (adaptado por win11-calamares-setup)", "---",
           mode.group(0) if mode else "mode: required",
           method.group(0) if method else "method: legacy",
           "labels:", '    step: "Boot menu"', '    step[es]: "Arranque"',
           f"default: {default}", "items:"]
    # Sin ítem de introducción (id vacío): esta versión lo mostraba como una opción más de la lista
    ids = [i for i in ORDER if i in items] + [i for i in items if i not in ORDER and i != "refind-ai"]
    for ident in ids:
        name, desc, shot = BOOT.get(ident, (ident, "", "boot-grub.png"))
        out.append(f"    - id: {q(ident)}")
        out.append(f"      name: {q(name)}")
        out.append(f"      description: {q(desc)}")
        for k, v in items.get(ident, {}).items():
            out.append(f"      {k}: {v}")
        out.append(f"      screenshot: {q(str(BRANDING / shot))}")
    conf.write_text("\n".join(out) + "\n")


LIGHT = ISO / "calamares-config"   # XDG_CONFIG_HOME con el que calamares-online.sh abre Calamares


def light_theme():
    """Colores claros para Calamares aunque la sesión en vivo use el tema oscuro de CachyOS.

    Calamares se abre con la configuración del usuario en vivo (BreezeDark): lo que el tema
    cachyos-win11 no pinta (el recuadro del Resumen, el mensaje de "¿Instalar ahora?", botones de
    Particiones…) quedaba con fondo oscuro y el texto oscuro del tema encima, ilegible.
    """
    src = Path("/usr/share/color-schemes/BreezeLight.colors")
    colors = src.read_text() if src.exists() else ""
    colors = re.sub(r"(?ms)^\[General\]\n.*?(?=^\[)", "", colors)   # nombre del esquema, no colores
    k = ("[General]\nColorScheme=BreezeLight\n\n[KDE]\nwidgetStyle=Breeze\nLookAndFeelPackage=org.kde.breeze.desktop\n\n"
         "[Icons]\nTheme=breeze\n\n" + colors)
    for d in (LIGHT, Path("/root/.config")):   # /root: si se abre Calamares sin calamares-online.sh
        d.mkdir(parents=True, exist_ok=True)
        (d / "kdeglobals").write_text(k)


def copy_files():
    shutil.rmtree(BRANDING, ignore_errors=True)
    shutil.copytree(ISO / "branding" / "cachyos-win11", BRANDING)
    (ETC / "modules").mkdir(parents=True, exist_ok=True)
    for f in (ISO / "modules").glob("shellprocess_win11_*.conf"):
        shutil.copy(f, ETC / "modules" / f.name)


def main():
    if not (SHARE.exists() or ETC.exists()):
        print("Calamares no está instalado")
        return 0
    ok = True
    # Lo imprescindible primero (tema y pasos de Windows 11); lo demás, aunque falle algo
    for step in (copy_files, settings, light_theme, bootloader, netinstall):
        try:
            step()
        except Exception:
            ok = False
            print(f"win11-calamares-setup: falló {step.__name__}", file=sys.stderr)
            traceback.print_exc()
    print("instalador adaptado a Windows 11" if ok else "instalador adaptado a Windows 11 (con avisos)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
