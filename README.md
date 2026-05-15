# dotfiles

Dotfiles managed by symlinking files from this repository into `$HOME`.

## Install

Bootstrap Homebrew, install baseline packages, install global npm tools,
and install Claude Code:

```sh
./setup.sh
```

The baseline Homebrew packages are listed in `Brewfile`. The setup script
also installs `@openai/codex` globally with npm and Claude Code with the
official install script.

After setup completes, run the dotfile installer separately:

```sh
./install.sh
```

## Dotfiles Only

Run:

```sh
./install.sh
```

By default, the installer links every repo-root dotfile except `.git`.
If a target already exists in your home directory, it asks whether to:

- skip it
- overwrite it
- move it aside as a timestamped backup
- apply one of those choices to all remaining conflicts

You can preview changes first:

```sh
./install.sh --dry-run
```

You can link specific files:

```sh
./install.sh .gitconfig .gitignore
```

You can overwrite without prompts:

```sh
./install.sh --force
```
