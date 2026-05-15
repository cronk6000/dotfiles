#!/usr/bin/env bash

set -euo pipefail

DESIRED_COMPUTER_NAME="cronk"
DESIRED_LOCAL_HOST_NAME="cronk"
DESIRED_HOST_NAME="cronk.local"

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

cache_sudo() {
  echo "Caching sudo credentials..."
  sudo -v
}

pm_key_supported() {
  local key="$1"
  pmset -g custom 2>/dev/null | awk '{ print $1 }' | grep -qx "$key"
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
  local current updated

  current="$(pm_value "$key")"
  if [[ "$current" == "$desired" ]]; then
    ok "$description ($key=$desired)."
    return
  fi

  echo "$description is not set. Current ${key:-setting}: ${current:-unknown}; desired: $desired."
  if prompt_yes_no "Set $description?" "y"; then
    run_sudo pmset -a "$key" "$desired"
    updated="$(pm_value "$key")"
    if [[ "$updated" == "$desired" ]]; then
      ok "$description ($key=$desired)."
    else
      skip "$description did not change after pmset write. Current $key: ${updated:-unknown}."
    fi
  else
    skip "$description left unchanged."
  fi
}

configure_pmset_value_if_supported() {
  local key="$1"
  local desired="$2"
  local description="$3"

  if ! pm_key_supported "$key"; then
    skip "$description is not supported on this Mac/macOS version ($key)."
    return
  fi

  configure_pmset_value "$key" "$desired" "$description"
}

configure_scutil_value() {
  local key="$1"
  local desired="$2"
  local current

  current="$(scutil --get "$key" 2>/dev/null || true)"
  if [[ "$current" == "$desired" ]]; then
    ok "$key is $desired."
    return
  fi

  echo "$key is '${current:-not set}'; desired: '$desired'."
  if prompt_yes_no "Set $key to $desired?" "y"; then
    run_sudo scutil --set "$key" "$desired"
  else
    skip "$key left unchanged."
  fi
}

configure_hostnames() {
  configure_scutil_value "ComputerName" "$DESIRED_COMPUTER_NAME"
  configure_scutil_value "LocalHostName" "$DESIRED_LOCAL_HOST_NAME"
  configure_scutil_value "HostName" "$DESIRED_HOST_NAME"
}

configure_firewall() {
  local status

  status="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)"
  if [[ "$status" == *"enabled"* || "$status" == *"State = 1"* ]]; then
    ok "Firewall is enabled."
    return
  fi

  echo "Firewall is disabled."
  if prompt_yes_no "Enable macOS firewall?" "y"; then
    run_sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
  else
    skip "Firewall left unchanged."
  fi
}

configure_remote_login() {
  local status

  status="$(sudo systemsetup -getremotelogin 2>/dev/null || true)"
  if [[ "$status" == *"Remote Login: On"* ]]; then
    ok "Remote Login is on."
    return
  fi

  skip "Remote Login is not on."
  echo "Enable it manually: System Settings -> General -> Sharing -> Remote Login"
  echo "Then review: Allow access for: Only these users"
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

  cache_sudo
  echo ""

  configure_hostnames
  configure_filevault
  if pm_key_supported "autorestartatconnect"; then
    configure_pmset_value_if_supported "autorestartatconnect" "1" "Automatic startup when power is connected"
  else
    configure_pmset_value_if_supported "autorestart" "1" "Automatic restart after power loss"
  fi
  configure_pmset_value_if_supported "sleep" "0" "System sleep disabled"
  configure_pmset_value_if_supported "womp" "1" "Wake for network access"
  configure_pmset_value_if_supported "tcpkeepalive" "1" "TCP keepalive during sleep"
  configure_pmset_value_if_supported "ttyskeepawake" "1" "Prevent sleep while remote sessions are active"
  configure_firewall
  configure_remote_login
  configure_restart_on_freeze

  echo ""
  echo "Auto-login is not configured."
  echo "Core LaunchDaemons and SSH can run without auto-login if FileVault is off."
  echo "User LaunchAgents, GUI apps, camera permissions, and browser workflows may require a logged-in user session."
  echo ""
  echo "Manual review:"
  echo "- System Settings -> General -> Sharing -> Remote Login -> Allow access for: Only these users"
  echo "- System Settings -> General -> Sharing -> Screen Sharing or Remote Management"
  echo "- System Settings -> Users & Groups -> Automatically log in as ... if this Mac runs GUI automation"
}

main "$@"
