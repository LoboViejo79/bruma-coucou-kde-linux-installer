#!/usr/bin/env python3
# Coucou: avisos por voz. Lee en voz alta las notificaciones y avisa cuando hay
# actualizaciones del sistema, con la voz de Sebastián (es-VE-SebastianNeural, Microsoft Edge).
#
#  - Notificaciones: escucha las que llegan al escritorio (org.freedesktop.Notifications.Notify)
#  - Actualizaciones: cuenta los paquetes pendientes (checkupdates) cada 2 horas
#  - "No molestar" de KDE activado: no dice nada
#
# El texto se envía al servicio de voz de Microsoft para convertirlo en audio.
# Ajustes en ~/.config/coucou/voz.ini ([voz] voz=, velocidad=, notificaciones=, actualizaciones=)
import asyncio
import configparser
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

import edge_tts

CFG = os.path.expanduser("~/.config/coucou/voz.ini")
STATE = os.path.expanduser("~/.local/state/coucou-voz")
# Apps que no se leen (las que avisan de cosas que ya ves o escuchas)
IGNORAR = {"plasma_waitforname", "kdeconnect", "spectacle", "kmix", "org.kde.plasma.mediacontroller", "actualizaciones"}


def ajustes():
    c = configparser.ConfigParser()
    c.read(CFG)
    s = c["voz"] if c.has_section("voz") else {}
    return {
        "voz": s.get("voz", "es-VE-SebastianNeural"),
        "velocidad": s.get("velocidad", "+0%"),
        "notificaciones": s.get("notificaciones", "si") != "no",
        "actualizaciones": s.get("actualizaciones", "si") != "no",
    }


def no_molestar() -> bool:
    try:
        out = subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                              "--object-path", "/org/freedesktop/Notifications", "--method",
                              "org.freedesktop.DBus.Properties.Get", "org.freedesktop.Notifications", "Inhibited"],
                             capture_output=True, text=True, timeout=3).stdout
        return "true" in out
    except Exception:
        return False


def limpiar(t: str) -> str:
    t = html.unescape(re.sub(r"<[^>]+>", " ", t or ""))
    t = re.sub(r"https?://\S+", "un enlace", t)
    return re.sub(r"\s+", " ", t).strip()


cola: asyncio.Queue = asyncio.Queue()


async def hablar(texto: str):
    a = ajustes()
    reproductor = shutil.which("ffplay")
    try:
        with tempfile.NamedTemporaryFile(suffix=".mp3", dir=os.environ.get("XDG_RUNTIME_DIR")) as f:
            await edge_tts.Communicate(texto, a["voz"], rate=a["velocidad"]).save(f.name)
            if reproductor:
                p = await asyncio.create_subprocess_exec(reproductor, "-nodisp", "-autoexit", "-loglevel", "quiet", f.name)
                await p.wait()
    except Exception as e:  # sin internet, etc.: no se cae, solo no habla
        print(f"voz: {e}", file=sys.stderr, flush=True)


async def hablante():
    while True:
        await hablar(await cola.get())


def decir(texto: str):
    if texto:
        cola.put_nowait(texto[:260])


# ── Notificaciones ───────────────────────────────────────────────────────────
async def notificaciones():
    recientes: dict[str, float] = {}
    while True:
        p = await asyncio.create_subprocess_exec(
            "dbus-monitor", "--session",
            "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        valores: list[str] = []
        dentro = False
        async for raw in p.stdout:
            linea = raw.decode(errors="replace").rstrip("\n")
            if linea.startswith("method call") and "member=Notify" in linea:
                dentro, valores = True, []
                continue
            if not dentro:
                continue
            m = re.match(r'^\s+(string|uint32) (.*)$', linea)
            if m and len(valores) < 5:
                v = m.group(2)
                valores.append(v[1:-1] if m.group(1) == "string" else v)
                if len(valores) == 5:
                    dentro = False
                    app, _, _, titulo, cuerpo = valores
                    a = ajustes()
                    if not a["notificaciones"] or app.lower() in IGNORAR or no_molestar():
                        continue
                    titulo, cuerpo = limpiar(titulo), limpiar(cuerpo)
                    clave = f"{app}|{titulo}|{cuerpo}"
                    ahora = time.time()
                    if ahora - recientes.get(clave, 0) < 60:
                        continue
                    recientes[clave] = ahora
                    quien = limpiar(app)
                    texto = f"{quien}: {titulo}" if quien and quien.lower() not in titulo.lower() else titulo
                    if cuerpo and cuerpo.lower() != titulo.lower():
                        texto += f". {cuerpo}"
                    decir(texto)
        await p.wait()
        await asyncio.sleep(3)   # dbus-monitor se cerró: volver a escuchar


# ── Actualizaciones del sistema ──────────────────────────────────────────────
async def actualizaciones():
    os.makedirs(STATE, exist_ok=True)
    f = os.path.join(STATE, "actualizaciones")
    await asyncio.sleep(120)   # después del inicio de sesión, sin apurar
    while True:
        a = ajustes()
        if a["actualizaciones"] and shutil.which("checkupdates"):
            p = await asyncio.create_subprocess_exec("checkupdates", stdout=asyncio.subprocess.PIPE,
                                                     stderr=asyncio.subprocess.DEVNULL)
            out, _ = await p.communicate()
            n = len([l for l in out.decode().splitlines() if l.strip()])
            try:
                antes = int(open(f).read().strip())
            except Exception:
                antes = 0
            if n > antes and not no_molestar():
                decir("Hay una actualización del sistema disponible." if n == 1
                      else f"Hay {n} actualizaciones del sistema disponibles.")
            open(f, "w").write(str(n))
        await asyncio.sleep(2 * 3600)


async def main():
    if "--probar" in sys.argv:
        await hablar(" ".join(x for x in sys.argv[1:] if x != "--probar") or "Hola, soy Sebastián. Así te voy a avisar.")
        return
    await asyncio.gather(hablante(), notificaciones(), actualizaciones())


if __name__ == "__main__":
    asyncio.run(main())
