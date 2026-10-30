# zsh-utm

> UTM virtual machines for Zsh — start, stop, check status and snapshot from the shell.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![CI](https://github.com/zsh-contrib/zsh-utm/actions/workflows/ci.yml/badge.svg)](https://github.com/zsh-contrib/zsh-utm/actions/workflows/ci.yml)

Stop clicking through the UTM window. `zsh-utm` adds a single `utm` command on top of `utmctl`, the command line tool that ships with [UTM](https://mac.getutm.app), with tab completion for subcommands, virtual machine names and snapshot names, and a `--wait` that `utmctl` does not have.

## Requirements

- macOS with [UTM](https://mac.getutm.app) installed, which provides `utmctl` (the Homebrew cask links it onto your `PATH`, otherwise the plugin uses the copy inside `UTM.app`)
- [gum](https://github.com/charmbracelet/gum) (`gum`, optional — logs fall back to plain stderr)

The first time you run `utm`, macOS asks whether your terminal may control UTM. Allow it under System Settings → Privacy & Security → Automation.

**macOS (Homebrew):**

```bash
brew install gum
```

## Installation

### Using zinit

```zsh
zinit load zsh-contrib/zsh-utm
```

### Using sheldon

```toml
[plugins.zsh-utm]
github = "zsh-contrib/zsh-utm"
```

### Manual

```bash
git clone https://github.com/zsh-contrib/zsh-utm.git ~/.zsh/zsh-utm
echo 'source ~/.zsh/zsh-utm/zsh-utm.plugin.zsh' >> ~/.zshrc
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZSH_UTM_TIMEOUT` | `60` | Seconds `--wait` polls before giving up |
| `GUM_LOG_LEVEL` | `info` | Log level: `error`, `warn`, `info`, `debug` |
| `DEBUG` | unset | Sets `GUM_LOG_LEVEL=debug` and enables xtrace |

## Usage

A `<vm>` is a virtual machine name or UUID.

### `utm list`

List virtual machines and their status, tab separated.

### `utm start <vm>`

```bash
utm start Ubuntu          # start
utm start Ubuntu -w       # wait until it is running
utm start Ubuntu -d       # disposable: discard changes on shutdown
```

### `utm stop <vm>`

```bash
utm stop Ubuntu           # ask the guest to shut down
utm stop Ubuntu -f        # force shutdown
utm stop Ubuntu -k        # kill the VM process
utm stop Ubuntu -s        # suspend and save state
utm stop Ubuntu -w        # wait until it has stopped
```

### `utm status [vm]`

Print the status of one virtual machine (`started`, `stopped`, ...), or of all of them. With a `<vm>` only the status word is printed, so it is easy to script:

```bash
[[ "$(utm status Ubuntu)" == started ]] && echo running
```

### `utm snapshot <vm> [action] [name]`

Snapshots are only available for QEMU virtual machines.

```bash
utm snapshot Ubuntu                      # list, newest first
utm snapshot Ubuntu create clean         # save the current state
utm snapshot Ubuntu restore clean        # go back to it
utm snapshot Ubuntu overwrite clean      # replace it with the current state
utm snapshot Ubuntu rename clean fresh   # rename it
utm snapshot Ubuntu delete fresh         # remove it
```

## How It Works

Each subcommand calls `utmctl` and keeps the output stable, so scripts keep working: `utm list` prints `name<TAB>status` even though `utmctl list` prints `UUID Status Name`, and `utm status <vm>` prints only the status word. Virtual machine and snapshot names are passed as single arguments, so names with quotes or spaces are safe. `utmctl` stops a machine by force unless told otherwise, so `utm stop` asks the guest to shut down explicitly. `--wait` polls `utmctl status` once a second until the machine reaches the target status or `ZSH_UTM_TIMEOUT` runs out.

Tab completion asks UTM for virtual machine and snapshot names, so the first completion can take a moment (and launches UTM if it is not running).

## Troubleshooting

- **`utmctl not found`**: install UTM, or link it yourself with `ln -s /Applications/UTM.app/Contents/MacOS/utmctl /opt/homebrew/bin/utmctl`.
- **Snapshot commands fail**: snapshots need a QEMU virtual machine, Apple Virtualization machines do not support them.
- **`--wait` times out**: raise `ZSH_UTM_TIMEOUT`, and check the guest actually honors a shutdown request (otherwise use `-f`).

## The zsh-contrib Ecosystem

| Repo | What it provides |
|------|-----------------|
| [zsh-aws](https://github.com/zsh-contrib/zsh-aws) | AWS credential management with aws-vault and tmux |
| [zsh-eza](https://github.com/zsh-contrib/zsh-eza) | eza with Catppuccin and Rose Pine theming |
| [zsh-fzf](https://github.com/zsh-contrib/zsh-fzf) | fzf with Catppuccin and Rose Pine theming |
| [zsh-tmux](https://github.com/zsh-contrib/zsh-tmux) | Automatic tmux window title management |
| **zsh-utm** ← you are here | UTM virtual machine control from the shell |
| [zsh-vivid](https://github.com/zsh-contrib/zsh-vivid) | vivid LS_COLORS generation with theme support |

## License

[MIT](LICENSE) — Copyright (c) 2026 zsh-contrib

<!-- markdownlint-disable-file MD013 -->
