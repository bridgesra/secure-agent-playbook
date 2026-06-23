# Docker cheat sheet (for Secure Agent Playbook)

A practical primer on Docker concepts used in this playbook — Case 1 (`claude-box`), Case 2/3 (Dev Containers), and OrbStack on macOS.

**One-sentence model:** An **image** is a recipe. A **container** is a running instance of that recipe. A **volume** is disk that outlives any single container.

---

## Image

An **image** is a read-only template: OS + tools + app, packaged as layers.

| Image in this playbook | What it is |
| ---------------------- | ---------- |
| `claude-secure-sandbox:latest` | Node base + `claude` CLI (built by `secure-agent-playbook.sh`) |
| `mcr.microsoft.com/devcontainers/base:ubuntu` | Base image for Case 2/3 dev containers |
| `node:20-bookworm-slim` | Starting point for the Case 1 image build |

Images are **built or pulled once**, then **reused**. They do not change while you work (unless you rebuild).

```bash
docker image ls
```

**Think:** installed app on disk — not running yet.

---

## Container

A **container** is a running (or stopped) process environment created **from** an image.

When you run `claude-box`:

```bash
docker run --rm -it ... claude-secure-sandbox:latest
```

Docker:

1. Takes the image
2. Creates an isolated environment (own filesystem view, process namespace)
3. Starts `claude` as the main process
4. Attaches your terminal to it

When you `/exit`, that process ends → the container stops → `--rm` deletes it.

```bash
docker ps        # running containers
docker ps -a     # all containers (including stopped)
```

**Think:** a lightweight, disposable sandbox — not a full VM.

**Important:** Containers are **ephemeral by default**. Anything written *inside* the container filesystem (not on a volume) is **lost** when the container is removed.

---

## Volume

A **named volume** is storage **managed by Docker** that **survives** container deletion.

Case 1 auth uses:

```text
claude-config-volume  →  mounted at /home/agent inside the container
```

- Container exits → **volume stays**
- Next `claude-box` → same volume reattached → login persists

```bash
docker volume ls
docker volume inspect claude-config-volume
```

**Think:** a Docker-owned disk you plug into whichever container needs it.

Case 3 uses a similar pattern: `claude-code-config-<id>` (per dev container / project).

---

## Bind mount (different from a volume)

A **bind mount** maps a **folder on your Mac** into the container.

`claude-box` does this for your code:

```text
~/repos/my-app  →  /workspace   (inside container)
```

- Edits inside the container → change real files on your Mac
- Container removed → **project folder still there**

| | Volume | Bind mount |
| -- | ------ | ---------- |
| **Owned by** | Docker | You (host path) |
| **Typical use** | Auth, DB data, caches | Source code |
| **This playbook** | `claude-config-volume` | project → `/workspace` |

---

## Dockerfile

A **Dockerfile** is instructions to **build** an image:

```dockerfile
FROM node:20-bookworm-slim    # start from base image
RUN npm install -g claude     # add packages/tools
ENTRYPOINT ["claude"]         # default command when container starts
```

The setup script writes one to `~/.config/claude-sandbox/Dockerfile` and runs `docker build`.

**Think:** a Makefile for a machine snapshot.

---

## `docker run` flags (used in this playbook)

```bash
docker run [options] IMAGE [command]
```

| Flag | Meaning |
| ---- | ------- |
| `--rm` | Delete container when it exits |
| `-it` | Interactive + terminal (you can type) |
| `-v A:B` | Mount A into path B inside the container |
| `-e VAR=val` | Set environment variable |
| `-u 501:20` | Run as your Mac user ID (file permissions) |
| `-w /workspace` | Working directory inside the container |
| `--name foo` | Give the container a name |

---

## Registry

A **registry** is where images are stored and downloaded from.

| Registry | Examples |
| -------- | -------- |
| Docker Hub | `node:20-bookworm-slim` |
| Microsoft | `mcr.microsoft.com/devcontainers/...` |
| GitHub | `ghcr.io/anthropics/devcontainer-features/...` |

- `docker build` — create a local image
- `docker pull` — download an image

Dev Containers pull images on first **Reopen in Container** (can take 5–15 minutes the first time).

---

## Case 1 vs Dev Container (Case 2/3)

Both use Docker; the workflow differs.

| | Case 1 `claude-box` | Case 2/3 Dev Container |
| -- | ------------------- | ---------------------- |
| **Who starts it** | You, in Mac Terminal | Cursor / VS Code extension |
| **What runs** | `claude` (entrypoint) | Editor server + tools + terminals |
| **How long it lives** | Until you `/exit` | Until you close the remote connection |
| **Code** | Bind mount → `/workspace` | Bind mount project folder |
| **Auth volume** | `claude-config-volume` (shared) | `claude-code-config-<id>` (per project) |

---

## OrbStack

**OrbStack** runs the Linux environment Docker needs on your Mac. Use the `docker` CLI or the OrbStack UI — same concepts, same commands.

---

## Lifecycle (this playbook)

```text
ONE-TIME (setup script)
  docker build           → image: claude-secure-sandbox:latest
  docker volume create   → claude-config-volume

EACH claude-box SESSION
  docker run             → new container from image
  mount volume           → auth persists
  mount ~/repos/…        → your code
  /exit                  → container gone (--rm)
  volume remains         → next time still logged in

CASE 3 DEV CONTAINER
  Cursor builds/pulls image + features
  creates per-project volume for ~/.claude
  container stays up while editor is attached
```

---

## Commands worth remembering

```bash
docker ps              # running containers
docker ps -a           # including stopped
docker image ls        # installed images
docker volume ls       # persistent storage
docker volume inspect NAME
docker volume rm NAME  # delete volume (wipes Case 1 auth!)
docker stop ID         # stop a container
docker logs ID         # container output (debugging)
```

**Peek inside Case 1 auth volume** (while `claude-box` is not running):

```bash
docker run --rm -v claude-config-volume:/home/agent \
  --entrypoint ls claude-secure-sandbox:latest -la /home/agent /home/agent/.claude
```

---

## Security model (why containers)

```text
Mac host
  ~/.ssh, ~/.aws       ← NOT mounted (protected)
  ~/repos/my-app       ← mounted in (shared on purpose)
  Docker volumes       ← auth lives here (inside Docker)
```

The container can touch **mounted** paths and **its own** filesystem. It cannot see unmounted host secrets — that is the isolation goal.

Ignore files (`.cursorignore`, `.claudeignore`) and `permissions.deny` add project-level guardrails but are not perfect guarantees.

---

## Cleanup after testing

| Action | Effect |
| ------ | ------ |
| `rm -rf ~/repos/test-project` | Removes project files on Mac |
| `/exit` from `claude-box` | Container removed (`--rm`); volume kept |
| `docker volume rm claude-config-volume` | Wipes Case 1 auth; re-login required |
| `docker volume rm claude-code-config-<id>` | Wipes Case 3 auth for that project |
| `docker rmi claude-secure-sandbox:latest` | Removes Case 1 image (rebuild via setup script) |

Deleting a project folder does **not** delete Docker volumes.

---

## Day-to-day: what you need to remember

1. **Image** — reusable template (build or pull once)
2. **Container** — temporary runtime (`claude-box` session)
3. **Volume** — persistent Docker storage (auth)
4. **Bind mount** — your repo folder inside the container
5. **`--rm`** — container auto-cleanup; **volume is separate**
6. **Case 1 and Case 3 use different auth volumes**

---

## See also

- [README.md](README.md) — full playbook setup and workflows
- [Claude Code devcontainer docs](https://code.claude.com/docs/en/devcontainer)
