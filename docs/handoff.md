# Handoff (last update 2026-10-12)

## START HERE — next session: the owner reviews the descriptive texts, then the directory

State: public at github.com/gvmatrosov/autobuffer, version 0.1.1, checked on the owner's phone
(copy, tap, button at 46 columns, clean Claude outside the owner's home). Trial leftovers are all
removed (sessions cc4/cc5, the trial config, the owner's tap binding restored exactly).

Owner's plan (2026-10-12): in a new session, go through every text a stranger reads and decide
the wording. The texts, all English:
- `.claude-plugin/plugin.json` `description` + `keywords`, `.claude-plugin/marketplace.json`
  `description` — what the directory and `/plugin` show;
- `README.md` — the install line and "What happens";
- `hooks/rule.md` — the rule Claude gets every session;
- the first-session note inside `bin/autobuffer` (`session_start`);
- `skills/setup/SKILL.md` — its `description` decides when Claude opens it.
Explain each to the owner in plain Russian; change wording only after the owner's say. Any change
people should get → bump `version` (repo rule), run tests + --mutate + validate, commit, push.

Then: submit to Anthropic's plugin directory. Found by search, not yet opened: a portal at
claude.ai/directory/manage (paid plans, a plugin is submitted as a GitHub repo) and a form at
clau.de/plugin-directory-submission. Verify the current process before acting; submitting is the
owner's step (their account).

Open, owner's call: the memory note `evolupe-plugins` in the owner's harness still lists cop as
part of evolupe-terminal (the harness was not touched this session). The owner's own `cop` has the
same who-fallback flaw fixed here (writes to every SSH session); harmless on single-user machines.

---

autobuffer began as `cop` inside the owner's evolupe marketplace (evolupe-terminal) and was split
out the same day (owner: "делаем отдельным. autobuffer") — a separate plugin, own repo, so it can
go public without evolupe's privacy scrub and is untouched by evolupe's rename to blox.

## Owner decisions
- Nothing beyond the owner's own setup (the clipboard rule + a tmux tap button), plus the setup
  skill that builds the same for another stack. No mod, no reading of Claude's answers.
- The button appears by itself in tmux, only in Claude's tmux session (owner's idea: mouse on for
  that session only), nothing written to tmux config; 📋 in front of "copy".
- One-command install; the first session says what was added and asks for one test paste.

## Verified
- tests/check.sh: bytes (fake tmux/who, files as ttys) + the button on a real tmux server with a
  robot thumb (tests/tap.py) tapping the status line at 46 columns; --mutate: 35 breaks, all red.
- Plugin `bin/` is on the Bash tool's PATH; SessionStart additionalContext reaches the model.
- At 46 columns the button is drawn and tappable even with Claude's long task title (Claude's
  session's right side is the clock only — see below).
- On the owner's phone (Termius), 2026-10-12, the autobuffer build: the attach command copied by
  autobuffer arrived whole; in a separate tmux server (`-L abphone`) where `--session-start` had
  put the button into session "claude" only, a tap on 📋 copy pasted exactly the seeded text.

- Clean config (a separate CLAUDE_CONFIG_DIR holding only a copy of the credentials, made by the
  owner by hand; deleted afterwards): `claude plugin install autobuffer --marketplace
  gvmatrosov/autobuffer` installed from the private GitHub repo in one step (git uses the owner's
  GitHub login); a headless Claude with no owner rules copied the asked-for command by itself and
  ran the first-session note. Found there: the test string overwrote the real copy — fixed, the
  reply's own copy is now the test (re-run: Claude copied a link and asked to paste that).
- Name: no Claude Code plugin, clipboard or terminal tool is called autobuffer; npm and PyPI hold
  unrelated libraries with no `autobuffer` command; GitHub repos with the name are unrelated.

- Public since 2026-10-12 (owner's go; history scanned first: noreply author, nothing private).
  A stranger's install — empty CLAUDE_CONFIG_DIR and HOME, git with no global config and no
  GitHub login — `claude plugin install autobuffer --marketplace gvmatrosov/autobuffer` cloned,
  validated and installed; bin/autobuffer kept its executable bit.

- Outside tmux (found from the owner's question "what if not in tmux?"): the `who` fallback wrote
  to EVERY SSH session on the machine, other users' included — a copied token could land on a
  stranger's clipboard on a shared server (the owner's own cop has the same fallback; the owner's
  machines are single-user). Now: inside tmux its clients; outside, the terminal of the nearest
  ancestor process that has one (Claude's); then tmux clients; last `who` filtered to this user.
  Checked live: outside tmux it chose exactly Claude's pane tty.
- Incident while making that change (2026-10-12): a nested heredoc in an inline edit command
  closed early and bash ran the rest with `$T` empty, overwriting `/usr/bin/id` with a test
  stand-in and leaving junk in `/`. Restored with `apt-get install --reinstall coreutils`
  (`dpkg --verify` clean; no service restarted), junk removed. Lesson: edit scripts go to a file,
  never through nested heredocs.

- Owner's own trial (empty config, 2026-10-12): outside tmux, Claude put a link on the clipboard
  right after `/plugin install`, WITHOUT a restart — the engine picks the plugin up live.
- Found on the owner's phone: no 📋 copy at 46 columns. Claude Code writes its task title into the
  pane title, tmux's default right side shows it (21 chars) plus time and date, and the window
  list gets no room. The tests missed it (pane title was "sleep"). Fixed: Claude's session's
  right side is the clock only; a robot check looks for "copy" with a long title.

- Owner's trial in a tmux session of their own server (cc4): the "empty" Claude ran in a folder
  under the owner's home, and Claude Code loaded the home's `.claude/CLAUDE.md` as PROJECT
  instructions (CLAUDE_CONFIG_DIR does not stop that) — so it copied with the owner's own cop and
  the 📋 copy button, reading autobuffer's memory, had nothing. Not a plugin bug: a stranger has
  no other clipboard tool or rule. Trials of a clean Claude must run in a folder outside the
  owner's home (/tmp/...), as the headless clean runs did. The tap path itself was replayed for
  the owner's terminal in cc4 and delivered the link.

## Not yet verified
- An already-running session right after install: driving a second interactive Claude through
  tmux keys is refused by the auto-mode classifier. README says to restart Claude Code after
  installing, which holds whatever the engine does.
- The setup skill live; `send=` on a real Mac/WSL.

## Next
- Submit to Anthropic's plugin directory.
