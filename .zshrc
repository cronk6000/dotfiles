# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Editor
export EDITOR="vim"
export VISUAL="$EDITOR"

# Locale
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Privacy
export GH_TELEMETRY=false
export DO_NOT_TRACK=true

# Paths
path=(
  "$HOME/bin"
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  "$path[@]"
)

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

# Shell behavior
setopt auto_cd
setopt interactive_comments
setopt no_beep

# Tool initialization
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# Machine-specific config
if [[ -f "$HOME/.zsh_extra" ]]; then
  source "$HOME/.zsh_extra"
fi
