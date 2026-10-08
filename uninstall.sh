#!/usr/bin/env bash
# Removes claude-fallback. Your real Claude Code install is untouched.
set -eu
rm -rf "$HOME/.claude-fallback"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] && grep -qF '# claude-local-fallback' "$rc" && sed -i.bak '/# claude-local-fallback/d' "$rc" && echo "cleaned $rc (backup: $rc.bak)"
done
echo "removed. Ollama models stay; list them with 'ollama list', delete with 'ollama rm <name>'."
