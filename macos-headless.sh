#!/usr/bin/env bash

set -euo pipefail

if [[ "${OSTYPE:-}" != darwin* ]]; then
  echo "macos-headless.sh only applies to macOS."
  exit 0
fi

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local reply suffix

  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  printf "%s %s " "$prompt" "$suffix"
  read -r reply

  case "$reply" in
    y|Y|yes|YES)
      return 0
      ;;
    n|N|no|NO)
      return 1
      ;;
    "")
      [[ "$default" == "y" ]]
      ;;
    *)
      echo "Please answer y or n."
      prompt_yes_no "$prompt" "$default"
      ;;
  esac
}

ok() {
  printf "✓ %s\n" "$*"
}

skip() {
  printf "[skip] %s\n" "$*"
}

run_sudo() {
  sudo "$@"
}

pm_value() {
  local key="$1"
  pmset -g custom 2>/dev/null | awk -v key="$key" '$1 == key { value = $2 } END { if (value != "") print value }'
}

configure_filevault() {
  local status

  status="$(fdesetup status 2>/dev/null || true)"
  if [[ "$status" == *"FileVault is Off."* ]]; then
    ok "FileVault is off."
    return
  fi

  if [[ "$status" == *"FileVault is On."* ]]; then
    echo "FileVault is on. A headless Mac cannot fully boot unattended with FileVault enabled."
    if prompt_yes_no "Disable FileVault?" "n"; then
      run_sudo fdesetup disable
    else
      skip "FileVault left unchanged."
    fi
    return
  fi

  echo "Could not determine FileVault status: ${status:-unknown}"
  skip "FileVault left unchanged."
}

configure_pmset_value() {
  local key="$1"
  local desired="$2"
  local description="$3"
  local current

  current="$(pm_value "$key")"
  if [[ "$current" == "$desired" ]]; then
    ok "$description ($key=$desired)."
    return
  fi

  echo "$description is not set. Current ${key:-setting}: ${current:-unknown}; desired: $desired."
  if prompt_yes_no "Set $description?" "y"; then
    run_sudo pmset -a "$key" "$desired"
  else
    skip "$description left unchanged."
  fi
}

configure_remote_login() {
  local status

  status="$(sudo systemsetup -getremotelogin 2>/dev/null || true)"
  if [[ "$status" == *"Remote Login: On"* ]]; then
    ok "Remote Login is on."
    return
  fi

  echo "Remote Login is not on. SSH is useful for recovering a headless Mac."
  if prompt_yes_no "Enable Remote Login?" "y"; then
    run_sudo systemsetup -setremotelogin on
  else
    skip "Remote Login left unchanged."
  fi
}

configure_restart_on_freeze() {
  local status

  status="$(sudo systemsetup -getrestartfreeze 2>/dev/null || true)"
  if [[ "$status" == *"Restart After Freeze: On"* ]]; then
    ok "Restart after freeze is on."
    return
  fi

  echo "Restart after freeze is not on."
  if prompt_yes_no "Enable restart after freeze?" "y"; then
    run_sudo systemsetup -setrestartfreeze on
  else
    skip "Restart after freeze left unchanged."
  fi
}

main() {
  echo "Configuring macOS for headless operation."
  echo "You may be prompted for your administrator password for system settings."
  echo ""

  configure_filevault
  configure_pmset_value "autorestart" "1" "Automatic restart after power loss"
  configure_pmset_value "sleep" "0" "System sleep disabled on AC power"
  configure_pmset_value "womp" "1" "Wake for network access"
  configure_pmset_value "tcpkeepalive" "1" "TCP keepalive during sleep"
  configure_pmset_value "ttyskeepawake" "1" "Prevent sleep while remote sessions are active"
  configure_remote_login
  configure_restart_on_freeze

  echo ""
  echo "Auto-login is not configured. For a headless Mac, SSH and Screen Sharing are preferable to auto-login."
}

main "$@"
