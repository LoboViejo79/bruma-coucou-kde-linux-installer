#!/usr/bin/env bash
# Instalar Bruma Coucou: qué apps de la página "Aplicaciones" ya están en el equipo, del sistema (pacman)
# o de Flatpak (del sistema o de la cuenta): así no se instalan dos veces ni aparecen dos iguales.
#   apps-instaladas.sh [usuario]   →  ids separados por comas (juegos,discord,…)
set -uo pipefail
U=${1:-$(id -un)}
pq() { pacman -Q "$@" >/dev/null 2>&1 && return 0; local p; for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 && return 0; done; return 1; }
FP=$( { flatpak list --system --app --columns=application 2>/dev/null
        if [ "$(id -u)" = 0 ] && [ "$U" != root ]; then runuser -u "$U" -- flatpak list --user --app --columns=application 2>/dev/null
        else flatpak list --user --app --columns=application 2>/dev/null; fi; } | sort -u)
fp() { grep -qx "$1" <<<"$FP"; }
hay=()
{ pq steam || pq cachyos-gaming-meta; } && hay+=(juegos)
pq winboat && hay+=(windows)
{ pq code || pq visual-studio-code-bin || pq vscodium || pq vscodium-bin || fp com.visualstudio.code || fp com.vscodium.codium; } && hay+=(vscode)
{ pq discord || pq discord-canary || pq vesktop || pq vesktop-bin || fp com.discordapp.Discord || fp dev.vencord.Vesktop; } && hay+=(discord)
{ pq spotify || pq spotify-launcher || fp com.spotify.Client; } && hay+=(spotify)
{ pq anydesk || pq anydesk-bin || fp com.anydesk.Anydesk; } && hay+=(anydesk)
{ pq vlc || fp org.videolan.VLC; } && hay+=(vlc)
(IFS=,; echo "${hay[*]}")
