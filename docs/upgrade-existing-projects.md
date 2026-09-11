# Add status line, RTK, and Headroom to an existing project

For repos created with `new-project` (or a copy of `secure-agent-template/`) **before** these three shipped. New projects already get them.

Do **not** run `cp -R ~/.config/secure-agent-template/.` over the old repo. That overwrites `CLAUDE.md`, skills, ignore files, and any `permissions.deny` or Dev Container customizations.

**Where to run this.** File copies and `jq` edits: **Mac Terminal**, not the target Dev Container. `$HOME/.config/secure-agent-template` and `claude-box` live on the host. Checks that need `rtk` / `headroom` / `curl 8787`: inside the agent environment (Case 1: `docker exec` into `claude-box`, or ask Claude to run them; Cases 2/3: Cursor integrated terminal after rebuild).

`claude-box` is a **zsh function this playbook writes into `~/.zshrc`**. It is not an Anthropic command. It starts this playbook’s Docker image and **opens the Claude CLI** — that is Case 1 by design, not a bash prompt.

---

## What you are adding

| Piece | What it does | Daily use |
| --- | --- | --- |
| **Status line** | Claude Code CLI bar: context %, model, effort, token usage | Appears in `claude` / `claude-box`. Needs `jq`. Cursor-only (Case 2) copies the file but does not show it. |
| **RTK** | Shrinks **shell** output before the agent reads it | Automatic via hooks. You do not type `rtk`. |
| **Headroom** | Shrinks **whatever still goes to the LLM** (local proxy on `127.0.0.1:8787`) | Type `claude` as usual. Cursor Agent chat is **not** proxied; it can use Headroom MCP tools. Do not enable Cursor’s Override OpenAI Base URL for subscription models. |

Keep RTK and Headroom both. If the Headroom proxy is down, Claude **fail-closes** (it will not talk to Anthropic directly).

---

## Before you start

On the Mac, from this playbook repo, the template and Case 1 image should already include these features:

```bash
cd /path/to/secure-agent-playbook
./secure-agent-playbook.sh
source ~/.zshrc
```

Skip that if you already ran it **after** status line / RTK / Headroom landed.

Set `P` to the old project and `T` to the template (this checkout is the source of truth):

```bash
P="/path/to/existing-repo"
T="/path/to/secure-agent-playbook/secure-agent-template"
# After a current playbook run you can instead use:
# T="$HOME/.config/secure-agent-template"
```

Repeat per old project. Pick **Case 1** or **Cases 2 and 3** below.

---

## Case 1 (`claude-box`)

The sandbox image already installs `jq`, RTK, and Headroom and starts the proxy in the entrypoint.

### Commands

1. Copy the status-line script and merge Claude settings (keeps your `permissions.deny`):

```bash
mkdir -p "$P/.claude"
cp "$T/.claude/statusline.sh" "$P/.claude/statusline.sh"
jq --arg cmd 'bash "${CLAUDE_PROJECT_DIR:-.}/.claude/statusline.sh"' '
  .statusLine = {type: "command", command: $cmd} |
  .env = (.env // {}) |
  .env.ANTHROPIC_BASE_URL = "http://127.0.0.1:8787"
' "$P/.claude/settings.json" > /tmp/settings.json && mv /tmp/settings.json "$P/.claude/settings.json"
```

2. `grep -qxF '.claude/.headroom_wrap_*' "$P/.gitignore" || echo '.claude/.headroom_wrap_*' >> "$P/.gitignore"`
3. `cd "$P" && claude-box`
4. Confirm the status bar in the Claude CLI (context / model / usage).
5. In a **second** Mac terminal (Claude CLI is not bash):

```bash
docker exec -it "$(docker ps --filter ancestor=claude-secure-sandbox:latest -q | head -1)" bash
rtk --version && rtk init --show
curl -sS http://127.0.0.1:8787/health && headroom doctor
```

### Why

1. Wires the CLI status bar and points Claude at the local Headroom proxy without replacing your deny list.
2. Ignores Headroom wrap artifacts.
3. Starts this playbook’s image (RTK hooks + Headroom proxy + `claude`).
4. Status line only exists in the Claude Code terminal CLI.
5. Confirms RTK hooks and that the proxy is healthy. Case 1 does not publish `8787` to the Mac; use `curl` / `headroom doctor` / `headroom dashboard --no-open` inside the session.

---

## Cases 2 and 3 (Dev Container)

### What this will and will not overwrite

**Safe:** `.claude/skills/`, `CLAUDE.md`, ignore files, Cursor rules, `image` / `features` / `mounts` / `remoteEnv` / `customizations`, other `containerEnv` keys, and `permissions.deny` (the `jq` below only adds keys).

| File / field | Effect |
| --- | --- |
| `.devcontainer/devcontainer.json` → `postCreateCommand` | **Replaced** if you use the full `jq` below. If you already have extra install steps, append instead (see below). |
| `.devcontainer/devcontainer.json` → `postStartCommand` | **Set.** Required so Headroom starts on every attach, not only on first create. |
| `.cursor/mcp.json` | **Replaced** by a plain `cp`. If you already have other MCP servers, merge a `headroom` entry instead. |

`postCreateCommand` runs **once** (container create). `postStartCommand` runs **every** start. If you only have `postCreate`, the proxy dies when the container is reused — Claude then fail-closes until you start it by hand.

### Commands

1. `P` and `T` as above.
2. Copy installer, proxy starter, and status-line script:

```bash
mkdir -p "$P/.devcontainer" "$P/.claude"
cp "$T/.devcontainer/setup-agent-tools.sh" "$P/.devcontainer/"
cp "$T/.devcontainer/start-headroom.sh" "$P/.devcontainer/"
cp "$T/.claude/statusline.sh" "$P/.claude/statusline.sh"
```

