# Git + GitHub Setup Wizard v17.1

A fully automated Git and GitHub setup wizard for multi-account SSH management. Works seamlessly on **WSL**, **Docker**, and **macOS**. Automatically configures SSH keys, Git global configuration, and Git remotes.

## Features

- Configure Git global `user.name` and `user.email`
- Generate new or use existing SSH keys
- Automatically start `ssh-agent` and add keys
- Auto-detect multiple SSH keys and configure `~/.ssh/config`
- Auto-update Git remote URLs per selected SSH key
- Test SSH connections with GitHub
- Manual and automatic setup modes

## Requirements

- Bash shell
- Git
- `ssh-agent`
- Optional: `xclip` (Linux) or `pbcopy` (macOS) for automatic clipboard copy
- WSL/Docker/macOS compatible

## Installation

Clone the repository:

```bash
git clone https://github.com/madebymehedi/git-setup-cli.git
cd github-setup-wizard
chmod +x setup-wizard.sh
````

## Usage

### Automatic Mode

```bash
./git-setup-cli
# Select mode 1 (Automatic)
```

This will:

* Install Git if missing
* Configure default Git username/email
* Auto-configure SSH keys and GitHub host aliases
* Test SSH connection

### Manual Mode

```bash
./git-setup-cli
# Select mode 2 (Manual)
```

You can then:

1. Configure Git username/email
2. Generate or select an SSH key
3. Add SSH key to `ssh-agent`
4. Test SSH connection
5. List SSH keys
6. Auto-configure SSH keys in `~/.ssh/config`
7. Auto-update Git remote URL per selected key

## Notes

* Automatically detects multiple SSH keys and adds host aliases like `github-id_ed25519`
* Stores the last added key in `~/.github_setup_session`
* Clipboard copy supported on Linux, macOS, and WSL
* If `ssh-agent` fails to start, ensure your environment supports it
