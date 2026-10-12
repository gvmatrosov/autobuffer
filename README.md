# autobuffer

Everything Claude gives you to copy lands on your clipboard by itself. For Claude Code over SSH —
above all from a phone — where selecting a long command off a narrow screen turns its wraps into
real newlines and drops spaces.

## Install

In Claude Code (2.1.275 or later):

```
/plugin install autobuffer --marketplace gvmatrosov/autobuffer
```

Claude Code shows the plugin, you pick where to install it, and it says whether the plugin is
active at once; if it asks, run `/reload-plugins`. The rule and the button arrive with the next
session start (or `/clear`). Claude Code only (the plugin ships a small program), not claude.ai
chat or Cowork. To remove it: `/plugin`, the Installed tab.

## What happens

1. **Every session start** (and after `/clear`) the plugin hands Claude one rule: whatever you are
   expected to paste — a command, a link, a token, a path — Claude puts on your clipboard with
   `autobuffer` and says in one line what is there. It lives in no file of yours; uninstall the
   plugin and the rule is gone. The rule is a request, not a lock: Claude follows it like any
   instruction, and nothing forces it — if it ever forgets, ask.
2. **Without tmux** the rule works the same; there is just no button (the setup skill can build
   one for another setup). **Inside tmux**, the same start puts **📋 copy** in the middle of the
   status line of the tmux session Claude runs in — by itself, not by asking Claude. A tap puts the last copied text on the
   clipboard again — the clipboard is easy to overwrite, and the link Claude copied ten minutes
   ago has scrolled away. Only the device that tapped gets it; each tmux session remembers its
   own last text. If no terminal is attached to tmux when Claude copies (a phone app in the
   background has lost its connection), the text is kept and Claude says so; a tap after you are
   back delivers it.
3. **The first session** after installing, Claude says what was added and asks you to paste a test
   text once. OSC 52 — the escape that fills a terminal's clipboard — never reports back, so only
   your paste proves it works.
4. **If it does not work** (Claude runs on the computer with the screen, WSL, a terminal without
   OSC 52, no tmux and you want a button anyway), Claude offers the **setup** skill
   (`/autobuffer:setup`): it finds the road to your clipboard for your actual setup — `pbcopy`,
   `wl-copy`, `clip.exe`, a small script of its own — writes it as `send=<command>` in
   `~/.config/autobuffer/conf` after your yes, and proves it with a paste.

## The button, exactly

Only in Claude's own tmux session and only in tmux's memory — nothing is written to your tmux
config. In that session the window list is replaced by "📋 copy", centred, and mouse is turned on
(a tap needs it; in a desktop terminal, selecting text there then needs Shift held), and its right
side shrinks to the clock — Claude Code writes its task title there, and on a phone-width screen
the usual right side leaves the button no room. Your other sessions keep their own look and mouse setting, and a tap on their status line does what it did
before. `autobuffer --tmux off` takes it out everywhere and remembers; `autobuffer --tmux on`
brings it back.

## What it touches

- **Network: nothing.** autobuffer sends no data anywhere; the text goes only to your own
  terminal (or to the `send=` command you approved).
- **Credentials: none read.** autobuffer reads no keys, tokens or passwords of yours. A token
  reaches it only when Claude copies one for you to paste, and then only your clipboard gets it.
- **Your terminals:** the clipboard escape is written to the terminals attached to Claude's tmux
  server, or outside tmux to the terminal Claude runs in. Never another user's.
- **Files:** the last copied text in `~/.cache/autobuffer/` (mode 600), a settings file
  `~/.config/autobuffer/conf` (only after `--tmux off` or the setup skill), and a mark
  `~/.config/autobuffer/welcomed` so the first-session note is said once.
- **tmux, in memory only:** per-session options of Claude's session and one shared binding for a
  tap on the status line, which keeps your own tap for every other session.
- **Claude's context:** at each session start, the rule above (about 200 words).

## Why it works where plain OSC 52 does not

- tmux passes OSC 52 on only to terminals it believes have a clipboard. Termius reports
  `TERM=linux`, so tmux drops it silently. autobuffer writes the escape straight into the pty of
  each attached terminal, past tmux. Outside tmux it writes to the terminal Claude itself runs in;
  it never writes to another user's terminal.
- Termius takes only the ST-terminated form (`ESC \`), not the BEL form most tools send.
- Trailing newlines are stripped: a newline on the clipboard would make the paste run the command.
- The last text is kept in `~/.cache/autobuffer/` with mode 600 — tokens get copied too.

```
autobuffer 'ssh -p 22 me@example.com'
printf '%s' "$url" | autobuffer
autobuffer --again        # the last text again
```

## Checks

`tests/check.sh` — the exact bytes each terminal receives; the button on a real tmux server with a
robot thumb that attaches like a 46-column phone and taps the status line end to end.
`tests/check.sh --mutate` breaks autobuffer at 38 spots, one at a time; each must turn a check red.

MIT license.
