#!/bin/bash
# =======================================
# Git + GitHub Setup Wizard v17.1
# Fully automatic multi-account SSH & Git
# WSL/Docker/macOS compatible
# Author: Mehedi Hasan (github: madebymehedi)
# =======================================

# -----------------------------
# Colors
# -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

color_echo() { echo -e "${1}${2}${NC}"; }

# -----------------------------
# Environment detection
# -----------------------------
IS_WSL=false
IS_DOCKER=false
OS_TYPE=$(uname)

[[ "$(grep -Ei '(Microsoft|WSL)' /proc/version 2>/dev/null)" ]] && IS_WSL=true
[[ -f /.dockerenv || $(grep docker /proc/1/cgroup 2>/dev/null) ]] && IS_DOCKER=true

# -----------------------------
# Session cache
# -----------------------------
SESSION_CACHE="$HOME/.github_setup_session"

# -----------------------------
# Helpers
# -----------------------------
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    read -p "$prompt (default: $default): " input
    echo "${input:-$default}"
}

ensure_ssh_agent() {
    if [[ -z "$SSH_AGENT_PID" || -z "$SSH_AUTH_SOCK" ]] || ! ssh-add -l &>/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null
        color_echo "$GREEN" "✅ SSH agent started"
    fi
}


ensure_key_added() {
    local key="$1"
    [[ ! -f "$key" ]] && { color_echo "$RED" "❌ SSH key not found: $key"; return 1; }

    if [[ -z "$SSH_AUTH_SOCK" ]] || ! pgrep -u "$USER" ssh-agent >/dev/null; then
        eval "$(ssh-agent -s)" >/dev/null
        color_echo "$GREEN" "✅ SSH agent started"
    fi

    if ssh-add -l 2>/dev/null | grep -q "$(basename "$key")"; then
        color_echo "$YELLOW" "Key already added: $key"
    else
        ssh-add "$key" &>/dev/null
        color_echo "$GREEN" "✅ Key added: $key"
    fi

    echo "$key" > "$SESSION_CACHE"
}



copy_to_clipboard() {
    local pub_key="$1"
    [[ ! -f "$pub_key" ]] && { color_echo "$RED" "❌ Public key not found: $pub_key"; return 1; }
    if command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$pub_key"
    elif command -v pbcopy &>/dev/null; then
        pbcopy < "$pub_key"
    elif $IS_WSL; then
        cat "$pub_key" | clip.exe
    else
        color_echo "$YELLOW" "⚠️ Could not copy automatically. File: $pub_key"
    fi
    color_echo "$GREEN" "✅ Public key copied to clipboard"
}

# -----------------------------
# Git configuration
# -----------------------------
configure_git() {
    read -p "Enter Git user.name: " name
    read -p "Enter Git user.email: " email
    git config --global user.name "$name"
    git config --global user.email "$email"
    color_echo "$GREEN" "✅ Git global config updated"
}

# -----------------------------
# SSH key management
# -----------------------------
generate_or_use_key() {
    local default_name="id_ed25519"
    local key_name
    key_name=$(prompt_with_default "Enter SSH key name or custom" "$default_name")
    SSH_KEY="$HOME/.ssh/$key_name"

    if [[ -f "$SSH_KEY" ]]; then
        color_echo "$YELLOW" "Key exists. Using: $SSH_KEY"
    else
        ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f "$SSH_KEY" -N ""
        color_echo "$GREEN" "✅ Key generated: $SSH_KEY"
    fi

    PUB_KEY="$SSH_KEY.pub"
    [[ -f "$PUB_KEY" ]] && { echo -e "\nCopy this public key to GitHub:\n"; cat "$PUB_KEY"; copy_to_clipboard "$PUB_KEY"; }

    ensure_key_added "$SSH_KEY"
}

