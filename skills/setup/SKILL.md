---
name: setup
description: Find the way from this machine to the clipboard of the device the person types on, set autobuffer up for it, prove it with one real paste, and build an equivalent of the 📋 copy button where tmux is not used. Use when the person asks to set up copying / the clipboard / the copy button, when autobuffer answers "found no attached terminal", when a paste of something autobuffer copied arrives empty or broken, or when the person complains that copying commands or links off the screen mangles them.
---

# setup — the clipboard, built for this person's real stack

`autobuffer` (this plugin's `bin/`) puts text on the clipboard of the device the person is typing
on. Out of the box it does what works for SSH from a phone app like Termius: an OSC 52 escape,
ST-terminated, written straight into the pty of every attached terminal — past tmux, which drops
OSC 52 for terminals it thinks have no clipboard (Termius says `TERM=linux`). Inside tmux it also
puts a 📋 copy button in the status line of Claude's session by itself. Other stacks need a
different road. Your job: find this person's road, set it, prove it.

This skill is a request, not a lock: nothing checks that you followed it. The paste test at
step 3 is what makes the result true.

## 1. See the stack — detect first, ask only what cannot be seen

```sh
echo "TERM=$TERM TERM_PROGRAM=${TERM_PROGRAM:-} SSH=${SSH_CONNECTION:+yes} TMUX=${TMUX:+yes} STY=${STY:-} ZELLIJ=${ZELLIJ:-}"
uname -a; grep -qi microsoft /proc/version 2>/dev/null && echo WSL
tmux list-clients -F '#{client_tty} #{client_termname}' 2>/dev/null
who
command -v pbcopy wl-copy xclip xsel clip.exe qrencode 2>/dev/null
cat "${XDG_CONFIG_HOME:-$HOME/.config}/autobuffer/conf" 2>/dev/null
```

What you cannot see from here is the app on the far end. Ask in one line: "What do you type in
from — which app, on which device (e.g. Termius on iPhone, iTerm2 on a Mac, Windows Terminal)?"

## 2. Pick the road

| Where Claude runs | Far end | Road |
|---|---|---|
| over SSH (tmux, screen or bare) | an app that takes OSC 52: Termius, Blink, iTerm2 (its "Applications in terminal may access clipboard" setting on), Windows Terminal, WezTerm, kitty, Alacritty, foot | the default — nothing to set |
| on the same computer as the screen | any | the machine's own tool: `send=pbcopy` (macOS), `send=wl-copy` (Wayland), `send=xclip -selection clipboard` (X11), `send=clip.exe` (WSL) |
| over SSH | an app without OSC 52 (macOS Terminal.app; GNOME Terminal and other VTE terminals — check with the paste test) | no road to its clipboard from the server: say so honestly and fall back (below) |
| anything odd (mosh, a web terminal, nested SSH, a container) | — | try the default first; if the paste test fails, write a small script for this case and point `send=` at it |

The table is a starting guess, not the authority — terminals change. The paste test is.

`send=` goes in `${XDG_CONFIG_HOME:-$HOME/.config}/autobuffer/conf` as one line
`send=<shell command that reads the text on stdin>`. Show the person the line and get a yes before
writing it. A script you write for `send=` lives next to it (`~/.config/autobuffer/send`),
executable, with a comment saying why it exists.

**Fallback when no road exists:** for a link, a QR code the person scans
(`qrencode -t ANSIUTF8 '<url>'`, if installed); for a command, write it to a short-named file
(`~/run-me.sh`) and tell them to run it by name. No extra rule is needed for later sessions: the
rule autobuffer hands every session already says to offer this skill once when it fails.

## 3. Prove it with a real paste — never claim it works

OSC 52 never reports back: a terminal that drops it looks exactly like one that took it.

1. `autobuffer 'autobuffer-test-<4 random letters>'`
2. Ask: "Paste what is on your clipboard now (long-press → Paste on a phone)."
3. Exactly equal → it works. Empty or old text → this road does not work; back to step 2. Cut in
   the middle → the terminal cut a long escape; long texts may need the file fallback.

Only after an exact paste say "autobuffer works here".

## 4. The repeat button

The clipboard is easy to overwrite, and the link Claude copied ten minutes ago has scrolled away,
so a one-tap "copy it again" matters.

- **tmux:** nothing to build. At every session start autobuffer puts "📋 copy" in the middle of
  the status line of Claude's own tmux session (that session's window list is replaced, mouse is
  on there; other sessions keep their look; nothing is written to the tmux config). A tap reaches
  only the terminal that tapped. `autobuffer --tmux off` removes it for good, `--tmux on` brings
  it back. Prove it like the road: copy a test text, ask them to copy something else on their
  device, tap 📋 copy, paste.
- **Other multiplexers (GNU screen, zellij) or none:** if the person wants the button, build its
  equivalent for their setup — a status-line click or a key that runs `autobuffer --again` (it
  repeats the last text to every attached terminal; `--tty <pty>` narrows it to one). Explain what
  it changes in their setup and get a yes first; prove it with the same paste test.
