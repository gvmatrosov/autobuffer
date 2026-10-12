#!/usr/bin/env bash
# Autotests for bin/autobuffer.
#
# Part 1 — bytes: the exact bytes each terminal receives, the memory behind --again, send=.
#   Terminals are plain files; tmux and who are stand-ins first on PATH.
# Part 2 — the 📋 copy button on a REAL tmux server (a private socket, nothing of the person's):
#   the SessionStart hook, per-session options, the shared binding that keeps the person's own
#   tap, --tmux off/on, and a robot thumb (tests/tap.py) tapping the status line end to end.
#
#   tests/check.sh                    run everything
#   tests/check.sh --mutate           break autobuffer one spot at a time; each must turn a check red
#   tests/check.sh --quiet <file>     the checks against another copy (what --mutate runs)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/bin/autobuffer"
TAP="$REPO/tests/tap.py"
REAL_TMUX="$(command -v tmux || true)"

run_checks() {   # run_checks <autobuffer path> [quiet] → exit 0 when all pass
  local AB="$1" quiet="${2:-}" fails=0 T
  T="$(mktemp -d)"
  mkdir -p "$T/bin" "$T/plugin/bin" "$T/plugin/hooks"
  cp "$AB" "$T/plugin/bin/autobuffer"; chmod +x "$T/plugin/bin/autobuffer"
  cp "$REPO/hooks/rule.md" "$T/plugin/hooks/"
  AB="$T/plugin/bin/autobuffer"

  cat > "$T/bin/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  list-clients)
    [ -f "$FAKE/clients" ] || exit 1
    if [ "$3" = '#{client_tty}' ]; then cut -f2 "$FAKE/clients"; else cat "$FAKE/clients"; fi ;;
  display-message)
    if [ "$2" = -p ]; then [ -f "$FAKE/pane-session" ] && cat "$FAKE/pane-session" || exit 1
    else printf '%s\n' "$4" >> "$FAKE/display.log"; fi ;;
  *) exit 1 ;;
esac
EOF
  cat > "$T/bin/who" <<'EOF'
#!/usr/bin/env bash
[ -f "$FAKE/who" ] && cat "$FAKE/who"
EOF
  cat > "$T/bin/ps" <<'PS'
#!/usr/bin/env bash
pid="${@: -1}"
if [ -f "$FAKE/ps" ]; then
  awk -v p="$pid" '$1==p { print $2, $3; f=1 } END { if (!f) print "1 ?" }' "$FAKE/ps"
