#!/bin/sh
set -u
root=$(cd "$(dirname "$0")/../.." && pwd)
app="$root/mac/dist/OPUS@Home.app/Contents/MacOS/OPUSAtHome"
out="$root/mac/dist/screens"
data="$HOME/Library/Application Support/OPUS@Home"
state="$RUNNER_TEMP/fake-codex"
scroll="$RUNNER_TEMP/scroll"
mkdir -p "$out" "$data" "$state"
swiftc -O -o "$scroll" "$root/mac/ci/scroll.swift"
export FAKE_CODEX_STATE="$state"
pid=""

start() { "$app" & pid=$!; sleep "${1:-12}"; }
stop() { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true; sleep 2; }
shot() { screencapture -x "$out/$1.png"; echo "saved $1.png"; }
menu() {
  osascript -e 'tell application "System Events" to tell process "OPUSAtHome" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1
  sleep 3
  shot "$1"
  osascript -e 'tell application "System Events" to tell process "OPUSAtHome" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1
  sleep 1
}
settings_shots() {
  OPUS_AT_HOME_PREVIEW=settings "$app" & pid=$!
  sleep 12
  shot "$1-top"
  "$scroll" 512 400 -60
  sleep 2
  shot "$1-bottom"
  stop
}
prefs() { printf '%s\n' "$1" > "$data/settings.json"; }
limits() {
  now=$(date +%s)
  printf '{"primary":{"usedPercent":%s,"windowDurationMins":300,"resetsAt":%s},"secondary":{"usedPercent":%s,"windowDurationMins":10080,"resetsAt":%s}}\n' \
    "$1" $((now + 7200)) "$2" $((now + $3)) > "$state/limits.json"
}

prefs '{}'
start; menu 01-menu-first-launch; stop
settings_shots 02-settings-first-launch

brew install --quiet lilypond >/dev/null 2>&1 || echo "lilypond install failed"
sudo install -m 755 "$root/mac/ci/fake-codex" /usr/local/bin/codex
command -v codex lilypond

limits 20 40 108000
prefs '{"enabled":true,"openPullRequests":false}'
start 20; menu 03-menu-saving-quota; stop
settings_shots 04-settings-ready

limits 20 40 600
start 20; menu 05-menu-reset-too-close; stop

limits 20 40 10800
start 45; menu 06-menu-running; sleep 70; menu 07-menu-after-run; stop

prefs '{"enabled":true,"openPullRequests":false,"quotaMode":"anytime"}'
settings_shots 08-settings-anytime

echo "--- fake codex log"; cat "$state/exec.log" 2>/dev/null
echo "--- work folder"; ls -la "$data/work" 2>/dev/null
echo "--- history"; cat "$data/history.json" 2>/dev/null
echo "--- latest run log"; cat "$(ls -t "$data"/logs/*.log 2>/dev/null | head -1)" 2>/dev/null | grep opus-at-home

set -e
export FAKE_CLAUDE_STATE="$RUNNER_TEMP/fake-claude"
mkdir -p "$FAKE_CLAUDE_STATE"
npm install --no-audit --no-fund --prefix "$RUNNER_TEMP/opus-claude-cli" @anthropic-ai/claude-code
export PATH="$RUNNER_TEMP/opus-claude-cli/node_modules/.bin:$PATH"
claude --version
prefs '{"agent":"claude","openPullRequests":false}'
"$app" --setup-prompt > "$state/setup-prompt"
grep -F 'Claude Code (Not signed in)' "$state/setup-prompt"
if grep -E 'Codex|Docker|GitHub CLI' "$state/setup-prompt"; then exit 1; fi
export PATH="/usr/local/bin:$PATH"
sudo install -m 755 "$root/mac/ci/fake-claude" /usr/local/bin/claude
start; menu 09-claude-setup; stop
"$root/mac/dist/OPUS@Home.app/Contents/Resources/Setup.command"
test -f "$FAKE_CLAUDE_STATE/signed-in"
"$app" --setup-prompt | grep -F 'setup for Claude Code is complete'
"$app" --run-once --agent claude --no-pr
grep -Fx "$data/work" "$FAKE_CLAUDE_STATE/work-path"
git -C "$data/repo" show HEAD:pieces/opus-ci-test/attempts/01.ly | grep -F "{ c'1 }"
grep -F 'Committed locally' "$data/history.json"
settings_shots 10-claude-ready
