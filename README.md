# Secure Agent Playbook

Run **Claude Code** inside Docker containers on your Mac so agent commands never touch your host filesystem, SSH keys, or cloud credentials directly. Every new project comes with [RTK](https://github.com/rtk-ai/rtk) and [Headroom](https://github.com/headroomlabs-ai/headroom) set up to cut token use.

**Audience:** Apple Silicon Mac, `zsh`, comfortable with Terminal. This guide does not cover Windows.

**Remote Linux VM (no Docker):** if the VM *is* the sandbox — VS Code Remote SSH, repo on the server, Claude/RTK/Headroom installed on that host — skip Cases 1–2 and follow [docs/remote-linux-vm.md](docs/remote-linux-vm.md).

---

## Pick your case

Both cases use the same project files. `new-project my-app` creates a project that works either way.

| Case                       | You use                       | Container                   | Daily commands                                   |
| -------------------------- | ----------------------------- | --------------------------- | ------------------------------------------------ |
| **1 — Terminal only**      | Claude Code CLI               | `claude-box` (one per run)  | `claude-box`                                     |
| **2 — VS Code**            | VS Code + Claude Code CLI/extension | Dev Container (per project) | `code .` → Reopen in Container → `claude` |

```
CASE 1 — Terminal only              CASE 2 — VS Code
┌─────────────────────┐             ┌──────────────────────────────────────┐
│  Mac Terminal       │             │  VS Code (native UI)                 │
│    └── claude-box   │             │    └── Dev Container                 │
│         └── claude  │             │          ├── VS Code server + ext.   │
└─────────────────────┘             │          └── claude  ← type it here  │
                                    └──────────────────────────────────────┘
```

> **Case 1 does not require VS Code.** You only need Docker/OrbStack and Terminal.
>
> **Not using Docker?** A dedicated Linux VM that you treat as the isolation boundary is a different setup (no `claude-box`, no Dev Container). See [docs/remote-linux-vm.md](docs/remote-linux-vm.md).
>
> **Security note:** Containers protect your **host** (`~/.ssh`, `~/.aws`, etc.). Your **project folder** is intentionally shared and writable. `.claudeignore` reduces what Claude loads automatically; `permissions.deny` in `.claude/settings.json` hard-blocks reads. Neither is a perfect guarantee against a malicious repo.

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

| Tool                             | Required for | Install                                                                          |
| -------------------------------- | ------------ | -------------------------------------------------------------------------------- |
| **OrbStack** (or Docker Desktop) | Both cases   | `brew install orbstack`                                                          |
| **VS Code**                      | Case 2 only  | `brew install --cask visual-studio-code`                                         |
| **Dev Containers** extension     | Case 2 only  | VS Code → Extensions → `ms-vscode-remote.remote-containers` (by Microsoft)       |
| **`code` shell command**         | Case 2 only  | VS Code → Command Palette → `Shell Command: Install 'code' command in PATH`      |

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

Re-run the script after pulling repo updates so `claude-box` and the template stay current.

### 6. Reload your shell

```bash
source ~/.zshrc
```

### 7. Authentication (pick one before first use)

Choose **one** method:

| Method                 | When to use                         | Setup                                                                                                                                 |
| ---------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **API key**            | Simplest for containers and scripts | Add to `~/.zshrc` (never commit): `export ANTHROPIC_API_KEY="sk-ant-..."`. Case 2 forwards this into the Dev Container automatically. |
| **OAuth in container** | You prefer logging in interactively | Skip the API key; run `claude` inside the container and follow the browser prompt. See per-case notes below.                          |
| **OAuth token**        | Headless/CI                         | Run `claude setup-token` on your Mac, then add `export CLAUDE_CODE_OAUTH_TOKEN="..."` to `~/.zshrc`                                   |

After adding env vars to `~/.zshrc`, run `source ~/.zshrc` again.

**Case 2 note:** The template `devcontainer.json` includes `remoteEnv` so API keys and OAuth tokens from your Mac reach the container, and `postCreateCommand` (`.devcontainer/setup-agent-tools.sh`) so the `~/.claude` volume is writable by the `vscode` user (required for in-container OAuth), `jq` is installed for the status line, the RTK hook is registered, and Headroom is installed. `postStartCommand` starts the Headroom proxy on `127.0.0.1:8787`.

Details and reliability notes for each case are in [Case 1](#case-1--terminal-only) and [Case 2](#case-2--vs-code-dev-container).

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
new-project test-claude
claude-box
# Claude should start. Type /exit or Ctrl+D to leave.
```

`new-project` already `cd`s into the new folder. You are inside the container once `claude-box` starts — it runs `docker run -it` and attaches your terminal to it. There is no separate "get into the container" step. Verify with `pwd` (should show `/workspace`) or `test -f /.dockerenv && echo in-container`.

**Case 1 auth:** Uses a **separate** Docker volume from Case 2. Logging in inside a Dev Container does not log you in for `claude-box`. If OAuth says "Login successful" then **Not logged in**, reset Case 1 auth and refresh shell helpers:

```bash
# On Mac — exit claude-box first
docker volume rm claude-config-volume
cd ~/repos/secure-agent-playbook && ./secure-agent-playbook.sh
source ~/.zshrc
```

Then run the quick test again and complete `/login` once. See [Case 1 — Authentication](#3-authentication-case-1).

**Case 2 quick test:**

```bash
cd ~/repos
new-project test-vscode
code .
# Click Reopen in Container — first build can take 5–15 minutes
# When the container is ready, open a terminal and run: claude --version
# If it asks to add folders to the workspace, add the project folder (e.g., test-vscode/), not /workspaces/ (that's a parent folder)
```

If any step fails, see [Troubleshooting](#troubleshooting).

---

## What every new project gets automatically

Running `new-project` copies these files into your repo:

```
my-app/
├── .claudeignore              # Claude: skip from automatic context
├── .claude/
│   ├── settings.json          # Claude: hard-block reads + status line + Headroom URL
│   ├── statusline.sh          # Claude CLI: running context, model, effort, token usage
│   └── skills/
│       └── folder-explore/
│           └── SKILL.md       # Claude: build/refresh docs/repo-map.md
├── CLAUDE.md                  # Claude: project instructions every session
├── environment-notes.md       # Setup notes: per-project colors, git credentials, status line, RTK, Headroom
├── .gitignore
└── .devcontainer/
    ├── devcontainer.json      # Case 2: Claude Code feature + extension, Headroom port, setup hooks
    ├── setup-agent-tools.sh   # installs jq, RTK, Headroom, and the Claude hooks
    └── start-headroom.sh      # starts the local Headroom proxy if needed
```

**Case 1 note:** `claude-box` ignores `.devcontainer/`. Keep the folder anyway — it lets you open the same project in VS Code later.

### Status line (Claude Code CLI)

Each project ships `.claude/statusline.sh`, wired from `.claude/settings.json`. In the **Claude Code terminal CLI** it shows running context, model, effort, and token usage so you can see how full the window is without leaving the session.

It needs `jq` (installed in the Case 1 image and by the Case 2 `postCreateCommand`). If the bar is blank, see [Troubleshooting](#troubleshooting).

### RTK (token-saving shell proxy)

New containers install [RTK](https://github.com/rtk-ai/rtk) automatically. You do not type `rtk` yourself.

**What it is.** RTK sits between Claude and the shell. When Claude Code is about to run a Bash command, a hook rewrites it if RTK knows that command (`git status` becomes `rtk git status`). RTK runs the real command, compresses the output (failures only, compact git status, shorter diffs), and that short text is what Claude reads. Built-in tools like Read, Grep, and Glob skip the hook.

**Savings are bash-output savings**, not a 90% cut of your bill. RTK reports estimated tokens as `bytes / 4`. The percentages are the useful number.

**See savings** (inside the container, after some agent shell commands):

```bash
rtk --version
rtk gain          # totals
rtk gain --graph  # with a simple chart
rtk init --show   # confirm the hook is installed
```

The hook is global (`rtk init -g`), so RTK is registered at container setup, not as a file in the git repo. Case 1 installs it in the `claude-secure-sandbox` image. Case 2 runs `.devcontainer/setup-agent-tools.sh` from `postCreateCommand`.

### Headroom (token compression proxy)

New containers install [Headroom](https://github.com/headroomlabs-ai/headroom) and keep a local proxy on `127.0.0.1:8787`.

**What it is.** Headroom compresses tool outputs, logs, and other bulky context before they reach the model. RTK shrinks shell output before Claude reads it; Headroom shrinks whatever still goes to the LLM. Keep both. Telemetry is off (`HEADROOM_BEACON=off`).

**Daily use.** Type `claude` as usual — do not use `headroom wrap`. Claude Code (CLI and VS Code extension) is routed automatically (`ANTHROPIC_BASE_URL`).

**Check it** (inside the container, after the proxy is up):

```bash
curl -sS http://127.0.0.1:8787/health
headroom doctor
```

**Dashboard.** After Claude has made a request, open the live savings page:

- **Case 2:** in a Mac browser, [http://127.0.0.1:8787/dashboard](http://127.0.0.1:8787/dashboard) (port `8787` is forwarded).
- **Case 1:** the proxy stays loopback inside `claude-box`. Use `curl -sS http://127.0.0.1:8787/stats` and `headroom doctor` in that session.

If the proxy is down, Claude fail-closes (it will not silently talk to Anthropic). Restart it with `bash .devcontainer/start-headroom.sh`. Case 1 starts the proxy in the `claude-box` entrypoint. Case 2 starts it from `postStartCommand`. Details for a new project live in that repo's `environment-notes.md`.

### Per-project VS Code colors and git credentials

Each project's `environment-notes.md` covers both:

- **Colors:** set the theme or title bar color under the **Workspace** settings tab. It is saved in that folder's `.vscode/settings.json`, so it sticks to that project and leaves other VS Code windows alone.
- **Git credentials:** in Case 2, VS Code forwards your Mac Keychain credential helper into the container. Set it up once on the Mac. In Case 1, run `git push` from Mac Terminal. Avoid `credential.helper store` inside a container: it saves your token in plain text where Claude can read it.

### Ignore vs rules vs hard blocks

| File                    | Effect                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| `.claudeignore`         | Advisory — Claude won't auto-load these paths                                                |
| `.claude/settings.json` | **Enforced** — `permissions.deny` blocks the Read tool; wires the status line; sets `ANTHROPIC_BASE_URL` for Headroom |
| `.claude/statusline.sh` | CLI status bar: running context, model, effort, token usage                                  |
| `.claude/skills/`       | Project skills Claude can invoke (folder-explore ships by default)                          |
| `CLAUDE.md`             | Loaded at the start of every session                                                         |

To customize defaults, edit files in `secure-agent-template/` and re-run `./secure-agent-playbook.sh`.

---

## Case 1 — Terminal only

**Best for:** Terminal-only agent work. No VS Code required.

### 1. Create a project

```bash
cd ~/repos
new-project my-app      # creates ~/repos/my-app and cd's into it
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

Case 1 and Case 2 use **different auth storage**. A team/organizational Claude account login in a Dev Container (Case 2) does not carry over to `claude-box` (Case 1).

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

Run `git push` / `git pull` from Mac Terminal, not inside `claude-box` (it has no credentials on purpose).

### 5. Optional: unattended mode

Only if you accept the risk that a malicious repo could exfiltrate credentials inside the container:

```bash
claude-box --dangerously-skip-permissions
```

---

## Case 2 — VS Code Dev Container

**Best for:** Visual editing plus Claude Code, both in one container. You can use the `claude` CLI in the integrated terminal, the Claude Code extension in the sidebar, or both.

### 1. Create a project

```bash
cd ~/repos
new-project my-app      # creates ~/repos/my-app and cd's into it
```

### 2. Open and run Claude Code

1. Run `code .`, then click **Reopen in Container** when prompted (or Command Palette → `Dev Containers: Reopen in Container`). **The first build often takes 5–15 minutes**; later opens are much faster.
2. Open VS Code's **integrated terminal** (it runs inside the container).
3. Run:

```bash
claude
```

Claude Code is installed via the devcontainer feature, and the Claude Code extension is installed in the container — you do not install either yourself. VS Code's server, extensions, and terminals all run inside Docker, not on your Mac.

> **Tip:** Run `claude` in VS Code's integrated terminal, not `claude-box`. The Dev Container does not have Docker access, and that's intentional — it keeps isolation simple.

### 3. Authentication (Case 2)

Run `claude` from VS Code's **integrated terminal** (inside the container), not from Mac Terminal.

| Method                 | Works reliably? | Notes                                                                                                                                 |
| ---------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **API key**            | Yes             | Add `export ANTHROPIC_API_KEY="sk-ant-..."` to `~/.zshrc` on your Mac. Template `remoteEnv` forwards it into the container. Rebuild the container after adding the key. |
| **OAuth token**        | Yes             | `claude setup-token` on Mac, then `export CLAUDE_CODE_OAUTH_TOKEN="..."` in `~/.zshrc`. Rebuild the container so `remoteEnv` picks it up. |
| **OAuth in container** | Usually yes     | Run `/login` or follow the browser prompt on first `claude` start. Auth persists in a per-project Docker volume (`claude-code-config-<id>`). Requires the template `postCreateCommand` so `~/.claude` is owned by `vscode`, not `root`. |

`remoteEnv` reads your Mac's environment when VS Code starts. If you added the key in a terminal, quit and relaunch VS Code (or start it with `code .` from a shell that has the variable) before rebuilding.

Verify auth inside the container:

```bash
claude auth status
ls -la /home/vscode/.claude    # should show vscode:vscode, not root:root
```

If login says "successful" but immediately shows **Not logged in**, see [Troubleshooting](#troubleshooting). Common fix: delete the project's `claude-code-config-*` volume and rebuild the container.

You do **not** need Claude Code installed on your Mac for in-container OAuth. You only need a Mac install for `claude setup-token` (OAuth token method).

### 4. Daily workflow

```bash
cd ~/repos/my-app
code .
# Reopen in Container if not already attached
claude          # inside the VS Code terminal
```

---

## Command reference

| Command                                     | What it does                                                      |
| ------------------------------------------- | ----------------------------------------------------------------- |
| `./secure-agent-playbook.sh`                | One-time install (template, image, shell helpers); re-run after pulling |
| `new-project <name>`                        | New repo from the template, then `cd` into it (works for both cases) |
| `claude-box`                                | Start Claude Code in a standalone container (Case 1)              |
| `claude-box --dangerously-skip-permissions` | Unattended agent (use with caution)                               |

`new-project` used to take a `claude|cursor|both` mode. It now ignores a second argument and prints a note.

### Use with existing repos

To add the **status line, RTK, and Headroom** to a project that was scaffolded before those shipped, or to **remove the old Cursor files** from one, do not copy the whole template over it. Follow [docs/upgrade-existing-projects.md](docs/upgrade-existing-projects.md).

To install Claude, RTK, and Headroom **on a remote Linux VM** (no Docker), follow [docs/remote-linux-vm.md](docs/remote-linux-vm.md) instead of `new-project` / `claude-box`.

To scaffold the template into a repo that never used it (this overwrites files with the same names, such as `CLAUDE.md` and `.gitignore`):

```bash
cp -R ~/.config/secure-agent-template/. /path/to/existing-repo/
```

If you are upgrading an existing Case 2 project and OAuth login fails, delete the old auth volume and rebuild:

```bash
docker volume ls | grep claude-code-config
docker volume rm claude-code-config-<id>
```

Then in VS Code: **Dev Containers: Rebuild Container**.

---

## Security limitations

| Claim                                                     | Reality                                                                                   |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| "Host is fully protected"                                 | True for unmounted paths. Your project folder is shared on purpose.                       |
| "Ignore files = secrets are safe"                         | `.claudeignore` is advisory. Use `permissions.deny` for hard blocks.                      |
| "Containers = safe with `--dangerously-skip-permissions`" | Safer than host, but Anthropic warns credentials in `~/.claude` can still be exfiltrated. |
| "Git token in the container is fine"                      | `credential.helper store` writes it in plain text where Claude can read it. Use the Mac Keychain (Case 2) or push from the Mac (Case 1). |

### Do

- Keep `~/.ssh`, `~/.aws`, `~/.config/gcloud` **unmounted**
- Store secrets in `.env` (gitignored)
- Use short-lived or repo-scoped API tokens when possible
- Work only in trusted repositories for sensitive code

### Don't

- Mount the Docker socket into Dev Containers unless you understand the risk
- Commit `ANTHROPIC_API_KEY` or `.env` files
- Run `claude-box` from inside a Dev Container terminal (use Case 1 from Mac Terminal, or `claude` inside the container for Case 2)

---

## Troubleshooting

| Problem                                            | Fix                                                                                                                                                              |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `secure-agent-template/ not found`                 | Clone the full repo; run `./secure-agent-playbook.sh` from the repo root                                                                                         |
| `new-project`: template not found                  | Re-run `./secure-agent-playbook.sh`                                                                                                                              |
| `docker: command not found`                        | Mac Cases 1–2: install OrbStack (`brew install orbstack`) and launch it. Linux VM with no Docker: you want [docs/remote-linux-vm.md](docs/remote-linux-vm.md), not this README. |
| Docker build permissions error on `~/.docker/buildx` | `sudo chown -R "$(whoami):staff" ~/.docker/buildx`, then re-run setup script                                                                                  |
| Reopen in Container hangs                          | Update the Dev Containers extension; try **Dev Containers: Rebuild Without Cache**                                                                               |
| First container build is very slow                 | Normal — image pull + Headroom/Python install can take 5–15 min the first time                                                                                   |
| `code: command not found`                          | VS Code Command Palette → `Shell Command: Install 'code' command in PATH`                                                                                        |
| Claude asks to log in every time                   | Set `ANTHROPIC_API_KEY`, or complete OAuth once so it persists in the volume                                                                                     |
| Login successful, then **Not logged in** (Case 2)  | Check `ls -la /home/vscode/.claude` — must be `vscode:vscode`, not `root:root`. Re-copy template, delete `claude-code-config-*` volume, rebuild                  |
| Login successful, then **Not logged in** (Case 1)  | Case 1 auth is separate from Case 2. Reset: `docker volume rm claude-config-volume`, re-run `./secure-agent-playbook.sh`, `source ~/.zshrc`. Inside `claude-box`, check `ls -la /home/agent/.claude` is not `root:root`. Paste OAuth code if prompted. |
| `~/.claude` owned by root in Dev Container         | Template includes `postCreateCommand` to fix this; delete old volume and rebuild                                                                                 |
| OAuth browser auth works but no code / login fails | Case 2: use API key or fix volume perms. Case 1: paste the OAuth code when prompted; browser callback alone often fails in standalone Docker |
| `claude-config-volume` owned by root (Case 1)      | `docker volume rm claude-config-volume`, re-run `./secure-agent-playbook.sh`, `source ~/.zshrc`                                                                  |
| Status line is blank                               | Script needs `jq`. Case 1: re-run `./secure-agent-playbook.sh` to rebuild the image. Case 2: rebuild the Dev Container so `postCreateCommand` installs `jq`.     |
| `rtk: command not found` or no auto-rewrite        | RTK is installed at container create time. Case 1: re-run `./secure-agent-playbook.sh`. Case 2: Rebuild Container. Then `rtk --version`, `rtk gain`, and `rtk init --show`. |
| `headroom: command not found` or proxy down        | Headroom is installed at container create time. Case 1: re-run `./secure-agent-playbook.sh`. Case 2: Rebuild Container. Then `bash .devcontainer/start-headroom.sh`, `curl -sS http://127.0.0.1:8787/health`, `headroom doctor`. |
| Claude cannot reach Anthropic / connection refused | Headroom fail-closes when the proxy is down. Start it (`bash .devcontainer/start-headroom.sh` or a new `claude-box`) and check `~/.headroom/proxy.log`. |
| `git push` asks for a password in the Dev Container | Set up the Mac Keychain helper once (see the project's `environment-notes.md`), then rebuild or reopen the container.                                          |
| Project colors leak into other VS Code windows     | You changed the **User** setting. Move it to the **Workspace** tab so it lives in the project's `.vscode/settings.json`.                                          |
| Old project fails with `Cursor support was removed` | Its `devcontainer.json` still runs `setup-agent-tools.sh cursor`. See [docs/upgrade-existing-projects.md](docs/upgrade-existing-projects.md).                  |

---

## File reference (template source)

All template files live in [`secure-agent-template/`](secure-agent-template/) in this repo. Key contents:

- **`.claude/settings.json`** — enforces read blocks on secrets, `node_modules/`, the git credential store (`~/.git-credentials`), and Claude's own OAuth file (`~/.claude/.credentials.json`); points `statusLine` at the project `statusline.sh` (path is relative, not hardcoded to one workspace); sets `ANTHROPIC_BASE_URL` to the local Headroom proxy
- **`.claude/statusline.sh`** — Claude Code terminal CLI status bar: running context, model, effort, and token usage. Needs `jq` (installed in the Case 1 image and the Case 2 `postCreateCommand`)
- **`.claude/skills/folder-explore/SKILL.md`** — builds or refreshes `docs/repo-map.md` so later sessions can target files instead of reading the whole repo
- **`CLAUDE.md`** — project standards loaded into every Claude session
- **`environment-notes.md`** — setup notes: per-project VS Code colors, git credentials, status line, RTK, and Headroom (what it is, daily use, health check, dashboard URL)
- **`.devcontainer/devcontainer.json`** — Ubuntu base, Node 20, Claude Code feature, Claude Code extension in the sidebar, persistent `~/.claude` volume, `postCreateCommand` runs `setup-agent-tools.sh` (volume permissions, `jq`, RTK, Headroom, Claude hook and routing), `postStartCommand` starts the Headroom proxy, `remoteEnv` for API key/token forwarding
- **`.devcontainer/setup-agent-tools.sh`** — installs RTK and Headroom to `/usr/local/bin`, runs `rtk init -g`, routes Claude through Headroom, starts the proxy. Re-run is idempotent. Still accepts the old `claude`/`both` argument.
- **`.devcontainer/start-headroom.sh`** — starts `headroom proxy` on `127.0.0.1:8787` if it is not already healthy. Beacon off.

---

## Tests (this repo)

```bash
./tests/run.sh                 # contract, unit, installer (no Docker needed)
RUN_RUNTIME=1 ./tests/run.sh   # also builds real containers
```

See [tests/POLICY.md](tests/POLICY.md) before changing a test.

---

## References

- [Remote Linux VM (no Docker)](docs/remote-linux-vm.md) — Claude, RTK, and Headroom on a Linux host via VS Code Remote SSH
- [Upgrade existing (containerized) projects](docs/upgrade-existing-projects.md)
- [Docker cheat sheet](docker-cheat-sheet.md)
- [Claude Code native install](https://code.claude.com/docs/en/installation)
- [Claude Code devcontainer docs](https://code.claude.com/docs/en/devcontainer)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
- [Claude Code skills](https://code.claude.com/docs/en/skills)
- [Claude Code status line](https://code.claude.com/docs/en/statusline)
- [Claude Code environment variables](https://code.claude.com/docs/en/env-vars)
- [VS Code: sharing Git credentials with a container](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials)
- [RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk)
- [Headroom](https://github.com/headroomlabs-ai/headroom)
