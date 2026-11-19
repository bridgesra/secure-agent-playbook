# Secure Agent Playbook — agent instructions

Source for `secure-agent-playbook.sh` (Mac installer, Case 1 image, zsh helpers) and
`secure-agent-template/` (what `new-project` copies). Target: Apple Silicon Mac, zsh, OrbStack.

## Where changes go
- Project defaults: edit `secure-agent-template/`, never `~/.config/secure-agent-template/`.
- Root `.claude/` and `.devcontainer/` configure *this* repo, not generated projects.
- Behavior change → update README.md, the template's environment-notes.md, and
  docs/upgrade-existing-projects.md (existing projects need a migration path).

## Tests
- Run `./tests/run.sh` after any change to the installer, template, or tests.
- Follow tests/POLICY.md: when a test fails, fix production code. Do not edit, weaken,
  or delete a test's assertions without my explicit OK. New checks must be proven
  (sabotage → fail → revert → pass).

## Shell and security
- Bash: `set -euo pipefail` (except scripts that must never fail container start),
  idempotent and safe to re-run; zsh helpers must pass `zsh -n`.
- Never hardcode credentials, mount host secrets, or loosen `permissions.deny`.
  Keep Headroom telemetry off.
- Prefer small, focused changes.

## Housekeeping
- Don't read `.claudeignore` paths unless asked.
- After files are moved/added/deleted, run the folder-explore skill to refresh docs/repo-map.md.