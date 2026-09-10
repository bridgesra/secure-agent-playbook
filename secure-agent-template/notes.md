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

## Change color of only this folder's workspace

Use Cmd+, to open Settings, then:

- Select the Workspace tab.
- Search for Color Theme.
- Set Workbench › Color Theme to your choice

## Store git credentials

- Run `git config --global credential.helper store`
- On first push/pull it will prompt for access credentials; copy-paste from 1Password
- Then it will be stored in `.git-credentials`, and not needed again.
