## Status line (Claude Code CLI)

`.claude/statusline.sh` is wired from `.claude/settings.json`. In the **Claude Code terminal CLI** it shows running context, model, effort, and token usage.

It needs `jq`. If the bar is blank, rebuild the Dev Container (Case 3) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1). Cursor-only sessions do not show this bar.

## RTK (token-saving shell proxy)

[RTK](https://github.com/rtk-ai/rtk) is installed in this container. You do not type `rtk` yourself.

When Claude Code or Cursor Agent runs a **Bash/Shell** command, a hook may rewrite it (`git status` → `rtk git status`). RTK runs the real command, compresses the output, and the agent reads the short version. Built-in tools (Read, Grep, Glob) are not rewritten.

This cuts **bash output** the model has to read. It is not the same as cutting your bill by that percentage.

See savings (inside this container, after the agent has run some shell commands):

```bash
rtk gain          # totals
rtk gain --graph  # with a simple chart
rtk init --show   # confirm the hook is installed
```

If `rtk` is missing, rebuild the Dev Container (Cases 2 & 3) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1).

## Headroom (token compression proxy)

[Headroom](https://github.com/headroomlabs-ai/headroom) is already installed in this container. You do not type `headroom wrap` for daily work.

**What it is.** A local proxy on `127.0.0.1:8787` that compresses bulky context (tool output, logs, files) before it reaches the model. Same answers, fewer tokens. It runs on this machine; prompt content is not sent anywhere to be compressed. Anonymous Headroom telemetry is off.

**RTK vs Headroom.** RTK shrinks **shell** output before the agent reads it. Headroom shrinks **whatever still goes to the LLM**. Keep both.

### Daily use

- **Claude Code** (`claude` in the terminal, or the sidebar extension): already routed. Type `claude` as usual.
- **Cursor Agent** (Composer / chat, Cursor-hosted models): not routed through the proxy. Cursor can call Headroom MCP tools (`headroom_compress`, `headroom_retrieve`, `headroom_stats`). Do **not** enable Cursor's Override OpenAI Base URL for subscription models — that breaks them.

If the proxy is down, Claude **fail-closes** (it will not talk to Anthropic directly). Restart it, then try Claude again:

```bash
bash .devcontainer/start-headroom.sh
```

Case 1 (`claude-box`) starts the proxy in the container entrypoint. Cases 2 and 3 start it when the Dev Container starts.

### Check that it is working

Inside the container (Cursor integrated terminal, or inside `claude-box`):

```bash
curl -sS http://127.0.0.1:8787/health
headroom doctor
```

`health` should say `"status":"healthy"`. `doctor` should show **proxy pass**. The `savings` warning until you have sent a real Claude request is normal.

### Dashboard (live savings)

After Claude has made at least one request through the proxy:

**Cases 2 and 3** (Dev Container): port `8787` is forwarded to your Mac. In a browser on the Mac open:

[http://127.0.0.1:8787/dashboard](http://127.0.0.1:8787/dashboard)

You should see requests and tokens saved.

**Case 1** (`claude-box`): the proxy is loopback inside that container, not published to the Mac. Check from inside the session:

```bash
curl -sS http://127.0.0.1:8787/stats
headroom doctor
headroom dashboard --no-open
```

### If Headroom is missing

Rebuild the Dev Container (Cases 2 & 3) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1). Then `bash .devcontainer/start-headroom.sh`. Logs: `~/.headroom/proxy.log`.

## Change color of only this folder's workspace

Use Cmd+, to open Settings, then:

- Select the Workspace tab.
- Search for Color Theme.
- Set Workbench › Color Theme to your choice

## Store git credentials

- Run `git config --global credential.helper store`
- On first push/pull it will prompt for access credentials; copy-paste from 1Password
- Then it will be stored in `.git-credentials`, and not needed again.
