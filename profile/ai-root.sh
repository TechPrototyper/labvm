#!/usr/bin/env bash
# Als root: Node.js (LTS) für die KI-Werkzeuge. Qwen Code verlangt Node >= 22, Debian 13 liefert 20.
# Offizielles Tarball von nodejs.org, SHA-256 gepinnt. Idempotent.
set -euo pipefail
export LC_ALL=C.UTF-8
log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }

NODE_VER=v24.22.3
NODE_SHA=6e51a2ada00f0011cc266f65d98922b403d7ad88f809ca2aa615a5fe1ce6e86c
dir="/opt/node-$NODE_VER-linux-arm64"
if [ ! -x "$dir/bin/node" ]; then
  log "Node.js $NODE_VER installieren"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/node.tar.xz" "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-linux-arm64.tar.xz"
  echo "$NODE_SHA  $tmp/node.tar.xz" | sha256sum -c --status || { echo "Prüfsumme Node.js falsch" >&2; exit 1; }
  tar -xJf "$tmp/node.tar.xz" -C /opt
  rm -rf "$tmp"
else
  log "Node.js $NODE_VER bereits installiert"
fi
ln -sfn "$dir" /opt/node

# PATH für alle Sitzungen: Node, npm-Global-Prefix des Benutzers, ~/.local/bin (Claude Code)
cat > /etc/profile.d/ai-tools.sh <<'PROFILE'
case ":$PATH:" in *":/opt/node/bin:"*) ;; *) export PATH="$PATH:/opt/node/bin" ;; esac
case ":$PATH:" in *":$HOME/.npm-global/bin:"*) ;; *) export PATH="$PATH:$HOME/.npm-global/bin" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$PATH:$HOME/.local/bin" ;; esac
PROFILE
grep -q 'ai-tools.sh' /etc/bash.bashrc || printf '\n[ -r /etc/profile.d/ai-tools.sh ] && . /etc/profile.d/ai-tools.sh\n' >> /etc/bash.bashrc
