## Status line (Claude Code CLI)

`.claude/statusline.sh` is wired from `.claude/settings.json`. In the **Claude Code terminal CLI** it shows running context, model, effort, and token usage.

It needs `jq`. If the bar is blank, rebuild the Dev Container (Case 2) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1).

## RTK (token-saving shell proxy)

[RTK](https://github.com/rtk-ai/rtk) is installed in this container. You do not type `rtk` yourself.

When Claude Code runs a **Bash** command, a hook may rewrite it (`git status` → `rtk git status`). RTK runs the real command, compresses the output, and the agent reads the short version. Built-in tools (Read, Grep, Glob) are not rewritten.

This cuts **bash output** the model has to read. It is not the same as cutting your bill by that percentage.

See savings (inside this container, after the agent has run some shell commands):

```bash
rtk gain          # totals
rtk gain --graph  # with a simple chart
rtk init --show   # confirm the hook is installed
```

If `rtk` is missing, rebuild the Dev Container (Case 2) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1).

## Headroom (token compression proxy)

[Headroom](https://github.com/headroomlabs-ai/headroom) is already installed in this container. You do not type `headroom wrap` for daily work.

**What it is.** A local proxy on `127.0.0.1:8787` that compresses bulky context (tool output, logs, files) before it reaches the model. Same answers, fewer tokens. It runs on this machine; prompt content is not sent anywhere to be compressed. Anonymous Headroom telemetry is off.

**RTK vs Headroom.** RTK shrinks **shell** output before the agent reads it. Headroom shrinks **whatever still goes to the LLM**. Keep both.

### Daily use

Claude Code (`claude` in the terminal, or the VS Code sidebar extension) is already routed through the proxy. Type `claude` as usual.

If the proxy is down, Claude **fail-closes** (it will not talk to Anthropic directly). Restart it, then try Claude again:

```bash
bash .devcontainer/start-headroom.sh
```

Case 1 (`claude-box`) starts the proxy in the container entrypoint. Case 2 starts it when the Dev Container starts.

### Check that it is working

Inside the container (VS Code integrated terminal, or inside `claude-box`):

```bash
curl -sS http://127.0.0.1:8787/health
headroom doctor
```

`health` should say `"status":"healthy"`. `doctor` should show **proxy pass**. The `savings` warning until you have sent a real Claude request is normal.

### Dashboard (live savings)

After Claude has made at least one request through the proxy:

**Case 2** (Dev Container): port `8787` is forwarded to your Mac. In a browser on the Mac open:

[http://127.0.0.1:8787/dashboard](http://127.0.0.1:8787/dashboard)

You should see requests and tokens saved.

**Case 1** (`claude-box`): the proxy is loopback inside that container, not published to the Mac. Check from inside the session:

```bash
curl -sS http://127.0.0.1:8787/stats
headroom doctor
headroom dashboard --no-open
```

### If Headroom is missing

Rebuild the Dev Container (Case 2) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1). Then `bash .devcontainer/start-headroom.sh`. Logs: `~/.headroom/proxy.log`.

## Give this project its own VS Code colors

Workspace settings live in this folder's `.vscode/settings.json`. They apply only to this project, and they stick: every time you open the folder (on the Mac or in the Dev Container) they come back. Other VS Code windows keep their own theme.

**Whole theme.** Cmd+, → **Workspace** tab (not User) → search `Color Theme` → pick one.

**Just the title bar** (easier to tell windows apart while keeping your usual theme). Command Palette → `Preferences: Open Workspace Settings (JSON)` and add:

```json
{
  "workbench.colorCustomizations": {
    "titleBar.activeBackground": "#5a2d82",
    "titleBar.activeForeground": "#ffffff",
    "titleBar.inactiveBackground": "#3d1f59"
  }
}
```

On macOS the title bar must be VS Code's own (`"window.titleBarStyle": "custom"`, the default in current versions) for these colors to show.

`.vscode/settings.json` is not gitignored. Commit it if you want collaborators to see the same colors. Otherwise add `.vscode/settings.json` to `.gitignore`.

## Remember git credentials

**Case 2 (VS Code Dev Container): use your Mac's Keychain.** The Dev Containers extension forwards your Mac's git credential helper into the container. You don't store anything in the container.

1. On the Mac, once: `git config --global credential.helper` should print `osxkeychain`. If it prints nothing, run `git config --global credential.helper osxkeychain`.
2. Do one `git pull` or `git push` from Mac Terminal in any HTTPS repo. Paste your token (from 1Password) when asked. Keychain saves it.
3. Inside the Dev Container, `git push` now works without a prompt.

**Case 1 (`claude-box`): run git from Mac Terminal**, outside the container. `claude-box` has no credential helper and no SSH keys, on purpose.

**Avoid `git config --global credential.helper store` inside a container.** It writes the token in plain text to `~/.git-credentials`, where Claude can read it. In a Dev Container that file is also lost on every rebuild. In `claude-box` it would sit on the shared auth volume that every project uses.
