#!/data/data/com.termux/files/usr/bin/bash
# =========================================
#   Eslam Ramadan | Android Game Booster
#   Termux menu tool (Shizuku-aware) + Auto Update
# =========================================

# Script version and repository info
VERSION="1.0.0"
REPO_URL="https://github.com/EslamRamadan0/Android-Game-Booster.git"
SCRIPT_NAME="game_booster.sh"

# -------- Auto Update --------
auto_update() {
  echo ">>> Checking for updates..."
  
  # Check if we're in a git repository
  if [ -d .git ] && command -v git >/dev/null 2>&1; then
    # Check connectivity to remote repository
    if git fetch origin main >/dev/null 2>&1; then
      LOCAL_HASH=$(git rev-parse HEAD)
      REMOTE_HASH=$(git rev-parse origin/main)
      
      if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
        echo ">>> Update found! Downloading..."
        if git pull --rebase origin main >/dev/null 2>&1; then
          echo ">>> Tool updated to latest version. Please restart the script."
          exit 0
        else
          echo ">>> Update failed. Continuing with current version."
        fi
      else
        echo ">>> You have the latest version."
      fi
    else
      echo ">>> Could not check updates (no internet or repository access)."
    fi
  else
    echo ">>> Not a git repository, skipping auto-update."
  fi
  
  sleep 2
}

# Run update before menu starts
auto_update

# -------- Colors --------
c0='\033[0m'; c1='\033[1;36m'; c2='\033[1;32m'; c3='\033[1;33m'; c4='\033[1;31m'

# Detect rish (Shizuku)
has_rish=false
if command -v rish >/dev/null 2>&1; then
  has_rish=true
fi

# Save/restore store
STATE_DIR="$HOME/.eslam_gamebooster"
mkdir -p "$STATE_DIR"
ANIM_BAK="$STATE_DIR/anim_scales.bak"
SYNC_BAK="$STATE_DIR/sync_state.bak"

banner() {
  clear
  echo -e "${c1}"
  echo "  ███████ ███████ ██      █████  ███    ███     ██████   █████  ██████   █████  ███    ██ "
  echo "  ██      ██      ██     ██   ██ ████  ████     ██   ██ ██   ██ ██   ██ ██   ██ ████   ██ "
  echo "  ███████ █████   ██     ███████ ██ ████ ██     ██████  ███████ ██   ██ ███████ ██ ██  ██ "
  echo "       ██ ██      ██     ██   ██ ██  ██  ██     ██   ██ ██   ██ ██   ██ ██   ██ ██  ██ ██ "
  echo "  ███████ ███████ ██████ ██   ██ ██      ██     ██   ██ ██   ██ ██████  ██   ██ ██   ████ "
  echo -e "${c0}"
  echo -e "             ${c3}Android Game Booster by Eslam Ramadan${c0}"
  echo -e "             ${c2}Version: $VERSION${c0}"
  if $has_rish; then
    echo -e "             ${c2}Shizuku detected: YES${c0}"
  else
    echo -e "             ${c4}Shizuku detected: NO${c0}"
  fi
  echo
}

msg() { echo -e "$1$2${c0}"; }
pause() { echo ""; read -p "Press Enter to return to menu..."; }

# -------- Basics (no root) --------
install_essentials() {
  msg "$c3" ">>> Installing Termux Essentials..."
  pkg update -y && pkg upgrade -y
  pkg install -y git curl wget nano python python-pip termux-api
  msg "$c2" ">>> Essentials installed successfully."
}

