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

[Headroom](https://github.com/headroomlabs-ai/headroom) runs a local proxy on `127.0.0.1:8787`. Claude Code is pointed at it automatically. Cursor Agent can call Headroom MCP tools (`headroom_compress`, `headroom_retrieve`, `headroom_stats`); Cursor-hosted models are not routed through the proxy.

The proxy must be running. If it is down, Claude fail-closes instead of talking to Anthropic directly.

```bash
curl -sS http://127.0.0.1:8787/health
headroom doctor
headroom dashboard --no-open   # http://127.0.0.1:8787/dashboard
```

Anonymous Headroom telemetry is off (`HEADROOM_BEACON=off`). Do not enable Cursor's Override OpenAI Base URL for Cursor-hosted models.

If the proxy is missing, rebuild the Dev Container (Cases 2 & 3) or re-run `./secure-agent-playbook.sh` on your Mac (Case 1). Then `bash .devcontainer/start-headroom.sh`.

## Change color of only this folder's workspace

Use Cmd+, to open Settings, then:

- Select the Workspace tab.
- Search for Color Theme.
- Set Workbench › Color Theme to your choice

## Store git credentials

- Run `git config --global credential.helper store`
- On first push/pull it will prompt for access credentials; copy-paste from 1Password
- Then it will be stored in `.git-credentials`, and not needed again.