list_ssh_keys() {
    echo -e "${BOLD}Detected SSH private keys:${NC}"
    keys=($(ls -1 ~/.ssh/id_* 2>/dev/null | grep -v '\.pub'))
    [[ ${#keys[@]} -eq 0 ]] && { color_echo "$YELLOW" "No SSH keys found"; return; }
    for key in "${keys[@]}"; do
        echo "  $key"
    done
}

# -----------------------------
# Auto-config SSH config for multiple keys
# -----------------------------
auto_configure_ssh_config() {
    ensure_ssh_agent
    mkdir -p ~/.ssh
    config_file="$HOME/.ssh/config"
    touch "$config_file"

    keys=($(ls -1 ~/.ssh/id_* 2>/dev/null | grep -v '\.pub'))
    [[ ${#keys[@]} -eq 0 ]] && { color_echo "$YELLOW" "No SSH keys found in ~/.ssh"; return; }

    color_echo "$BLUE" "🔧 Auto-configuring SSH config for keys..."
    for key in "${keys[@]}"; do
        [[ ! -f "$key" ]] && continue
        alias_name="github-$(basename "$key")"
        if ! grep -q "Host $alias_name" "$config_file"; then
            cat >> "$config_file" <<EOL

Host $alias_name
    HostName github.com
    User git
    IdentityFile ~/.ssh/$key
EOL
            color_echo "$GREEN" "Added host alias: $alias_name -> $key"
        fi
        ensure_key_added "$key"
    done
}

# -----------------------------
# Automatic Git remote URL update per repo
# -----------------------------
auto_update_git_remote() {
    [[ ! -d .git ]] && { color_echo "$RED" "Not a git repository"; return; }

    remote_origin=$(git config --get remote.origin.url)
    [[ -z "$remote_origin" ]] && { color_echo "$RED" "No remote.origin set"; return; }

    keys=($(ls -1 ~/.ssh/id_* 2>/dev/null | grep -v '\.pub'))
    if [[ ${#keys[@]} -gt 1 ]]; then
        echo "Multiple SSH keys detected. Choose one for this repo:"
        select key in "${keys[@]}"; do
            [[ -n "$key" ]] && break
        done
    else
        key="${keys[0]}"
    fi

    alias_name="github-$(basename "$key")"
    new_url="git@$alias_name:$(echo $remote_origin | sed -E 's/.*github.com[:\/](.*)/\1/')"
    git remote set-url origin "$new_url"
    color_echo "$GREEN" "✅ Git remote updated to use $alias_name"
}


# -----------------------------
# Test SSH connection
# -----------------------------
test_ssh() {
    local host="${1:-github.com}"
    local verbose="${2:-false}"
    ensure_ssh_agent
    [[ -f "$SESSION_CACHE" ]] && ssh-add "$(cat "$SESSION_CACHE")" &>/dev/null

    if $verbose; then
        ssh -vT git@"$host"
    else
        output=$(ssh -T git@"$host" 2>&1)
        echo -e "${BLUE}${output}${NC}"
        if echo "$output" | grep -qE "Hi .*!|successfully authenticated"; then
            color_echo "$GREEN" "✅ SSH key is correctly added to GitHub!"
        else
            color_echo "$YELLOW" "⚠️ SSH test may fail with 'Permission denied'. If you see 'Hi <user>!', SSH works."
        fi
    fi
}

# -----------------------------
# Manual mode menu
# -----------------------------
manual_mode() {
    [[ -f "$SESSION_CACHE" ]] && SSH_KEY=$(cat "$SESSION_CACHE") || SSH_KEY="$HOME/.ssh/id_ed25519"

    while true; do
        echo -e "\nSelect an action:"
        echo "1) Configure Git global user/email"
        echo "2) Generate or use SSH key"
        echo "3) Add SSH key to ssh-agent"
        echo "4) Test SSH connection"
        echo "5) Verbose SSH test"
        echo "6) List all SSH keys"
        echo "7) Auto-configure all SSH keys in ~/.ssh/config"
        echo "8) Auto-update Git remote URL for current repo"
        echo "9) Exit"
        read -p "Enter choice [1-9]: " choice

        case $choice in
            1) configure_git ;;
            2) generate_or_use_key ;;
            3) ensure_key_added "$SSH_KEY" ;;
            4) test_ssh ;;
            5) test_ssh "" true ;;
            6) list_ssh_keys ;;
            7) auto_configure_ssh_config ;;
            8) auto_update_git_remote ;;
            9) color_echo "$GREEN" "Exiting wizard."; break ;;
            *) color_echo "$RED" "Invalid choice." ;;
        esac
    done
}

# -----------------------------
# Automatic mode
# -----------------------------
automatic_mode() {
    color_echo "$BOLD" "🚀 Running Automatic Mode..."
    [[ ! $(command -v git) ]] && sudo apt update && sudo apt install git -y

    read -p "Enter GitHub user.name (default: $USER): " git_name
    git_name="${git_name:-$USER}"
    read -p "Enter GitHub email (default: $USER@example.com): " git_email
    git_email="${git_email:-$USER@example.com}"

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"

    auto_configure_ssh_config
    test_ssh
    color_echo "$GREEN" "✅ Automatic setup completed!"
}

# -----------------------------
# Entry
# -----------------------------
echo -e "${BOLD}=======================================${NC}"
echo -e "${BOLD}       Git + GitHub Setup Wizard v17.1       ${NC}"
echo -e "${BOLD}=======================================${NC}"

mode=$(prompt_with_default "Select mode: 1) Automatic 2) Manual" "1")
[[ "$mode" == "1" ]] && automatic_mode || manual_mode
