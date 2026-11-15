#!/usr/bin/env bash
# labvm Standard-Ausstattung (als Benutzer): Claude Code, Qwen Code (und OpenCode), Browser-Vorgabe, Shared-Link, Desktop-Starter.
set -euo pipefail
export LC_ALL=C.UTF-8
export PATH="/opt/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }

mkdir -p "$HOME/.npm-global" "$HOME/Desktop" "$HOME/.config/xfce4"
npm config set prefix "$HOME/.npm-global" >/dev/null

# ---- Claude Code (offizieller Installer, braucht kein Node)
if command -v claude >/dev/null 2>&1; then
  log "Claude Code vorhanden ($(claude --version 2>/dev/null | head -1)), prüfe auf Update"
  timeout 180 claude update >/dev/null 2>&1 || warn "claude update nicht möglich (nicht kritisch)"
else
  log "Claude Code installieren"
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || warn "Claude Code konnte nicht installiert werden"
fi
# ---- Qwen Code und OpenCode per npm (@latest, nur wenn nicht aktuell)
npm_latest() {
  local pkg="$1" want have
  want="$(npm view "$pkg" version 2>/dev/null || true)"
  have="$(npm ls -g --depth=0 --json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin).get("dependencies",{}); print(d.get(sys.argv[1],{}).get("version",""))' "$pkg" 2>/dev/null || true)"
  if [ -n "$want" ] && [ "$have" = "$want" ]; then log "$pkg $have aktuell"; return; fi
  if npm install -g "$pkg@latest" >/dev/null 2>&1; then log "$pkg ${want:-?} installiert"; else warn "$pkg konnte nicht installiert werden"; fi
}
npm_latest @qwen-code/qwen-code
npm_latest opencode-ai

# ---- Chromium als Standardbrowser des Benutzers (xdg + XFCE), Starter auf dem Desktop
xdg-settings set default-web-browser chromium.desktop >/dev/null 2>&1 || true
if grep -q '^WebBrowser=' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null; then
  sed -i 's/^WebBrowser=.*/WebBrowser=chromium/' "$HOME/.config/xfce4/helpers.rc"
else
  echo 'WebBrowser=chromium' >> "$HOME/.config/xfce4/helpers.rc"
fi
cat > "$HOME/Desktop/chromium.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Chromium
Exec=chromium %U
Icon=chromium
Terminal=false
StartupNotify=true
DESK
chmod +x "$HOME/Desktop/chromium.desktop"
cat > "$HOME/Desktop/terminal.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Terminal=false
DESK
chmod +x "$HOME/Desktop/terminal.desktop"
bus="/run/user/$(id -u)/bus"
if [ -S "$bus" ]; then
  for f in "$HOME"/Desktop/*.desktop; do
    sum="$(sha256sum "$f" | cut -d' ' -f1)"
    DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set -t string "$f" metadata::xfce-exe-checksum "$sum" 2>/dev/null \
      && DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set "$f" metadata::trusted true 2>/dev/null || true
  done
fi

# ---- Shared-Ordner (Mac: ~/LabShare/<Pfad>) als ~/share
[ -d /mnt/share ] && ln -sfn /mnt/share "$HOME/share"
for c in claude qwen opencode; do v="$("$c" --version 2>/dev/null | head -1 || true)"; log "$c: ${v:-NICHT GEFUNDEN}"; done
log "base-user.sh fertig"
