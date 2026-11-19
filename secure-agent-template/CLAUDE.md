# Project instructions

## Project
<!-- One line on what this is, plus build/test/lint commands. Run /init to draft it. -->

## Environment (from secure-agent-playbook)
- You run in a container; only this folder is shared with the host.
- Shell commands may be rewritten to `rtk ...` to compress output. That's expected; don't undo it.
- API calls go through a local Headroom proxy (127.0.0.1:8787). On connection errors,
  run `bash .devcontainer/start-headroom.sh` rather than changing ANTHROPIC_BASE_URL.
- Never read or print credentials: `.env*`, `~/.git-credentials`, `~/.claude/.credentials.json`.
  Don't run `git push` or change git credential settings unless asked.

## Working style
- Read docs/repo-map.md first and open only the files you need. Refresh it with the
  folder-explore skill after moving, adding, or deleting files.
- Small, focused changes; no large refactors unless asked.
- Use strict types where the language has them. Don't hardcode secrets.
- Verify with the project's tests before saying something is done.
- Don't read `.claudeignore` paths unless asked.