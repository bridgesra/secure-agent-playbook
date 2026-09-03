## Change color of only this folder's workspace

Use Cmd+, to open Settings, then:

- Select the Workspace tab.
- Search for Color Theme.
- Set Workbench › Color Theme to your choice

## Store git credentials

- Run `git config --global credential.helper store`
- On first push/pull it will prompt for access credentials; copy-paste from 1Password
- Then it will be stored in `.git-credentials`, and not needed again.
