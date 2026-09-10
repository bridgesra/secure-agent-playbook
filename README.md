# Secure Agent Playbook

Run **Claude Code**, **Cursor**, or **both** inside Docker containers on your Mac so agent commands never touch your host filesystem, SSH keys, or cloud credentials directly.

**Audience:** Apple Silicon Mac, `zsh`, comfortable with Terminal. This guide does not cover Linux or Windows.

---

## Pick your case

| Case                | You use              | Containers        | Daily commands                                          |
| ------------------- | -------------------- | ----------------- | ------------------------------------------------------- |
| **1 — Claude only** | Claude Code CLI      | 1 (`claude-box`)  | `new-project foo claude` → `claude-box`                 |
| **2 — Cursor only** | Cursor editor        | 1 (Dev Container) | `new-project foo cursor` → Reopen in Container          |
| **3 — Both**        | Cursor + Claude Code | 1 (Dev Container) | `new-project foo both` → Reopen in Container → `claude` |

```
CASE 1 — Claude only                CASE 2 — Cursor only
┌─────────────────────┐             ┌─────────────────────┐
│  Mac Terminal       │             │  Cursor (native UI) │
│    └── claude-box   │             │    └── Dev Container│
│         └── claude  │             │         └── server  │
└─────────────────────┘             └─────────────────────┘

CASE 3 — Both (one container)
┌──────────────────────────────────────────────┐
│  Cursor (native UI)                          │
│    └── Dev Container                         │
│          ├── Cursor server + extensions      │
│          └── claude CLI  ← type `claude` here│
└──────────────────────────────────────────────┘
```

> **Case 1 does not require Cursor.** You only need Docker/OrbStack and Terminal.
>
> **Security note:** Containers protect your **host** (`~/.ssh`, `~/.aws`, etc.). Your **project folder** is intentionally shared and writable. Ignore files reduce what AI sees; `permissions.deny` in `.claude/settings.json` hard-blocks reads. Neither is a perfect guarantee against a malicious repo.

---

## Before you start

Complete this checklist before your first project.

### 1. Install Homebrew (if you don't have it)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to add Homebrew to your PATH.

### 2. Clone this repo

You need the **full repository** — not just this README. The setup script and template folder live here.

```bash
mkdir -p ~/repos
cd ~/repos
git clone git@github.com:bridgesra/secure-agent-playbook.git
cd secure-agent-playbook
```

Use your fork URL instead of the example above if needed.

### 3. Confirm prerequisites