else echo "1 ?"; fi
PS
  printf '#!/usr/bin/env bash\necho me\n' > "$T/bin/id"
  chmod +x "$T/bin/tmux" "$T/bin/who" "$T/bin/ps" "$T/bin/id"

  local ESC=$'\033'
  osc() { printf '%s]52;c;%s%s\\' "$ESC" "$(printf '%s' "$1" | base64 | tr -d '\n')" "$ESC"; }
  reset() {
    rm -rf "$T/pts" "$T/home" "$T/tty1" "$T"/*.log "$T/clients" "$T/pane-session" "$T/who" "$T/sent" "$T/conf" "$T/ps" "$T/pts9"
    mkdir -p "$T/pts" "$T/home"; : > "$T/pts/1"; : > "$T/pts/2"
  }
  c() {   # c <args…> — run autobuffer in the fake world
    env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" FAKE="$T" AUTOBUFFER_DEV="$T" \
      $([ -n "${NO_TMUX:-}" ] || printf 'TMUX=/fake,1,0') ${TMUX_PANE_SET:+TMUX_PANE=%1} ${EXTRA_ENV:-} bash "$AB" "$@"
  }
  ok()  { [ -n "$quiet" ] || echo "  ok   $1"; }
  bad() { echo "  RED  $1"; fails=$((fails+1)); }
  same() { if [ "$(cat "$2" 2>/dev/null; printf x)" = "$3x" ]; then ok "$1"; else bad "$1 — got: $(od -c "$2" 2>/dev/null | head -3)"; fi; }
  clients2() { printf '/n1\t%s\tA\n/n2\t%s\tB\n' "$T/pts/1" "$T/pts/2" > "$T/clients"; }
  mem="$T/home/.cache/autobuffer/last"

  [ -n "$quiet" ] || echo "bytes"
  reset; clients2
  c 'ssh me@example.com' >/dev/null
  same "every tmux client gets OSC 52 in the ST form" "$T/pts/1" "$(osc 'ssh me@example.com')"
  same "the second client gets the same bytes" "$T/pts/2" "$(osc 'ssh me@example.com')"

  reset; clients2
  printf 'line one\nline two\r\n\n' | c >/dev/null
  same "trailing newlines stripped, inner kept" "$T/pts/1" "$(osc $'line one\nline two')"

  reset; clients2
  if printf '\n\n' | c >/dev/null 2>&1; then bad "empty text must fail"; else ok "empty text fails"; fi
  [ -s "$T/pts/1" ] && bad "empty text wrote to a terminal" || ok "empty text writes nothing"

  reset; printf 'me pts/2 2026-10-12 10:00 (198.51.100.7)\nme tty1 2026-10-12 09:00\nsomeone pts/1 2026-10-12 10:05 (198.51.100.8)\n' > "$T/who"
  : > "$T/tty1"; NO_TMUX=1 c 'x' >/dev/null
  same "no tmux, no own terminal: this user's SSH session from who" "$T/pts/2" "$(osc x)"
  [ -s "$T/tty1" ] && bad "a local console (no remote host) was written" || ok "local console lines are skipped"
  [ -s "$T/pts/1" ] && bad "another user's terminal was written" || ok "another user's SSH session is never written"

  # Outside tmux: the terminal Claude runs in, found up the process chain — and only that one.
  # autobuffer's parent (the shell of Claude's Bash tool) has no tty; its parent, Claude, has one.
  reset; clients2; printf 'me pts/1 2026-10-12 10:00 (198.51.100.7)\n' > "$T/who"
  mkdir -p "$T/pts9"; : > "$T/pts9/9"
  NO_TMUX=1 bash -c 'printf "%s 777 ?\n777 1 pts9/9\n" $$ > "$1/ps"; shift; "$@"; :' _ "$T" \
    env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" FAKE="$T" AUTOBUFFER_DEV="$T" bash "$AB" own >/dev/null
  same "outside tmux: the terminal Claude runs in" "$T/pts9/9" "$(osc own)"
  { [ -s "$T/pts/1" ] || [ -s "$T/pts/2" ]; } && bad "outside tmux, other terminals were written too" || ok "outside tmux, nothing else is written"

  reset
  out="$(NO_TMUX=1 c 'x' 2>&1)"; code=$?
  [ "$code" -ne 0 ] && ok "no terminal fails" || bad "no terminal must fail"
  case "$out" in *"setup skill"*) ok "the failure names the setup skill" ;; *) bad "failure text: $out" ;; esac

  reset; clients2
  c --tty "$T/pts/2" 'only two' >/dev/null
  [ -s "$T/pts/1" ] && bad "--tty also wrote another terminal" || ok "--tty leaves the others alone"
  same "--tty writes its terminal" "$T/pts/2" "$(osc 'only two')"

  reset; clients2
  c 'token-123' >/dev/null; : > "$T/pts/1"
  c --again >/dev/null
  same "--again sends the last text" "$T/pts/1" "$(osc token-123)"
  mode="$(stat -c %a "$mem" 2>/dev/null)"
  [ "$mode" = 600 ] && ok "the memory file is 600" || bad "memory file mode: $mode"
  reset; if c --again >/dev/null 2>&1; then bad "--again with nothing copied must fail"; else ok "--again with nothing copied fails"; fi

  reset; clients2
  echo A > "$T/pane-session"; TMUX_PANE_SET=1 c 'from A' >/dev/null
  echo B > "$T/pane-session"; TMUX_PANE_SET=1 c 'from B' >/dev/null
  : > "$T/pts/1"; : > "$T/pts/2"
  c --tap /n1 >/dev/null
  same "a tap on the client showing A pastes A's text" "$T/pts/1" "$(osc 'from A')"
  [ -s "$T/pts/2" ] && bad "a tap wrote another terminal" || ok "a tap writes only the tapping terminal"
  grep -q '^📋 on the clipboard' "$T/display.log" 2>/dev/null && ok "the tap answers on the status line" || bad "no status-line answer"
  reset; clients2; c --tap /n1 >/dev/null
  grep -q '^📋 nothing copied yet' "$T/display.log" 2>/dev/null && ok "an empty tap says so" || bad "empty tap: $(cat "$T/display.log" 2>/dev/null)"

  reset; clients2
  printf 'send=cat > %s/sent\n' "$T" > "$T/conf"
  EXTRA_ENV="AUTOBUFFER_CONF=$T/conf" c 'via pbcopy' >/dev/null
  same "send= gets the exact text" "$T/sent" 'via pbcopy'
  [ -s "$T/pts/1" ] && bad "send= still wrote OSC 52" || ok "send= writes no escape"
  printf 'send=false\n' > "$T/conf"; rm -f "$mem"
  if EXTRA_ENV="AUTOBUFFER_CONF=$T/conf" c 'lost' >/dev/null 2>&1; then bad "a failing send must fail"; else ok "a failing send fails"; fi
  [ -e "$mem" ] && bad "a failed send was remembered" || ok "a failed send is not remembered"

  reset; clients2
  out="$(c "$(head -c 4000 /dev/zero | tr '\0' a)" 2>&1 >/dev/null)"
  case "$out" in *warning*) ok "a long text warns" ;; *) bad "no warning for a long text" ;; esac

  reset
  out="$(NO_TMUX=1 c --session-start)"
  if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin)["hookSpecificOutput"]; assert d["hookEventName"]=="SessionStart"; c=d["additionalContext"]; assert "Clipboard rule" in c and "not running inside tmux" in c' 2>/dev/null
  then ok "outside tmux: the rule, and the first note says there is no button"; else bad "session-start outside tmux: $out"; fi

  # ---- part 2: the button on a real tmux server ----
  [ -n "$quiet" ] || echo "the 📋 copy button (real tmux)"
  if [ -z "$REAL_TMUX" ]; then bad "tmux is not installed — the button checks cannot run"; rm -rf "$T"; return 1; fi
  local SOCK="$T/sock" H="$T/rhome"
  tm() { env HOME="$H" tmux -S "$SOCK" "$@"; }
  start() {   # a fresh server: sessions "claude" and "other", the person's own status tap
    tm kill-server 2>/dev/null
    local i=0; while [ -S "$SOCK" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
    rm -rf "$H"; mkdir -p "$H"
    tm -f /dev/null new -d -s claude -x 46 -y 24 'sleep 600'
    tm new -d -s other -x 46 -y 24 'sleep 600'
    tm set-option -t other mouse on   # the person's own setting there: a tap must reach their binding
    [ "${1:-}" = unbound ] && tm unbind -n MouseDown1Status || tm bind -n MouseDown1Status display-message "my own tap"
    [ "$(tm list-sessions -F '#S' 2>/dev/null | sort | tr '\n' ' ')" = "claude other " ] || bad "the test tmux did not start (${1:-})"
  }
  r() {   # r <args…> — autobuffer run from Claude's pane in session "claude"
    local pid sid pane
    pid="$(tm display -p '#{pid}')"; sid="$(tm display -p -t claude '#{session_id}')"; pane="$(tm display -p -t claude '#{pane_id}')"
    env HOME="$H" PATH="$(dirname "$REAL_TMUX"):/usr/bin:/bin" TMUX="$SOCK,$pid,${sid#\$}" TMUX_PANE="$pane" bash "$AB" "$@"
  }
  key() { tm list-keys -T root MouseDown1Status 2>/dev/null; }
  opt() { tm show-options -v -t "$1" "$2" 2>/dev/null; }

  start
  out="$(r --session-start)"
  [ "$(opt claude window-status-current-format)" = '📋 copy' ] && ok "Claude's session shows 📋 copy" || bad "no 📋 copy in Claude's session"
  [ "$(opt claude mouse)" = on ] && ok "mouse on in Claude's session" || bad "mouse not on in Claude's session"
  [ "$(opt other mouse)|$(opt other window-status-current-format)|$(opt other window-status-format)" = "on||" ] && ok "the other session is untouched" || bad "the other session changed"
  [ "$(tm show-options -gv mouse)" = off ] && ok "the global mouse setting is untouched" || bad "global mouse changed"
  case "$(key)" in *"--tap '#{client_name}'"*'"display-message \"my own tap\""') ok "the binding keeps the person's own tap for other sessions" ;; *) bad "binding: $(key)" ;; esac
  case "$out" in *"First session"*"📋 copy button is now"*"that copy is the test — do not copy anything else over it"*) ok "the first session tells about the button and tests with the real copy" ;; *) bad "first-session note: ${out:0:300}" ;; esac
  [ -e "$H/.config/autobuffer/welcomed" ] && ok "the first-session mark is written" || bad "no first-session mark"

  out="$(r --session-start)"; first_key="$(key)"
  case "$out" in *"First session"*) bad "the first-session note came twice" ;; *) ok "the first-session note comes once" ;; esac
  [ "$(printf '%s' "$first_key" | grep -o 'my own tap' | wc -l)" = 1 ] && ok "a second start does not nest the binding" || bad "nested: $first_key"

  # Claude Code writes its task title into the pane title, which tmux's default right side
  # shows; at 46 columns a long one used to squeeze the button out of sight.
  tm select-pane -t claude -T '✳ Claude Code — fixing the build on the server'
  res="$(python3 "$TAP" "$SOCK" claude look)"
  [ "$res" = DRAWN ] && ok "with a long Claude title, 📋 copy is still drawn at 46 columns" || bad "button squeezed out: $res"

  # The robot thumb, end to end: hook → binding → --tap → that client's tty.
  ( umask 077; mkdir -p "$H/.cache/autobuffer"; printf 'tap-proof-42' > "$H/.cache/autobuffer/last.claude" )
  res="$(python3 "$TAP" "$SOCK" claude 1 46)"
  [ "$res" = "OSC52 tap-proof-42 ST" ] && ok "a tap on 📋 copy puts the session's text on the tapping terminal (ST)" || bad "robot tap in claude: $res"
  res="$(python3 "$TAP" "$SOCK" other 1 30)"
  [ "$res" = "MSG my own tap" ] && ok "a tap in another session does what the person bound" || bad "robot tap in other: $res"

  r --tmux off >/dev/null
  [ -z "$(opt claude mouse)$(opt claude window-status-current-format)$(opt claude @autobuffer)$(opt claude status-right)" ] && ok "off: Claude's session gets its own look back" || bad "off left options"
  [ "$(key)" = 'bind-key -T root MouseDown1Status display-message "my own tap"' ] && ok "off: the person's own tap is back exactly" || bad "off binding: $(key)"
  [ -z "$(tm show-options -gv @autobuffer-prev 2>/dev/null)" ] && ok "off: no leftover option" || bad "off left @autobuffer-prev"
  grep -qx 'tmux=off' "$H/.config/autobuffer/conf" 2>/dev/null && ok "off is remembered" || bad "off not remembered"
  r --session-start >/dev/null
  [ -z "$(opt claude window-status-current-format)" ] && ok "after off, a new session adds no button" || bad "off did not stick"
  r --tmux on >/dev/null
  [ "$(opt claude window-status-current-format)" = '📋 copy' ] && ok "on: the button is back at once" || bad "on did not apply"
  grep -q '^tmux=' "$H/.config/autobuffer/conf" && bad "on left tmux= in the config" || ok "on clears the remembered off"

  start unbound
  r --session-start >/dev/null
  r --tmux off >/dev/null
  [ -z "$(key)" ] && ok "off with nothing bound before leaves nothing bound" || bad "off unbound: $(key)"

  tm kill-server 2>/dev/null
  rm -rf "$T"
  [ -n "$quiet" ] || { [ "$fails" -eq 0 ] && echo "autobuffer: all green" || echo "autobuffer: $fails red"; }
  [ "$fails" -eq 0 ]
}

case "${1:-}" in
  "") run_checks "$SRC"; exit ;;
  --quiet) run_checks "$2" quiet; exit ;;
  --mutate) ;;
  *) echo "usage: $0 [--mutate]" >&2; exit 2 ;;
esac

run_checks "$SRC" quiet || { echo "the unbroken autobuffer is red — fix that first"; exit 1; }
# Each break is an exact text replacement (old, new, what it breaks); one that does not apply
# exactly once fails the run, so a typo can never pass for a red.
python3 - "$SRC" "$0" <<'EOF'
import os, subprocess, sys, tempfile
src, me = sys.argv[1], sys.argv[2]
text = open(src).read()
BREAKS = [
    (r"""'\033]52;c;%s\033\\'""", r"""'\033]52;c;%s\a'""", "BEL instead of ST"),
    ("""while [ "${payload: -1}" = $'\\n' ]""", "while false", "trailing newlines kept"),
    ("( umask 077; mkdir", "( mkdir", "memory not private"),
    ('    ttys="$only_tty"\n', '    ttys="$(tmux list-clients -F \'#{client_tty}\')"\n', "--tty ignored"),
    ('src="$(session_state "$sess")" && [ -s "$src" ] || src="$STATE"', 'src="$STATE"', "sessions share one memory"),
    ('print d"/"$2', 'print d"/"$1', "who: wrong column"),
    ("$NF ~ /^\\(/ {", "1 {", "who: local consoles taken"),
    ("$1 == u && ", "", "who: another user's terminal taken"),
    ('[ -z "$ttys" ] && [ -z "${TMUX:-}" ] && ttys="$(own_tty)"', "true", "outside tmux, Claude's own terminal not used"),
    ('    [ -n "${TMUX:-}" ] && ttys="$(tmux list-clients', '    ttys="$(tmux list-clients', "outside tmux, tmux clients come first"),
    ('case "$tty" in ""|"?") ;;', 'case "$tty" in "") ;;', "a process without a terminal counts as one"),
    ('  where="via: $send"', '  where="via: $send"; printf x > "$(tmux list-clients -F \'#{client_tty}\' | head -n 1)"', "send= also writes a terminal"),
    ("""printf '%s' "$payload" | sh -c "$send\"""", 'sh -c "$send" </dev/null', "send= gets no text"),
    ("if ! printf '%s' \"$payload\"", "if printf '%s' \"$payload\"", "a failing send passes"),
    ('[ "${#b64}" -gt 4000 ]', "false", "no long-text warning"),
    ('"${tty:-$client}"', '"$client"', "a tap writes the client name, not its tty"),
    ('tmux display-message -c "$client" "${msg##*$\'\\n\'}"', "true", "a tap answers nothing"),
    ('set-option -t "$s" mouse on', 'set-option -g mouse on', "mouse on for every session"),
    ("set-option -t \"$s\" window-status-current-format '📋 copy'", "set-option -g window-status-current-format '📋 copy'", "the button in every session"),
    ('tmux set-option -g @autobuffer-prev "$prev"', "true", "the person's tap is not kept"),
    ('if-shell -F \'#{@autobuffer}\' "$TAP_CMD" "$prev"', 'if-shell -F \'#{@autobuffer}\' "$TAP_CMD"', "other sessions lose the person's tap"),
    ("""    *"--tap '#{client_name}'"*) prev="$(tmux show-options -gv @autobuffer-prev 2>/dev/null)" ;;\n""", "", "a second start nests the binding"),
    ("tmux set-option -t \"$s\" @autobuffer 1 \\;", "tmux", "the session is not marked"),
    ("    tmux set-option -u -t \"$s\" @autobuffer \\; set-option -u -t \"$s\" mouse \\", "    tmux set-option -u -t \"$s\" @autobuffer \\", "off keeps mouse on"),
    ("printf 'bind-key -n MouseDown1Status %s\\n' \"$prev\" | tmux source-file -", "true", "off does not give the tap back"),
    ("        tmux unbind-key -n MouseDown1Status\n", "        true\n", "off leaves our binding when none was before"),
    ('tmux set-option -gu @autobuffer-prev 2>/dev/null', "true", "off leaves @autobuffer-prev"),
    ("conf_set tmux off || exit 1", "true", "off is not remembered"),
    ('[ "$(conf_get tmux)" != off ]', "true", "off does not stick"),
    ("        conf_set tmux || exit 1", "        true", "on keeps the remembered off"),
    ('mkdir -p "$(dirname "$WELCOMED")" && : > "$WELCOMED"', "true", "the first-session note repeats"),
    ("    \\; set-option -t \"$s\" status-right ' %H:%M '", "", "a long title squeezes the button out"),
    ('\\; set-option -u -t "$s" status-right', "", "off keeps the short right side"),
    ('if [ ! -e "$WELCOMED" ]; then', "if false; then", "no first-session note"),
    ('"additionalContext":%s', '"additionalContext":%s,', "session-start JSON broken"),
]
red = 0
for old, new, why in BREAKS:
    n = text.count(old)
    if n != 1:
        print(f"  BAD BREAK ({n} matches): {why}"); sys.exit(1)
    fd, m = tempfile.mkstemp(); os.write(fd, text.replace(old, new).encode()); os.close(fd)
    r = subprocess.run(["bash", me, "--quiet", m], capture_output=True)
    os.unlink(m)
    if r.returncode == 0: print(f"  GREEN with the break: {why}")
    else: print(f"  red  {why}"); red += 1
print(f"mutations: {red} of {len(BREAKS)} reddened")
sys.exit(0 if red == len(BREAKS) else 1)
EOF
