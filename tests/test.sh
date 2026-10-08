#!/usr/bin/env bash
# Offline test: fake claude/ollama/curl on PATH, no network, no real models.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
fail=0; check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected [$3] got [$2]"; fail=1; fi; }

# fake real claude: FAKE_MODE=ok answers, FAKE_MODE=expired prints the real 401 text.
cat > "$T/real-claude" <<'X'
#!/usr/bin/env bash
if [ -n "${ANTHROPIC_BASE_URL:-}" ]; then echo "CLOUD:$*"; exit 0; fi
[ "${1:-}" = auth ] && { echo '{"loggedIn": true}'; exit 0; }
if [ "$FAKE_MODE" = expired ]; then echo "Failed to authenticate. API Error: 401 OAuth access token is invalid."; exit 1; fi
if [ "$FAKE_MODE" = broken ]; then echo "some other error"; exit 3; fi
echo "CLAUDE:$*:$(cat)"
X
cat > "$T/bin/ollama" <<'X'
#!/usr/bin/env bash
case "$1" in show) exit 0 ;; run) echo "LOCAL[$2]:$3" ;; esac
X
cat > "$T/bin/curl" <<'X'
#!/usr/bin/env bash
case "$*" in *api/version*) exit 0 ;; *api/chat*) [ "${FAKE_CLOUD:-down}" = up ] && exit 0 || exit 7 ;; esac
X
chmod +x "$T"/real-claude "$T"/bin/*
export PATH="$T/bin:$PATH" CLAUDE_FALLBACK_REAL="$T/real-claude" CLAUDE_FALLBACK_MARKER="$T/limited"
export CLAUDE_FALLBACK_MODELS="test:1b-cloud llama3.2"
unset ANTHROPIC_BASE_URL CLAUDE_FALLBACK_OFF
cf="$ROOT/claude-fallback"

check "healthy claude passes through" "$(echo in | FAKE_MODE=ok "$cf" -p hi --model sonnet)" "CLAUDE:-p hi --model sonnet:in"
check "other errors are not swallowed" "$(echo | FAKE_MODE=broken "$cf" -p hi 2>/dev/null; echo "rc=$?")" "some other error
rc=3"
check "expired -> local chat, stdin kept, --model dropped" \
  "$(echo ctx | FAKE_MODE=expired "$cf" -p hi --model sonnet 2>/dev/null)" "LOCAL[cf-llama3.2]:hi
ctx"
check "failure leaves a marker" "$([ -f "$T/limited" ] && echo yes)" "yes"
check "expired -> cloud model through Claude Code when cloud is up" \
  "$(echo | FAKE_MODE=expired FAKE_CLOUD=up "$cf" -p hi --model sonnet 2>/dev/null)" "CLOUD:--bare --model test:1b-cloud -p hi"
check "--local forces fallback" "$(echo | FAKE_MODE=ok "$cf" --local -p hi 2>/dev/null)" "LOCAL[cf-llama3.2]:hi"
check "CLAUDE_FALLBACK_OFF bypasses" "$(echo x | FAKE_MODE=expired CLAUDE_FALLBACK_OFF=1 "$cf" -p hi)" "Failed to authenticate. API Error: 401 OAuth access token is invalid."
# a second installed copy must not be mistaken for the real CLI (would loop forever)
mkdir -p "$T/copy" "$T/realdir"; cp "$cf" "$T/copy/claude"; cp "$T/real-claude" "$T/realdir/claude"
check "skips other copies of itself" \
  "$(echo in | FAKE_MODE=ok CLAUDE_FALLBACK_REAL= PATH="$T/copy:$T/realdir:$PATH" timeout 10 "$cf" -p hi)" "CLAUDE:-p hi:in"
exit $fail
