#!/usr/bin/env bash
# Installiert labvm (idempotent): Befehl nach /opt/homebrew/bin (oder /usr/local/bin), zstd, Claude-Skill, zsh-Vervollständigung.
set -euo pipefail
cd "$(dirname "$0")"; here="$(pwd)"
for tool in limactl zstd; do
  command -v "$tool" >/dev/null || { echo "!! $tool fehlt -> brew install ${tool/limactl/lima}"; }
done
bin=/opt/homebrew/bin; [ -w "$bin" ] || bin=/usr/local/bin
ln -sfn "$here/labvm" "$bin/labvm" && echo "-> $bin/labvm"
mkdir -p "$HOME/.claude/skills/labvm"
ln -sfn "$here/skill/SKILL.md" "$HOME/.claude/skills/labvm/SKILL.md" && echo "-> ~/.claude/skills/labvm/SKILL.md (Claude-Skill)"
mkdir -p "$HOME/.zfunc" && "$here/labvm" completion zsh > "$HOME/.zfunc/_labvm" && echo "-> ~/.zfunc/_labvm (in ~/.zshrc: fpath+=~/.zfunc; autoload -U compinit && compinit)"
"$here/labvm" doctor || true
