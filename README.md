# dotfiles

Configuration and workstation provisioning for Linux and macOS development
machines. One command takes a fresh box to a working environment: shell, editor,
git, containers, language toolchains and the applications around them.

```bash
git clone https://github.com/ivanbila/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh --packages
```

`install.sh` links the dotfiles into `$HOME` and then runs the setup script for
the current OS. Both halves are safe to re-run: everything checks before it
installs.

---

## What you get

| Area | Tools |
| --- | --- |
| Shell | zsh, oh-my-zsh, spaceship prompt, autosuggestions, syntax highlighting, fzf, zoxide, direnv |
| Terminal | ripgrep, fd, bat, eza, jq, yq, htop/btop, tmux, tldr, hyperfine, just, ncdu |
| Git | git, git-lfs, delta, lazygit, GitHub CLI, pre-commit, a large alias set |
| Containers | Docker Engine + Compose v2 + Buildx (Linux), Colima or Docker Desktop (macOS), lazydocker, dive, ctop |
| Kubernetes | kubectl, helm, k9s, kind, kubectx/kubens, stern |
| Cloud | AWS CLI v2, Terraform, Ansible |
| Languages | Node (nvm), Python (pipx + uv + poetry), Go, Rust (rustup), Java/Maven/Gradle (SDKMAN), PHP + Composer + Laravel, Ruby (rbenv) |
| Databases | psql, mysql/mariadb, redis, sqlite clients plus pgcli and mycli |
| Editors | vim (vim-plug), Neovim, VS Code, JetBrains Toolbox and Sublime on macOS |
| Apps | Chrome, Firefox, Slack, Discord, Signal, Telegram, Postman, Obsidian, VLC, Spotify |
| Fonts | JetBrains Mono, FiraCode and Hack Nerd Fonts, powerline fonts |

Database and cache **servers** are deliberately not installed on the host — run
them per-project with `docker compose`, and keep only the clients locally.

---

## Layout

```
.
├── install.sh                    symlink the dotfiles into $HOME
├── setup-linux-workstation.sh    provision Debian/Ubuntu
├── setup-macos-workstation.sh    provision macOS
├── home/                         everything linked into $HOME
│   ├── .zshrc  .exports  .aliases  .functions
│   ├── .gitconfig  .gitignore_global  .git-commit-template.txt
│   ├── .vimrc  .vim/plugins.vim
│   └── .tmux.conf  .editorconfig
├── lib/                          shared shell helpers
│   ├── common.sh                 logging, dry-run, module selection
│   ├── apt.sh                    idempotent apt/dpkg/repository helpers
│   └── shell.sh                  oh-my-zsh and prompt setup
├── packages/                     Homebrew bundles
│   ├── Brewfile                  core CLI toolchain
│   ├── Brewfile.extras           cloud, Kubernetes, databases
│   └── Brewfile.casks            GUI applications and fonts
└── macos/defaults.sh             opinionated macOS system preferences
```

Anything placed under `home/` is mirrored into `$HOME` at the same relative
path, so adding a new dotfile only means dropping it in and re-running
`./install.sh`.

---

## Installing

### Dotfiles only

```bash
./install.sh              # link, back up whatever was there before
./install.sh --dry-run    # show what would change, touch nothing
```

Existing real files are moved to `~/.dotfiles-backup/<timestamp>/` before being
replaced. Files already linked to this repo are left alone.

The installer also prompts once for your git identity and writes it to
`~/.gitconfig.local`, which is included by `home/.gitconfig` but never
committed — so the repository stays free of names, emails and key IDs.

### Linux (Debian / Ubuntu)

```bash
./setup-linux-workstation.sh                    # everything
./setup-linux-workstation.sh --list             # show the modules
./setup-linux-workstation.sh --only docker,node
./setup-linux-workstation.sh --skip apps,php
./setup-linux-workstation.sh --headless         # servers and WSL: no GUI apps
./setup-linux-workstation.sh --php-version 8.4
./setup-linux-workstation.sh --dry-run
```

Modules: `core cli shell docker node python go rust java php ruby db k8s cloud
editors apps fonts`.

Repositories are added with `signed-by` keyrings under `/etc/apt/keyrings`
rather than the deprecated `apt-key`, and every package is checked before it is
installed, so a second run is close to a no-op.

### macOS

```bash
./setup-macos-workstation.sh                    # everything except system defaults
./setup-macos-workstation.sh --minimal          # core CLI only
./setup-macos-workstation.sh --no-casks         # no GUI applications
./setup-macos-workstation.sh --docker-desktop   # Docker Desktop instead of Colima
./setup-macos-workstation.sh --defaults         # also apply macos/defaults.sh
```

Modules: `core brew extras casks shell docker node python java rust defaults`.

Installs the Xcode Command Line Tools, Rosetta 2 on Apple Silicon and Homebrew,
then applies the three Brewfiles.

---

## Containers

**Linux** gets Docker Engine from Docker's own apt repository, with Compose v2
and Buildx as CLI plugins. Your user is added to the `docker` group, so log out
and back in (or run `newgrp docker`) before using `docker` without `sudo`.

**macOS** defaults to [Colima](https://github.com/abiosoft/colima) with the
plain Docker CLI: same `docker` and `docker compose` commands, no Docker Desktop
licence to worry about. The VM is created with 4 CPUs, 8 GiB of RAM and a 60 GiB
disk:

```bash
colima start                     # start the runtime
colima stop                      # reclaim the resources
colima status
```

Pass `--docker-desktop` to the setup script if you would rather have Docker
Desktop; nothing else in the configuration changes.

Useful aliases: `dc` (compose), `dcu`/`dcd` (up/down), `dcl` (logs), `dps`
(formatted `ps`), `dprune` (reclaim disk), `dsh <container>` (shell inside a
container), `ld` (lazydocker).

---

## Customising

| File | Purpose |
| --- | --- |
| `~/.zshrc.local` | Machine-specific shell config, work secrets, extra PATH entries |
| `~/.gitconfig.local` | Git identity and signing key |
| `home/.exports` | Environment variables and PATH, shared by zsh and bash |
| `home/.aliases` | Aliases, grouped by tool |
| `home/.functions` | Functions: `mkcd`, `extract`, `killport`, `dsh`, `gco`, `update-all`, ... |

Both `.local` files are gitignored. Nothing in this repository reads a secret,
and nothing writes one into a tracked file.

Handy entry points once installed:

```bash
update-all        # apt/brew/snap/npm/pipx/rustup/oh-my-zsh in one go
killport 3000     # free a port a dev server is squatting on
gco               # fuzzy-pick a branch and check it out
extract file.tgz  # any archive format
```

---

## Notes

- **Shell startup speed.** `nvm` is loaded lazily on first use of
  `nvm`/`node`/`npm`/`npx`/`yarn`/`pnpm`, and the completion cache is rebuilt at
  most once a day. Startup stays under ~150 ms on a warm cache.
- **Everything is guarded.** `.zshrc` works on a machine with none of these
  tools installed and gets better as they appear, so the same dotfiles work on a
  locked-down server and a full workstation.
- **Optional steps never abort a run.** A failed third-party download warns and
  the script continues; the summary at the end tells you which modules ran.
- **WSL** is detected: systemd service enablement and GUI apps are skipped.

## Testing

CI runs `shellcheck` and `shfmt` over every script, parses the zsh, git, tmux
and vim configuration, and dry-runs the installer on both Ubuntu and macOS.
Locally:

```bash
shellcheck --external-sources install.sh setup-*.sh lib/*.sh macos/*.sh
./install.sh --dry-run
```

## License

MIT — see [LICENSE](LICENSE).