| Tool                                   | Required for     | Install                                                                        |
| -------------------------------------- | ---------------- | ------------------------------------------------------------------------------ |
| **OrbStack** (or Docker Desktop)       | All cases        | `brew install orbstack`                                                        |
| **Cursor**                             | Cases 2 & 3 only | [cursor.com](https://cursor.com)                                               |
| **Anysphere Dev Containers** extension | Cases 2 & 3 only | Cursor → Extensions → search `Dev Containers` by "Anysphere" (not Microsoft's) |
| **Cursor shell command**               | Cases 2 & 3 only | Cursor → Command Palette → `Shell Command: Install 'cursor' command in PATH`   |

Launch OrbStack (or Docker Desktop) and leave it running. Approve helper tools when prompted and choose Docker if asked. Verify with:

```bash
docker ps
```

You should see a (probably empty) table of containers.

### 4. Shell

This guide assumes **zsh** (macOS default). The setup script adds helpers to `~/.zshrc`. If you use bash or fish, adapt the commands or switch to zsh for this workflow.

### 5. Run the setup script

```bash
cd ~/repos/secure-agent-playbook
chmod +x secure-agent-playbook.sh
./secure-agent-playbook.sh
```

If the Docker build fails with a permissions error on `~/.docker/buildx`:

```bash
sudo chown -R "$(whoami):staff" ~/.docker/buildx
```

Then re-run `./secure-agent-playbook.sh`.

The script:

1. Copies `secure-agent-template/` → `~/.config/secure-agent-template/`
2. Builds the `claude-secure-sandbox:latest` Docker image (first run may take a few minutes)
3. Creates the `claude-config-volume` for persistent Claude auth (Case 1)
4. Adds or **updates** `new-project` and `claude-box` helpers in `~/.zshrc`

Re-run the script after pulling repo updates so `claude-box` stays current.

### 6. Reload your shell

```bash
source ~/.zshrc
```

### 7. Authentication (pick one before first use)

Cases 1 and 3 need a way for Claude Code to authenticate. Case 2 (Cursor only) does not. Choose **one** method:

| Method                         | When to use                         | Setup                                                                                                                                 |
| ------------------------------ | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **API key**       | Simplest for containers and scripts | Add to `~/.zshrc` (never commit): `export ANTHROPIC_API_KEY="sk-ant-..."`. Case 3 forwards this into the Dev Container automatically. |
| **OAuth in container**         | You prefer logging in interactively | Skip the API key; run `claude` inside the container and follow the browser prompt. See per-case notes below.                          |
| **OAuth token**                | Headless/CI                         | Run `claude setup-token` on your Mac, then add `export CLAUDE_CODE_OAUTH_TOKEN="..."` to `~/.zshrc`                                   |

After adding env vars to `~/.zshrc`, run `source ~/.zshrc` again.

**Case 3 note:** The template `devcontainer.json` includes `remoteEnv` so API keys and OAuth tokens from your Mac reach the container, and `postCreateCommand` (`.devcontainer/setup-agent-tools.sh`) so the `~/.claude` volume is writable by the `vscode` user (required for in-container OAuth), `jq` is installed for the status line, RTK hooks are registered, and Headroom is installed. `postStartCommand` starts the Headroom proxy on `127.0.0.1:8787`.

Details and reliability notes for each case are in [Case 1](#case-1--claude-code-only) and [Case 3](#case-3--cursor--claude-code).

### 8. Verify setup worked

```bash
# Docker is running
docker ps

# Setup script installed the template
test -d ~/.config/secure-agent-template && echo "template OK"

# Shell helpers are available
type new-project
type claude-box

# Claude sandbox image exists (Case 1)
docker image inspect claude-secure-sandbox:latest >/dev/null && echo "image OK"
```

**Case 1 quick test:**

```bash
cd ~/repos
new-project test-claude claude
cd test-claude
claude-box
# Claude should start. Type /exit or Ctrl+D to leave.
```

You are already inside the container — `claude-box` runs `docker run -it` and attaches your terminal to it. There is no separate "get into the container" step. Verify with `pwd` (should show `/workspace`) or `test -f /.dockerenv && echo in-container`.

**Case 1 auth:** Uses a **separate** Docker volume from Case 3. Logging in inside a Dev Container does not log you in for `claude-box`. If OAuth says "Login successful" then **Not logged in**, reset Case 1 auth and refresh shell helpers:

```bash
# On Mac — exit claude-box first
docker volume rm claude-config-volume
cd ~/repos/secure-agent-playbook && ./secure-agent-playbook.sh
source ~/.zshrc
```

Then run the quick test again and complete `/login` once. See [Case 1 — Authentication](#3-authentication-case-1).

**Cases 2 & 3 quick test:**

```bash
cd ~/repos
new-project test-cursor cursor   # or: both
cursor .
# Click Reopen in Container — first build can take 1-2 minutes
# If using Claude Code (Case 3), when the container is ready, open a terminal and run: claude --version  
# if it asks to add folders to the workspace, you want to add the new folder name (e.g., test-cursor/ test-both/) but not /workspaces/ (that's a parent folder)
```

If any step fails, see [Troubleshooting](#troubleshooting).

---

## What every new project gets automatically

Running `new-project` copies these files into your repo:

```
my-app/
├── .cursorignore              # Cursor: skip indexing these paths
├── .cursor/mcp.json           # Cursor: Headroom MCP (compress / retrieve / stats)
├── .cursor/rules/
│   └── global-standards.mdc   # Cursor: always-on rules
├── .claudeignore              # Claude: skip from automatic context
├── .claude/
│   ├── settings.json          # Claude: hard-block reads + status line + Headroom URL
│   ├── statusline.sh          # Claude: context / rate-limit status bar
│   └── skills/
│       └── folder-explore/
│           └── SKILL.md       # Claude: build/refresh docs/repo-map.md
├── CLAUDE.md                  # Claude: project instructions every session
├── notes.md                   # Personal setup notes (theme, git credentials, RTK, Headroom)
├── .gitignore
└── .devcontainer/
    ├── devcontainer.json              # default (Cursor + Claude feature)
    ├── devcontainer.cursor-only.json  # used when mode=cursor
    ├── setup-agent-tools.sh           # installs jq, RTK, Headroom, and agent hooks
    └── start-headroom.sh              # starts the local Headroom proxy if needed
```

**Case 1 note:** `new-project foo claude` still copies `.devcontainer/` files. You won't use them — that's fine. Ignore the folder.

### RTK (token-saving shell proxy)

New containers install [RTK](https://github.com/rtk-ai/rtk) automatically. You do not type `rtk` yourself.

**What it is.** RTK sits between the agent and the shell. When Claude Code or Cursor Agent is about to run a Bash/Shell command, a hook rewrites it if RTK knows that command (`git status` becomes `rtk git status`). RTK runs the real command, compresses the output (failures only, compact git status, shorter diffs), and that short text is what the agent reads. Built-in tools like Read, Grep, and Glob skip the hook.

**Savings are bash-output savings**, not a 90% cut of your bill. RTK reports estimated tokens as `bytes / 4`. The percentages are the useful number.

**See savings** (inside the container, after some agent shell commands):

```bash
rtk --version
rtk gain          # totals
rtk gain --graph  # with a simple chart
rtk init --show   # confirm the hook is installed
```

Cursor hooks are global-only, so RTK is registered at container setup, not as a file in the git repo. Case 1 installs it in the `claude-secure-sandbox` image. Cases 2 and 3 run `.devcontainer/setup-agent-tools.sh` from `postCreateCommand`. Each new project also gets a short RTK note in `notes.md`.

### Headroom (token compression proxy)

New containers install [Headroom](https://github.com/headroomlabs-ai/headroom) and keep a local proxy on `127.0.0.1:8787`. Claude Code is routed through it automatically (`ANTHROPIC_BASE_URL`). You still type `claude` as usual — do not use `headroom wrap` for daily use.

**What it is.** Headroom compresses tool outputs, logs, and other bulky context on the way to the model. RTK shrinks shell output before the agent reads it; Headroom shrinks whatever still goes to the LLM. Keep both. Serena is not installed.

**Cursor Agent** (Composer / this chat, Cursor-hosted models) is not wrapped. Override OpenAI Base URL would send subscription models at Headroom and break them. Cursor gets Headroom as MCP tools only (`.cursor/mcp.json`).

**Telemetry is off** (`HEADROOM_BEACON=off`, `DO_NOT_TRACK=1`).

**See savings** (inside the container, after Claude has made a request):

```bash
curl -sS http://127.0.0.1:8787/health
headroom doctor
headroom dashboard --no-open   # http://127.0.0.1:8787/dashboard
```

If the proxy is down, Claude fail-closes (it will not silently talk to Anthropic). Restart it with `bash .devcontainer/start-headroom.sh`. Case 1 starts the proxy in the `claude-box` entrypoint. Cases 2 and 3 start it from `postStartCommand`.

### Ignore vs rules vs hard blocks

| File                    | Tool        | Effect                                             |
| ----------------------- | ----------- | -------------------------------------------------- |
| `.cursorignore`         | Cursor      | Excludes paths from indexing/context               |
| `.cursor/rules/*.mdc`   | Cursor      | Persistent instructions (`alwaysApply: true`)      |
| `.claudeignore`         | Claude Code | Advisory — Claude won't auto-load these paths      |
| `.cursor/mcp.json`      | Cursor      | Headroom MCP server (`headroom_compress` / retrieve / stats) |
| `.claude/settings.json` | Claude Code | **Enforced** — `permissions.deny` blocks Read tool; wires the status line; sets `ANTHROPIC_BASE_URL` for Headroom |
| `.claude/statusline.sh` | Claude Code | Status bar: context %, model, 5h/7d usage |
| `.claude/skills/`       | Claude Code | Project skills Claude can invoke (folder-explore ships by default) |
| `CLAUDE.md`             | Claude Code | Loaded at the start of every session               |

To customize defaults, edit files in `secure-agent-template/` and re-run `./secure-agent-playbook.sh`.

---

## Case 1 — Claude Code only

**Best for:** Terminal-only agent work. No Cursor required.

### 1. Create a project

```bash
cd ~/repos
new-project my-app claude
cd my-app
```

### 2. Start Claude in a container

```bash
claude-box
```

`claude-box` runs `docker run -it` with the Claude CLI as the entrypoint. Your Mac Terminal **is** the container session — you do not open a second shell or run `docker exec`. The project folder is mounted at `/workspace`.

To confirm you are inside the container:

```bash
pwd                  # /workspace
test -f /.dockerenv && echo "in container"
```

### 3. Authentication (Case 1)

Case 1 and Case 3 use **different auth storage**. A team/organizational Claude account login in a Dev Container (Case 3) does not carry over to `claude-box` (Case 1).

| Method                 | Works reliably? | Notes                                                                                                       |
| ---------------------- | --------------- | ----------------------------------------------------------------------------------------------------------- |
| **API key**            | Yes             | Add `export ANTHROPIC_API_KEY="sk-ant-..."` to `~/.zshrc`; `claude-box` passes it into the container. Often not available on team subscriptions. |
| **OAuth token**        | Yes             | `claude setup-token` on Mac, then `export CLAUDE_CODE_OAUTH_TOKEN="..."` in `~/.zshrc`                      |
| **OAuth in container** | Yes, after setup | Team/organizational accounts: run `/login`, open the URL, authorize, paste the code if prompted. Requires a writable auth volume (see below). Browser callback alone often fails — use the paste-code step. |

`claude-box` stores auth on the `claude-config-volume` at `/home/agent/.claude` inside the container, with `HOME=/home/agent` so `.claude.json` persists too.

Verify inside `claude-box`:

```bash
echo "HOME=$HOME  CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR"
ls -la /home/agent/.claude    # should show your user, not root:root
claude auth status
```

If OAuth says "Login successful" but shows **Not logged in**, the auth volume is not writable. Reset and refresh helpers:

```bash
# On Mac — exit claude-box first
docker volume rm claude-config-volume
cd ~/repos/secure-agent-playbook && ./secure-agent-playbook.sh
source ~/.zshrc
```

Re-run `./secure-agent-playbook.sh` whenever this repo updates `claude-box` — the script refreshes the function in `~/.zshrc` (it is not enough to run it once).

Auth is stored in the shared `claude-config-volume` (not per-project). Your project is mounted at `/workspace`; your Mac's `~/.ssh` is not.

### 4. Daily workflow

```bash
cd ~/repos/my-app
claude-box
# ... work ...
exit   # container is removed (--rm)
```

### 5. Optional: unattended mode

Only if you accept the risk that a malicious repo could exfiltrate credentials inside the container:

```bash
claude-box --dangerously-skip-permissions
```

---

## Case 2 — Cursor only

**Best for:** Visual editing with containerized extensions and terminals. No Claude Code.

### 1. Create a project

```bash
cd ~/repos
new-project my-app cursor
```

This swaps in `devcontainer.cursor-only.json` (no Claude Code feature) for a faster container build.

### 2. Open in a container

1. Cursor opens automatically (or run `cursor .`)
2. Click **Reopen in Container** when prompted (or Command Palette → `Dev Containers: Reopen in Container`)
3. Wait for the image pull/build — **the first build often takes 5–15 minutes**. Later opens are much faster.

Cursor's server, extensions, and integrated terminals now run inside Docker — not on your Mac.

### 3. Daily workflow

```bash
cd ~/repos/my-app
cursor .
# Reopen in Container if not already attached
```

---

## Case 3 — Cursor + Claude Code

**Best for:** Visual editing plus an autonomous coding agent, both in one container.

### 1. Create a project

```bash
cd ~/repos
new-project my-app both
```

### 2. Open and run Claude Code

1. Open in Cursor → **Reopen in Container** (first build may take 5–15 minutes)
2. Open Cursor's **integrated terminal** (inside the container)
3. Run:

```bash
claude
```

Claude Code is installed via the devcontainer feature — you do not install it yourself.

> **Tip:** Run `claude` in Cursor's integrated terminal, not `claude-box`. The Dev Container does not have Docker access, and that's intentional — it keeps isolation simple.

### 3. Authentication (Case 3)

Run `claude` from Cursor's **integrated terminal** (inside the container), not from Mac Terminal.

| Method                 | Works reliably? | Notes                                                                                                                                 |
| ---------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **API key**            | Yes             | Add `export ANTHROPIC_API_KEY="sk-ant-..."` to `~/.zshrc` on your Mac. Template `remoteEnv` forwards it into the container. Rebuild the container after adding the key. |
| **OAuth token**        | Yes             | `claude setup-token` on Mac, then `export CLAUDE_CODE_OAUTH_TOKEN="..."` in `~/.zshrc`. Rebuild the container so `remoteEnv` picks it up. |
| **OAuth in container** | Usually yes     | Run `/login` or follow the browser prompt on first `claude` start. Auth persists in a per-project Docker volume (`claude-code-config-<id>`). Requires the template `postCreateCommand` so `~/.claude` is owned by `vscode`, not `root`. |

Verify auth inside the container:

```bash
claude auth status
ls -la /home/vscode/.claude    # should show vscode:vscode, not root:root
```

If login says "successful" but immediately shows **Not logged in**, see [Troubleshooting](#troubleshooting). Common fix: delete the project's `claude-code-config-*` volume and rebuild the container.

You do **not** need Claude Code installed on your Mac for in-container OAuth (Option B). You only need a Mac install for `claude setup-token` (OAuth token method).

### 4. Daily workflow

```bash
cd ~/repos/my-app
cursor .
# Reopen in Container
claude          # inside Cursor terminal
```

---

## Command reference

| Command                                     | What it does                                       |
| ------------------------------------------- | -------------------------------------------------- |
| `./secure-agent-playbook.sh`                | One-time install (template, image, shell helpers)  |
| `new-project <name> claude`                 | New repo, Claude-only workflow                     |
| `new-project <name> cursor`                 | New repo, Cursor-only devcontainer                 |
| `new-project <name> both`                   | New repo, full template (default)                  |
| `claude-box`                                | Start Claude Code in standalone container (Case 1) |
| `claude-box --dangerously-skip-permissions` | Unattended agent (use with caution)                |

### Use with existing repos

Copy the template into an existing project:

```bash
cp -R ~/.config/secure-agent-template/. /path/to/existing-repo/
```

For Cursor-only, also run:

```bash
cp /path/to/existing-repo/.devcontainer/devcontainer.cursor-only.json \
   /path/to/existing-repo/.devcontainer/devcontainer.json
```

If you are upgrading an existing Case 3 project and OAuth login fails, delete the old auth volume and rebuild:

```bash
docker volume ls | grep claude-code-config
docker volume rm claude-code-config-<id>
```

Then in Cursor: **Dev Containers: Rebuild Container**.

---

## Security limitations

| Claim                                                     | Reality                                                                                   |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| "Host is fully protected"                                 | True for unmounted paths. Your project folder is shared on purpose.                       |
| "Ignore files = secrets are safe"                         | `.cursorignore` / `.claudeignore` are advisory. Use `permissions.deny` for Claude.        |
| "Containers = safe with `--dangerously-skip-permissions`" | Safer than host, but Anthropic warns credentials in `~/.claude` can still be exfiltrated. |

### Do

- Keep `~/.ssh`, `~/.aws`, `~/.config/gcloud` **unmounted**
- Store secrets in `.env` (gitignored)
- Use short-lived or repo-scoped API tokens when possible
- Work only in trusted repositories for sensitive code

### Don't

- Mount Docker socket into Dev Containers unless you understand the risk
- Commit `ANTHROPIC_API_KEY` or `.env` files
- Run `claude-box` from inside a Dev Container terminal (use Case 1 from Mac Terminal, or `claude` inside the container for Case 3)

---

## Troubleshooting

| Problem                                            | Fix                                                                                                                                                              |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `secure-agent-template/ not found`                 | Clone the full repo; run `./secure-agent-playbook.sh` from the repo root                                                                                         |
| `new-project`: template not found                  | Re-run `./secure-agent-playbook.sh`                                                                                                                              |
| `docker: command not found`                        | Install OrbStack: `brew install orbstack`, then launch it                                                                                                        |
| Docker build permissions error on `~/.docker/buildx` | `sudo chown -R "$(whoami):staff" ~/.docker/buildx`, then re-run setup script                                                                                  |
| Reopen in Container hangs                          | Update `anysphere.remote-containers`; try Rebuild Without Cache                                                                                                  |
| First container build is very slow                 | Normal — image pull + Headroom/Python install can take 5–15 min the first time                                                                                   |
| `cursor: command not found`                        | Install shell command from Cursor Command Palette                                                                                                                |
| Claude asks to log in every time                   | Set `ANTHROPIC_API_KEY`, or complete OAuth once so it persists in the volume                                                                                     |
| Login successful, then **Not logged in** (Case 3)  | Check `ls -la /home/vscode/.claude` — must be `vscode:vscode`, not `root:root`. Re-copy template, delete `claude-code-config-*` volume, rebuild                  |
| Login successful, then **Not logged in** (Case 1)  | Case 1 auth is separate from Case 3. Reset: `docker volume rm claude-config-volume`, re-run `./secure-agent-playbook.sh`, `source ~/.zshrc`. Inside `claude-box`, check `ls -la /home/agent/.claude` is not `root:root`. Paste OAuth code if prompted. |
| `~/.claude` owned by root in Dev Container         | Template includes `postCreateCommand` to fix this; delete old volume and rebuild                                                                                 |
| OAuth browser auth works but no code / login fails | Case 3: use API key or fix volume perms. Case 1: paste the OAuth code when prompted; browser callback alone often fails in standalone Docker |
| `claude-config-volume` owned by root (Case 1)      | `docker volume rm claude-config-volume`, re-run `./secure-agent-playbook.sh`, `source ~/.zshrc`                                                                  |
| Extensions not installing                          | Use `customizations.vscode`, not `customizations.cursor`                                                                                                         |
| Status line is blank                               | Script needs `jq`. Case 1: re-run `./secure-agent-playbook.sh` to rebuild the image. Case 3: rebuild the Dev Container so `postCreateCommand` installs `jq`.     |
| `rtk: command not found` or no auto-rewrite        | RTK is installed at container create time. Case 1: re-run `./secure-agent-playbook.sh`. Cases 2 & 3: Rebuild Container. Then `rtk --version`, `rtk gain`, and `rtk init --show`. |
| `headroom: command not found` or proxy down        | Headroom is installed at container create time. Case 1: re-run `./secure-agent-playbook.sh`. Cases 2 & 3: Rebuild Container. Then `bash .devcontainer/start-headroom.sh`, `curl -sS http://127.0.0.1:8787/health`, `headroom doctor`. |
| Claude cannot reach Anthropic / connection refused | Headroom fail-closes when the proxy is down. Start it (`bash .devcontainer/start-headroom.sh` or a new `claude-box`) and check `~/.headroom/proxy.log`. |
| Cursor Agent still uses full tokens                | Expected for Cursor-hosted models. Use Headroom MCP tools, or a custom OpenAI-compatible model pointed at `http://127.0.0.1:8787/v1`. Do not enable Override OpenAI Base URL for subscription models. |

---

## File reference (template source)

All template files live in [`secure-agent-template/`](secure-agent-template/) in this repo. Key contents:

- **`.cursorignore`** — excludes secrets, deps, build output from Cursor indexing
- **`.cursor/mcp.json`** — Cursor MCP server for Headroom (`/usr/local/bin/headroom mcp serve`)
- **`.claude/settings.json`** — enforces read blocks on secrets and `node_modules/`; points `statusLine` at the project `statusline.sh` (path is relative, not hardcoded to one workspace); sets `ANTHROPIC_BASE_URL` to the local Headroom proxy
- **`.claude/statusline.sh`** — Claude Code status bar (context %, model, 5h/7d rate limits). Needs `jq` (installed in the Case 1 image and Case 3 `postCreateCommand`)
- **`.claude/skills/folder-explore/SKILL.md`** — builds or refreshes `docs/repo-map.md` so later sessions can target files instead of reading the whole repo
- **`notes.md`** — personal setup notes (workspace Color Theme, git credential helper, what RTK and Headroom are and how to check savings)
- **`devcontainer.json`** (both mode) — Ubuntu base, Node 20, Claude Code feature, Claude Code extension in the sidebar, persistent `~/.claude` volume, `postCreateCommand` runs `setup-agent-tools.sh both` (volume permissions, `jq`, RTK, Headroom, Claude/Cursor hooks), `postStartCommand` starts the Headroom proxy, `remoteEnv` for API key/token forwarding
- **`devcontainer.cursor-only.json`** — same without Claude Code feature; `postCreateCommand` runs `setup-agent-tools.sh cursor` (RTK, Headroom, Cursor hooks); `postStartCommand` starts the Headroom proxy
- **`.devcontainer/setup-agent-tools.sh`** — installs RTK and Headroom to `/usr/local/bin`, runs `rtk init -g`, routes Claude through Headroom, starts the proxy. Re-run is idempotent.
- **`.devcontainer/start-headroom.sh`** — starts `headroom proxy` on `127.0.0.1:8787` if it is not already healthy. Beacon off.

---

## References

- [Claude Code devcontainer docs](https://code.claude.com/docs/en/devcontainer)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Claude Code status line](https://code.claude.com/docs/en/statusline)
- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)
- [RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk)
- [Headroom](https://github.com/headroomlabs-ai/headroom)
