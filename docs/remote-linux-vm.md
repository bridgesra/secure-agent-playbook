# Claude Code on a remote Linux VM (no Docker)

Use this when the **VM is the isolation boundary**: you open VS Code on your laptop, SSH into a Linux server, and run Claude Code, RTK, and Headroom **on that host**. Do not use Cases 1–2 (`claude-box`, Dev Containers, `./secure-agent-playbook.sh`). Those exist to sandbox a Mac. Here the sandbox is the machine.

Claude runs as **your Linux user**. It can read anything that account can read (`~/.ssh`, other projects, env files). Put only the analysis work on this VM, or tighten `permissions.deny`.

**Audience:** Ubuntu 20.04+ / Debian 10+ (or similar), bash or zsh, VS Code Remote SSH. Outbound HTTPS required (Anthropic, GitHub, Headroom/RTK installers).

```
Laptop (VS Code UI)
  └── Remote SSH  →  Linux VM
        ├── analysis repo
        ├── claude  (CLI; optional VS Code extension)
        ├── rtk     (shell-output hooks)
        └── headroom proxy on 127.0.0.1:8787
```

---

## What you are installing

| Piece | Role | Daily use |
| --- | --- | --- |
| **Claude Code** | Agent CLI (and optional VS Code sidebar) | `claude` in the remote terminal |
| **Template files** | Deny list, status line, `CLAUDE.md`, Headroom URL | Copied into each repo you analyze |
| **jq** | Status line | Automatic |
| **RTK** | Shrinks **shell** output before the agent reads it | Automatic via hooks. You do not type `rtk`. |
| **Headroom** | Shrinks **whatever still goes to the LLM** (`127.0.0.1:8787`) | Type `claude` as usual. If the proxy is down, Claude **fail-closes**. |

Keep RTK and Headroom both.

---

## 1. One-time: tools on the VM

SSH in as the user who will run Claude. Do **not** run `./secure-agent-playbook.sh` (it builds a Docker image and writes Mac `zsh` helpers).

### Claude Code

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates jq

curl -fsSL https://claude.ai/install.sh | bash

claude --version 
```

If `claude` is not found:

```bash
echo 'export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
claude --version
```

On zsh, use `~/.zshrc` instead of `~/.bashrc` in every snippet below.

### Playbook template (scripts + files to copy into projects)

```bash
mkdir -p ~/repos "$HOME/.config/secure-agent-template"
cd ~/repos
git clone https://github.com/bridgesra/secure-agent-playbook.git
cp -R ~/repos/secure-agent-playbook/secure-agent-template/. \
  "$HOME/.config/secure-agent-template/"
```

Use your fork URL if that is what you maintain.

### RTK, Headroom, Claude hooks

`setup-agent-tools.sh` defaults to `/home/vscode/.claude`. Override that or it will try to `chown` a user that does not exist.

```bash
export CLAUDE_HOME="$HOME/.claude"
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
bash "$HOME/.config/secure-agent-template/.devcontainer/setup-agent-tools.sh"
```

Needs `sudo` for packages and `/usr/local/bin`. Re-run is idempotent.

### Start Headroom on login (do not block the shell)

There is no Dev Container `postStartCommand`. If `8787` is down, Claude will not reach Anthropic.

```bash
START_HR="$HOME/.config/secure-agent-template/.devcontainer/start-headroom.sh"

cat >> ~/.bashrc <<EOF

# secure-agent-playbook: Headroom proxy (loopback only)
export PATH="\$HOME/.local/bin:/usr/local/bin:\$PATH"
export HEADROOM_BEACON=off
export DO_NOT_TRACK=1
if command -v curl >/dev/null 2>&1 && ! curl -sf --max-time 1 http://127.0.0.1:8787/health >/dev/null 2>&1; then
  nohup bash "${START_HR}" >/dev/null 2>&1 &
