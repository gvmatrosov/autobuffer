# autobuffer

Whatever you must paste lands on your clipboard. For Claude Code over SSH — above all from a
phone — where selecting a long command off a narrow screen turns its wraps into real newlines and
drops spaces.

## Install

In Claude Code:

```
/plugin install autobuffer --marketplace gvmatrosov/autobuffer
```

Then restart Claude Code. That is all: Claude Code downloads the plugin into its own plugins
folder and turns it on for every folder you work in; the rule and the button arrive with the next
session start. Claude Code only (the plugin ships a small program), not claude.ai.

## What happens

1. **Every session start** (and after `/clear`) the plugin hands Claude one rule: whatever you are
   expected to paste — a command, a link, a token, a path — Claude puts on your clipboard with
   `autobuffer` and says in one line what is there. It lives in no file of yours; uninstall the
   plugin and the rule is gone.
2. **Inside tmux**, the same start puts **📋 copy** in the middle of the status line of the tmux
   session Claude runs in. A tap puts the last copied text on the clipboard again — the clipboard
   is easy to overwrite, and the link Claude copied ten minutes ago has scrolled away. Only the
   device that tapped gets it; each tmux session remembers its own last text.
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
(a tap needs it; in a desktop terminal, selecting text there then needs Shift held). Your other
sessions keep their own look and mouse setting, and a tap on their status line does what it did
before. `autobuffer --tmux off` takes it out everywhere and remembers; `autobuffer --tmux on`
brings it back.

## Why it works where plain OSC 52 does not

- tmux passes OSC 52 on only to terminals it believes have a clipboard. Termius reports
  `TERM=linux`, so tmux drops it silently. autobuffer writes the escape straight into the pty of
  each attached terminal, past tmux (outside tmux: the SSH sessions `who` lists).
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
`tests/check.sh --mutate` breaks autobuffer at 29 spots, one at a time; each must turn a check red.

MIT license.
