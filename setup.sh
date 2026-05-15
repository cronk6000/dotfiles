#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

log() {
  printf '%s\n' "$*"
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed: $(brew --prefix)"
    return
  fi

  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    log "Homebrew install finished, but brew was not found in the expected locations." >&2
    exit 1
  fi
}

install_packages() {
  log "Installing Homebrew packages from Brewfile..."
  brew bundle --file "$DOTFILES_DIR/Brewfile"
}

install_npm_packages() {
  if command -v codex >/dev/null 2>&1; then
    log "Codex already installed: $(command -v codex)"
    return
  fi

  log "Installing global npm packages..."
  npm install -g @openai/codex
}

install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed: $(command -v claude)"
    return
  fi

  log "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
}

install_starship() {
  if command -v starship >/dev/null 2>&1; then
    log "Starship already installed: $(command -v starship)"
    return
  fi

  log "Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh
}

configure_macos_headless() {
  if [[ "${OSTYPE:-}" != darwin* ]]; then
    return
  fi

  "$DOTFILES_DIR/macos-headless.sh"
}

print_next_steps() {
  log ""
  log "Setup complete."
  log "To link dotfiles into your home directory, run:"
  log "  $DOTFILES_DIR/install.sh"
}

main() {
  install_homebrew
  install_packages
  install_npm_packages
  install_claude
  install_starship
  configure_macos_headless
  print_next_steps
}

main "$@"
