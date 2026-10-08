#!/usr/bin/env bash
# Installs claude-fallback as `claude` in ~/.claude-fallback/bin and puts that dir first on PATH.
#   curl -fsSL https://raw.githubusercontent.com/oyekamal/claude-local-fallback/main/install.sh | bash
set -eu
DIR=$HOME/.claude-fallback/bin
RAW=https://raw.githubusercontent.com/oyekamal/claude-local-fallback/main/claude-fallback
LINE='export PATH="$HOME/.claude-fallback/bin:$PATH"  # claude-local-fallback'

mkdir -p "$DIR"
here=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -n "$here" ] && [ -f "$here/claude-fallback" ]; then
  cp "$here/claude-fallback" "$DIR/claude"
else
  curl -fsSL "$RAW" -o "$DIR/claude"
fi
chmod +x "$DIR/claude"

added=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  grep -qF '# claude-local-fallback' "$rc" || { echo "$LINE" >> "$rc"; added=1; echo "added PATH line to $rc"; }
done
[ -f "$HOME/.bashrc" ] || [ -f "$HOME/.zshrc" ] || { echo "$LINE" >> "$HOME/.bashrc"; echo "added PATH line to ~/.bashrc"; }

echo
echo "installed: $DIR/claude"
command -v ollama >/dev/null || echo "!! Ollama is missing. Install it: https://ollama.com/download  (Linux: curl -fsSL https://ollama.com/install.sh | sh)"
PATH="$DIR:$PATH" command -v claude >/dev/null 2>&1 && [ "$(PATH="$DIR:$PATH" type -ap claude | sed -n 2p)" ] \
  || echo "note: Claude Code itself isn't installed. Fine for local-only use; get it at https://claude.com/claude-code"
echo
echo "Open a new terminal (or: source ~/.bashrc / ~/.zshrc), then try:"
echo "  claude --local -p \"say hi\""