fi
EOF
source ~/.bashrc
```

Add that block **once**. If you paste it twice you will get duplicate startups.

The proxy listens on **127.0.0.1:8787** only. Do not publish that port on `0.0.0.0`.

### Auth (pick one)

| Method | Setup |
| --- | --- |
| **API key** | `echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc` then `source ~/.bashrc`. Never commit the key. |
| **OAuth in the terminal** | Run `claude` and `/login`. Paste the code if the browser callback fails. |

Team subscriptions often have no API key; use `/login`.

---

## 2. Each analysis repo

Copy the template into the repo **on the VM**. Do not copy it over this playbook repo.

**New or empty directory:**

```bash
mkdir -p /path/to/analysis-repo
cp -R "$HOME/.config/secure-agent-template/." /path/to/analysis-repo/
cd /path/to/analysis-repo
```

**Existing repo:** copy these paths. Do **not** run `cp -R` over a repo that already has `CLAUDE.md`, `.gitignore`, or `.claude/settings.json` you care about — merge by hand instead.

```text
.claude/settings.json
.claude/statusline.sh
.claude/skills/
.claudeignore
CLAUDE.md                 # skip if the repo already has project instructions
environment-notes.md      # optional personal notes
.gitignore                # merge; at least ignore .env and .claude/.headroom_wrap_*
.devcontainer/setup-agent-tools.sh
.devcontainer/start-headroom.sh
```

`.devcontainer/devcontainer.json` is unused without Docker; you can omit it.

Tighten `.claudeignore` and `.claude/settings.json` `permissions.deny` for bulky data and secrets. Ignore files are advisory; `permissions.deny` is the hard Read block.

Data **outside** the git repo is still readable if your user can open it. No extra mount is required. Add deny rules if it should stay out of Claude.

---

## 3. VS Code on the laptop

Install Microsoft **Remote - SSH** (you do not need Dev Containers).

1. Command Palette → **Remote-SSH: Connect to Host** → the VM.
2. **File → Open Folder** → the analysis repo. Plain folder, not “Reopen in Container”.
3. Optional: install the **Claude Code** extension (`anthropic.claude-code`) on the SSH host for the sidebar.
4. Open the **remote** integrated terminal:

```bash
cd /path/to/analysis-repo
claude
```

Type `claude`, not `claude-box`.

To see the Headroom dashboard in a laptop browser, forward loopback port `8787` (VS Code Ports panel, or `ssh -L 8787:127.0.0.1:8787 user@vm`), then open [http://127.0.0.1:8787/dashboard](http://127.0.0.1:8787/dashboard) after one real Claude request.

---

## 4. Confirm it works

In the **VM** terminal (SSH or VS Code remote):

```bash
claude --version
rtk --version && rtk init --show
curl -sS http://127.0.0.1:8787/health
headroom doctor
```

| Check | Expected |
| --- | --- |
| `claude --version` | A version string, not `command not found` |
| `rtk init --show` | Claude hook `[ok]` |
| `health` | `"status":"healthy"` |
| `headroom doctor` | **proxy pass** |

A `savings` warning before any real Claude request is normal. Then:

```bash
cd /path/to/analysis-repo
claude
```

You should see the CLI status bar (context / model / usage). Blank bar usually means `jq` is missing: `sudo apt-get install -y jq`.

After a few agent shell commands: `rtk gain`. After one Claude prompt: `curl -sS http://127.0.0.1:8787/stats`.

If Claude cannot reach Anthropic, the proxy is down:

```bash
bash "$HOME/.config/secure-agent-template/.devcontainer/start-headroom.sh"
curl -sS http://127.0.0.1:8787/health
```

Logs: `~/.headroom/proxy.log`.

---

## 5. Daily loop

1. VS Code → Remote SSH → open the analysis folder.
2. Remote terminal: `claude` (Headroom should already be up from `.bashrc`).
3. Edit in VS Code; Claude writes the same files on the VM.

After a VM reboot, the first new shell starts the proxy. If `curl` to `8787` fails, run `start-headroom.sh` once.

Optional git helper on the VM: `git config --global credential.helper store`.

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `claude: command not found` | Add `$HOME/.local/bin` to `PATH` and open a new shell. Confirm `~/.local/bin/claude` exists. |
| `setup-agent-tools.sh` talks about `/home/vscode` | You forgot `export CLAUDE_HOME="$HOME/.claude"`. |
| `rtk: command not found` / `headroom: command not found` | Re-run the setup script with `CLAUDE_HOME` set. Ensure `/usr/local/bin` is on `PATH`. |
| `health` fails, Claude cannot reach Anthropic | Proxy down. Run `start-headroom.sh`. Check `~/.headroom/proxy.log`. Do not unset `ANTHROPIC_BASE_URL` to “fix” it — that bypasses Headroom. |
| Status line blank | Install `jq`. |
| Login works on the laptop but not on the VM | Auth is on the VM user. Set the API key or `/login` in the remote terminal. |
| Want Docker isolation instead | You are on the wrong page. Use Cases 1–2 in [README.md](../README.md) (Mac + containers), or run a Dev Container **on** the VM if you need the agent sandboxed from this host. |

---

## Security limitations

| Claim | Reality |
| --- | --- |
| "The VM is a container" | It isolates the **laptop**. It does not isolate other files on the VM from Claude. |
| "Ignore files = secrets are safe" | Advisory. Use `permissions.deny` for Claude Read. |
| "Headroom / RTK are a sandbox" | They save tokens. They are not a security boundary. |

Do not commit `ANTHROPIC_API_KEY` or `.env`. Do not bind Headroom to a public interface.

---

## See also

- [README.md](../README.md) — Mac + Docker Cases 1–2
- [upgrade-existing-projects.md](upgrade-existing-projects.md) — merge RTK/Headroom into an old **containerized** project (not this host-install path)
- [Claude Code native install](https://code.claude.com/docs/en/installation)
- [RTK](https://github.com/rtk-ai/rtk)
- [Headroom](https://github.com/headroomlabs-ai/headroom)
