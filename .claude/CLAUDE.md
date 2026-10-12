# autobuffer — working rules for this repo

A public Claude Code plugin (this repo is also its own one-plugin marketplace). Written in
English; the owner talks in Russian.

- **Nothing private ships**, in files or history: no IPs, hostnames, real names, tokens, paths of
  the owner's machines. Tests use example.com and 198.51.100.x.
- **Lock vs request.** The 📋 copy button and the SessionStart hook fire by themselves (locks); the
  clipboard rule and the setup skill are requests to Claude. Say which is which in docs.
- **Before every commit:** `tests/check.sh` green, `tests/check.sh --mutate` all red (add a break
  for every new behaviour), `claude plugin validate .`.
- **The real proof is a paste on a phone**: OSC 52 never reports back. Never claim it works on a
  device nobody pasted on.
- **Never test on the owner's live tmux server**: use a private socket (`tmux -S <file>`), as the
  tests do. The owner's own harness has its own clipboard tool and button; the plugin is never run
  next to them for the same person.
- **Bump `version` in `.claude-plugin/plugin.json` with every change people should get**:
  Claude Code updates an installed plugin only when the version changes (seen 2026-10-12).