3. Headroom MCP for Cursor Agent — **only if** you do not already have other MCP servers:

```bash
mkdir -p "$P/.cursor"
cp "$T/.cursor/mcp.json" "$P/.cursor/mcp.json"
```

Otherwise add this under `mcpServers` in the existing file:

```json
"headroom": {
  "command": "/usr/local/bin/headroom",
  "args": ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"]
}
```

4. Patch `devcontainer.json`. **Case 3 (`both`):**

```bash
jq '
  .containerEnv = (.containerEnv // {}) |
  .containerEnv.HEADROOM_BEACON = "off" |
  .containerEnv.DO_NOT_TRACK = "1" |
  .forwardPorts = ((.forwardPorts // []) + [8787] | unique) |
  .portsAttributes = (.portsAttributes // {}) |
  .portsAttributes["8787"] = {"label": "Headroom dashboard", "onAutoForward": "silent"} |
  .postCreateCommand = "bash .devcontainer/setup-agent-tools.sh both" |
  .postStartCommand = "bash .devcontainer/start-headroom.sh"
' "$P/.devcontainer/devcontainer.json" > /tmp/dc.json && mv /tmp/dc.json "$P/.devcontainer/devcontainer.json"
```

**Case 2:** same command, but `setup-agent-tools.sh cursor` instead of `both`.

If `postCreateCommand` already runs `setup-agent-tools.sh` and you have extra steps, **do not** use that `jq`. Keep your create command and add only:

```json
"postStartCommand": "bash .devcontainer/start-headroom.sh"
```

To keep a custom create script and still install tools:

```bash
bash your-existing-setup.sh && bash .devcontainer/setup-agent-tools.sh both
```

5. **Case 3 only** — status line + Headroom URL (skip on Case 2):

```bash
jq --arg cmd 'bash "${CLAUDE_PROJECT_DIR:-.}/.claude/statusline.sh"' '
  .statusLine = {type: "command", command: $cmd} |
  .env = (.env // {}) |
  .env.ANTHROPIC_BASE_URL = "http://127.0.0.1:8787"
' "$P/.claude/settings.json" > /tmp/settings.json && mv /tmp/settings.json "$P/.claude/settings.json"
```

6. `grep -qxF '.claude/.headroom_wrap_*' "$P/.gitignore" || echo '.claude/.headroom_wrap_*' >> "$P/.gitignore"`
7. In Cursor: Command Palette → **Dev Containers: Rebuild Container** (first rebuild can take several minutes: Headroom/Python). If you only added `postStartCommand` and the scripts are already on disk, **Reload Window** / re-attach is enough for the next start; rebuild if `rtk` or `headroom` is missing.
8. In the **container** terminal:

```bash
rtk --version && rtk init --show
curl -sS http://127.0.0.1:8787/health
headroom doctor
```

### Why

1. Template vs old repo paths.
2. `setup-agent-tools.sh` installs `jq` (status line), RTK, Headroom, and agent hooks. `start-headroom.sh` starts the proxy. `statusline.sh` is the CLI bar.
3. Cursor Agent is not wrapped by the proxy; MCP is how it can compress / retrieve / stats.
4. Create installs tools; **start** brings the proxy up every attach; port `8787` is the dashboard on the Mac.
5. Claude Code reads `statusLine` and `ANTHROPIC_BASE_URL` from project settings.
6. Ignore wrap files.
7. Rebuild actually runs `postCreate` so binaries and hooks exist.
8. RTK: Claude hook `[ok]`; add Cursor with `rtk init -g --agent cursor --auto-patch --no-trust-filters` if `rtk init --show` says Cursor hook not found. Headroom: `"status":"healthy"` and **proxy pass**. `shell env` unset in bash is expected — Claude is routed via `.claude/settings.json`. A `savings` warning before any real Claude request is normal.

---

## Confirm they are working (not just installed)

**Status line.** Open `claude` (Case 3 integrated terminal, or `claude-box`). You should see the bar. Blank bar usually means `jq` is missing: Case 1 re-run `./secure-agent-playbook.sh`; Case 3 rebuild so `postCreate` installs `jq`.

**RTK.** Totals only count Bash/Shell the **agent** ran (not you typing, not Read/Grep/Glob). After a few agent shell commands:

```bash
rtk gain
rtk gain --graph
```

**Headroom.** Send one real `claude` prompt, then:

```bash
curl -sS http://127.0.0.1:8787/stats
headroom doctor
```

Cases 2 and 3: on the Mac open [http://127.0.0.1:8787/dashboard](http://127.0.0.1:8787/dashboard). Case 1: stay inside the session (`stats` / `doctor`).

**Case 2:** Cursor-hosted models will not show proxy savings. Check `health` + RTK hooks; use Headroom MCP from Cursor.

If Claude cannot reach Anthropic: proxy is down. `bash .devcontainer/start-headroom.sh` (or a new `claude-box`). Logs: `~/.headroom/proxy.log`.

---

## Next time you open the project

| | Auto? |
| --- | --- |
| **RTK** | Yes. Hooks persist. Nothing to start. |
| **Status line** | Yes, whenever you use the Claude CLI and `jq` is installed. |
| **Headroom** | Only if `postStartCommand` is `bash .devcontainer/start-headroom.sh` (Cases 2/3) or you use `claude-box` (Case 1 entrypoint). |

If you open a Dev Container and `curl -sS http://127.0.0.1:8787/health` fails, `postStart` is missing or did not run. Start it once with `bash .devcontainer/start-headroom.sh`, then add `postStartCommand` so you do not have to.

Optional: copy the Status line / RTK / Headroom sections from [`secure-agent-template/environment-notes.md`](../secure-agent-template/environment-notes.md) into the old project’s notes file. Do not overwrite project-specific notes.