light_clean_termux() {
  msg "$c3" ">>> Cleaning Termux own caches/logs..."
  rm -rf "$HOME"/.cache/* 2>/dev/null
  find "$PREFIX/var/cache" -type f -delete 2>/dev/null
  find "$PREFIX/tmp" -mindepth 1 -delete 2>/dev/null
  msg "$c2" ">>> Termux cache cleaned."
}

focus_termux_only() {
  msg "$c3" ">>> Minimizing Termux overhead for focus session..."
  if command -v sv >/dev/null 2>&1; then
    for s in "$PREFIX"/var/service/*; do [ -d "$s" ] && sv down "$s" 2>/dev/null; done
  fi
  export PYTHONOPTIMIZE=2
  msg "$c2" ">>> Lightweight session variables applied."
}

# -------- Shizuku-powered helpers --------
SHELL_RUN() {
  if $has_rish; then
    rish "$@"
  else
    "$@"
  fi
}

backup_anim_scales() {
  if [ ! -f "$ANIM_BAK" ]; then
    local w a t
    w=$(SHELL_RUN settings get global window_animation_scale 2>/dev/null)
    a=$(SHELL_RUN settings get global animator_duration_scale 2>/dev/null)
    t=$(SHELL_RUN settings get global transition_animation_scale 2>/dev/null)
    echo "${w:-1.0}|${a:-1.0}|${t:-1.0}" > "$ANIM_BAK"
  fi
}

set_anim_scales() {
  local val="$1"
  backup_anim_scales
  SHELL_RUN settings put global window_animation_scale "$val"
  SHELL_RUN settings put global animator_duration_scale "$val"
  SHELL_RUN settings put global transition_animation_scale "$val"
}

restore_anim_scales() {
  if [ -f "$ANIM_BAK" ]; then
    IFS='|' read -r w a t < "$ANIM_BAK"
    SHELL_RUN settings put global window_animation_scale "${w:-1.0}"
    SHELL_RUN settings put global animator_duration_scale "${a:-1.0}"
    SHELL_RUN settings put global transition_animation_scale "${t:-1.0}"
    msg "$c2" ">>> Animation scales restored."
  fi
}

backup_sync() {
  if [ ! -f "$SYNC_BAK" ]; then
    s=$(SHELL_RUN settings get global master_sync 2>/dev/null)
    echo "${s:-1}" > "$SYNC_BAK"
  fi
}

set_master_sync() {
  local v="$1"
  backup_sync
  SHELL_RUN settings put global master_sync "$v"
}

restore_sync() {
  if [ -f "$SYNC_BAK" ]; then
    v=$(cat "$SYNC_BAK")
    SHELL_RUN settings put global master_sync "${v:-1}"
    msg "$c2" ">>> Master sync restored."
  fi
}

kill_background_apps() {
  msg "$c3" ">>> Killing background apps..."
  if SHELL_RUN am kill-all 2>/dev/null; then
    msg "$c2" ">>> Done."
  else
    msg "$c4" ">>> Failed."
  fi
}

force_stop_package() {
  read -rp "Enter package name: " P
  [ -n "$P" ] && SHELL_RUN am force-stop "$P"
}

compile_speed_package() {
  read -rp "Enter package: " P
  [ -n "$P" ] && SHELL_RUN cmd package compile -m speed -f "$P"
}

game_mode_on() {
  msg "$c3" ">>> Game Mode ON..."
  if $has_rish; then
    set_anim_scales 0.0
    set_master_sync 0
    kill_background_apps
    msg "$c2" ">>> Game Mode Activated."
  else
    msg "$c4" ">>> Shizuku not available. Please install Shizuku and rish for full functionality."
  fi
}

game_mode_off() {
  msg "$c3" ">>> Restoring system..."
  restore_anim_scales
  restore_sync
  msg "$c2" ">>> Restored."
}

# New function to install the tool from GitHub
install_tool() {
  msg "$c3" ">>> Installing/Updating Android Game Booster..."
  
  # Check if git is available
  if ! command -v git >/dev/null 2>&1; then
    msg "$c4" ">>> Git is not installed. Installing now..."
    pkg update -y && pkg install -y git
  fi
  
  # Clone or update the repository
  if [ -d "$HOME/Android-Game-Booster" ]; then
    msg "$c3" ">>> Tool already installed. Updating..."
    cd "$HOME/Android-Game-Booster"
    if git pull origin main; then
      chmod +x "$SCRIPT_NAME"
      msg "$c2" ">>> Update successful."
    else
      msg "$c4" ">>> Update failed."
    fi
  else
    cd "$HOME"
    if git clone "$REPO_URL"; then
      msg "$c2" ">>> Tool downloaded successfully."
      cd "Android-Game-Booster"
      chmod +x "$SCRIPT_NAME"
    else
      msg "$c4" ">>> Failed to download tool. Check your internet connection."
      return 1
    fi
  fi
  
  msg "$c2" ">>> Installation complete. You can run the tool with:"
  msg "$c2" ">>> cd ~/Android-Game-Booster && ./$SCRIPT_NAME"
}

show_help() {
  echo -e "${c1}Android Game Booster - Help${c0}"
  echo
  echo "This tool helps optimize your Android device for gaming through Termux."
  echo
  echo "For full functionality, you need:"
  echo "1. Shizuku installed and running on your device"
  echo "2. Rish installed in Termux: pkg install shizuku"
  echo
  echo "Without Shizuku, some features will not work."
  echo
  read -p "Press Enter to continue..."
}

menu() {
  banner
  echo -e "${c2}[1]${c0} Install Termux Essentials"
  echo -e "${c2}[2]${c0} Light Clean Termux"
  echo -e "${c2}[3]${c0} Focus Termux"
  echo -e "${c2}[4]${c0} Game Mode ON"
  echo -e "${c2}[5]${c0} Game Mode OFF"
  echo -e "${c2}[6]${c0} Kill Background Apps"
  echo -e "${c2}[7]${c0} Force Stop Package"
  echo -e "${c2}[8]${c0} Compile Package for Speed"
  echo -e "${c2}[9]${c0} Install/Update This Tool"
  echo -e "${c2}[H]${c0} Help"
  echo -e "${c2}[0]${c0} Exit"
  echo
  read -rp "Choose option: " ch
  case "$ch" in
    1) install_essentials; pause ;;
    2) light_clean_termux; pause ;;
    3) focus_termux_only; pause ;;
    4) game_mode_on; pause ;;
    5) game_mode_off; pause ;;
    6) kill_background_apps; pause ;;
    7) force_stop_package; pause ;;
    8) compile_speed_package; pause ;;
    9) install_tool; pause ;;
    h|H) show_help; ;;
    0) exit 0 ;;
    *) msg "$c4" "Invalid choice."; pause ;;
  esac
}

# Main execution
while true; do
  menu
done
