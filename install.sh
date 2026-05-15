#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:?HOME is not set}"
DRY_RUN=0
FORCE=0
BACKUP_ALL=0
SKIP_ALL=0
OVERWRITE_ALL=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options] [file ...]

Symlink dotfiles from this repository into $HOME.

Options:
  -n, --dry-run     Show what would happen without changing files.
  -f, --force       Overwrite conflicting files without prompting.
  -h, --help        Show this help.

If no files are provided, every repo-root dotfile is linked except .git.
When a target already exists, the script asks whether to skip, overwrite,
or move the existing file aside as a timestamped backup.
USAGE
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %q' "$1"
    shift
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

confirm_action() {
  local target="$1"
  local reply

  if [[ "$FORCE" -eq 1 || "$OVERWRITE_ALL" -eq 1 ]]; then
    printf 'overwrite'
    return
  fi

  if [[ "$BACKUP_ALL" -eq 1 ]]; then
    printf 'backup'
    return
  fi

  if [[ "$SKIP_ALL" -eq 1 ]]; then
    printf 'skip'
    return
  fi

  while true; do
    printf '%s exists. [s]kip, [o]verwrite, [b]ackup, overwrite [a]ll, backup a[l]l, s[k]ip all? ' "$target" >&2
    read -r reply

    case "$reply" in
      s|S|'')
        printf 'skip'
        return
        ;;
      o|O)
        printf 'overwrite'
        return
        ;;
      b|B)
        printf 'backup'
        return
        ;;
      a|A)
        OVERWRITE_ALL=1
        printf 'overwrite'
        return
        ;;
      l|L)
        BACKUP_ALL=1
        printf 'backup'
        return
        ;;
      k|K)
        SKIP_ALL=1
        printf 'skip'
        return
        ;;
      *)
        log "Please enter s, o, b, a, l, or k." >&2
        ;;
    esac
  done
}

discover_dotfiles() {
  local entry name

  for entry in "$DOTFILES_DIR"/.[!.]* "$DOTFILES_DIR"/..?*; do
    [[ -e "$entry" ]] || continue

    name="$(basename "$entry")"
    case "$name" in
      .|..|.git)
        continue
        ;;
    esac

    printf '%s\n' "$name"
  done
}

link_dotfile() {
  local name="$1"
  local source="$DOTFILES_DIR/$name"
  local target="$HOME_DIR/$name"
  local backup target_real source_real action

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    log "Missing source: $source"
    return 1
  fi

  if [[ -L "$target" ]]; then
    target_real="$(readlink "$target")"
    source_real="$source"
    if [[ "$target_real" == "$source_real" ]]; then
      log "Already linked: $target -> $source"
      return 0
    fi
  elif [[ ! -e "$target" ]]; then
    run ln -s "$source" "$target"
    log "Linked: $target -> $source"
    return 0
  fi

  action="$(confirm_action "$target")"
  case "$action" in
    skip)
      log "Skipped: $target"
      ;;
    overwrite)
      run rm -rf "$target"
      run ln -s "$source" "$target"
      log "Linked: $target -> $source"
      ;;
    backup)
      backup="$target.backup.$(date +%Y%m%d%H%M%S)"
      run mv "$target" "$backup"
      run ln -s "$source" "$target"
      log "Backed up: $target -> $backup"
      log "Linked: $target -> $source"
      ;;
  esac
}

main() {
  local files=()
  local arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -f|--force)
        FORCE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        while [[ "$#" -gt 0 ]]; do
          files+=("$1")
          shift
        done
        ;;
      -*)
        log "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${#files[@]}" -eq 0 ]]; then
    while IFS= read -r arg; do
      files+=("$arg")
    done < <(discover_dotfiles)
  fi

  if [[ "${#files[@]}" -eq 0 ]]; then
    log "No dotfiles found."
    exit 0
  fi

  for arg in "${files[@]}"; do
    link_dotfile "$arg"
  done
}

main "$@"
