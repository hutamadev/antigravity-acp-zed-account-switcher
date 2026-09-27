#!/usr/bin/env bash
# agy-account.sh
# Multi-Account Manager & Seamless Switcher for Antigravity ACP (Zed Editor)
# Part of zed-backup suite

set -e

ACP_DIR="${HOME}/.gemini/antigravity-acp"
TOKEN_FILE="${ACP_DIR}/acp_token.json"
PROFILES_DIR="${ACP_DIR}/profiles"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

mkdir -p "$PROFILES_DIR"

print_banner() {
    echo -e "${CYAN}${BOLD}=== Antigravity ACP Account Manager ===${NC}"
}

print_usage() {
    print_banner
    echo -e "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}status${NC}              Show currently active Google account"
    echo -e "  ${GREEN}list${NC}                List all saved account profiles"
    echo -e "  ${GREEN}save <name>${NC}         Save currently active account as a profile"
    echo -e "  ${GREEN}switch <name>${NC}       Switch active account to a saved profile"
    echo -e "  ${GREEN}new${NC}                 Prepare for logging into a new Google account"
    echo -e "  ${GREEN}delete <name>${NC}       Delete a saved profile"
    echo -e "  ${GREEN}help${NC}                Show this help message"
    echo ""
}

# Helper: Fetch email from token file via Google OAuth userinfo
get_token_email() {
    local target_file="$1"
    if [[ ! -f "$target_file" ]]; then
        echo "No token file"
        return 1
    fi

    python3 - <<EOF
import json, urllib.request, urllib.parse, sys

try:
    with open("$target_file") as f:
        conf = json.load(f)
    data = urllib.parse.urlencode({
        'client_id': conf['client_id'],
        'client_secret': conf['client_secret'],
        'refresh_token': conf['refresh_token'],
        'grant_type': 'refresh_token'
    }).encode()
    req = urllib.request.Request(conf.get('token_uri', 'https://oauth2.googleapis.com/token'), data=data)
    with urllib.request.urlopen(req, timeout=5) as resp:
        tokens = json.loads(resp.read().decode())
    access_token = tokens['access_token']
    req_user = urllib.request.Request('https://www.googleapis.com/oauth2/v3/userinfo', headers={'Authorization': f'Bearer {access_token}'})
    with urllib.request.urlopen(req_user, timeout=5) as resp:
        info = json.loads(resp.read().decode())
        print(info.get('email', 'Unknown'))
except Exception as e:
    print(f"Error: {e}")
EOF
}

# Helper: Restart background ACP daemon cleanly
restart_daemon() {
    echo -e "${BLUE}==>${NC} Restarting Antigravity ACP background process..."
    if pgrep -f "agy_acp_server.par" >/dev/null 2>&1; then
        pkill -f "agy_acp_server.par" || true
        pkill -f "localharness_external" || true
        sleep 1
        echo -e "${GREEN}✓${NC} Daemon stopped. Zed will automatically restart it on next request."
    else
        echo -e "${GREEN}✓${NC} No running daemon found. Ready for next request."
    fi
}

# Command: status
cmd_status() {
    print_banner
    if [[ ! -f "$TOKEN_FILE" ]]; then
        echo -e "${YELLOW}Status:${NC} No active Google account token found."
        echo -e "Run ${CYAN}$0 new${NC} or open Zed Assistant to trigger login."
        return 0
    fi

    echo -e "${BLUE}==>${NC} Checking active Google account..."
    local email
    email=$(get_token_email "$TOKEN_FILE")
    
    echo -e "Active Email : ${BOLD}${GREEN}${email}${NC}"
    echo -e "Token File   : ${TOKEN_FILE}"

    # Check if matches any saved profile
    local matched_profile=""
    for pf in "$PROFILES_DIR"/*.json; do
        if [[ -f "$pf" ]]; then
            if cmp -s "$TOKEN_FILE" "$pf"; then
                matched_profile="$(basename "$pf" .json)"
                break
            fi
        fi
    done

    if [[ -n "$matched_profile" ]]; then
        echo -e "Saved Profile: ${BOLD}${CYAN}${matched_profile}${NC}"
    else
        echo -e "Saved Profile: ${YELLOW}(Not saved to profiles yet. Use '$0 save <name>')${NC}"
    fi
}

# Command: list
cmd_list() {
    print_banner
    echo -e "${BOLD}Saved Account Profiles:${NC}"
    
    shopt -s nullglob
    local profiles=("$PROFILES_DIR"/*.json)
    shopt -u nullglob

    if [[ ${#profiles[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No saved profiles found in ${PROFILES_DIR}.${NC}"
        echo -e "Use ${CYAN}$0 save <name>${NC} to save the current account."
        return 0
    fi

    for pf in "${profiles[@]}"; do
        local name
        name="$(basename "$pf" .json)"
        local email
        email=$(get_token_email "$pf")
        
        local is_active=""
        if [[ -f "$TOKEN_FILE" ]] && cmp -s "$TOKEN_FILE" "$pf"; then
            is_active="${GREEN}${BOLD} [ACTIVE]${NC}"
        fi

        printf "  • %-20s : %-30s%b\n" "$name" "$email" "$is_active"
    done
}

# Command: save
cmd_save() {
    local profile_name="$1"
    if [[ ! -f "$TOKEN_FILE" ]]; then
        echo -e "${RED}Error: No active token to save.${NC}" >&2
        exit 1
    fi

    if [[ -z "$profile_name" ]]; then
        echo -e "${BLUE}==>${NC} Detecting email for auto profile name..."
        local email
        email=$(get_token_email "$TOKEN_FILE")
        if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            profile_name="${email%%@*}"
        else
            echo -e "${RED}Error: Please specify profile name: $0 save <name>${NC}" >&2
            exit 1
        fi
    fi

    local target_profile="${PROFILES_DIR}/${profile_name}.json"
    cp -f "$TOKEN_FILE" "$target_profile"
    echo -e "${GREEN}✓${NC} Active account saved as profile: ${BOLD}${CYAN}${profile_name}${NC} (${target_profile})"
}

# Command: switch
cmd_switch() {
    local profile_name="$1"
    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Error: Please specify profile to switch to: $0 switch <name>${NC}" >&2
        echo -e "Run ${CYAN}$0 list${NC} to see available profiles."
        exit 1
    fi

    local target_profile="${PROFILES_DIR}/${profile_name}.json"
    if [[ ! -f "$target_profile" ]]; then
        echo -e "${RED}Error: Profile '${profile_name}' does not exist!${NC}" >&2
        echo -e "Run ${CYAN}$0 list${NC} to see available profiles."
        exit 1
    fi

    # Auto backup current active token if not yet in profiles
    if [[ -f "$TOKEN_FILE" ]]; then
        local matched=false
        for pf in "$PROFILES_DIR"/*.json; do
            if cmp -s "$TOKEN_FILE" "$pf"; then
                matched=true
                break
            fi
        done
        if [[ "$matched" = false ]]; then
            local auto_backup="${PROFILES_DIR}/backup_$(date +%Y%m%d_%H%M%S).json"
            cp -f "$TOKEN_FILE" "$auto_backup"
            echo -e "${YELLOW}==>${NC} Current unsaved token backed up to ${auto_backup}"
        fi
    fi

    # Replace token
    cp -f "$target_profile" "$TOKEN_FILE"
    echo -e "${GREEN}✓${NC} Switched active token to profile: ${BOLD}${CYAN}${profile_name}${NC}"

    # Restart daemon
    restart_daemon
    echo -e "${GREEN}✓${NC} Successfully switched! New account is now active in Zed Editor."
}

# Command: new
cmd_new() {
    print_banner
    echo -e "${YELLOW}==>${NC} Preparing to log in with a new Google Account..."
    
    # Backup current token if exists
    if [[ -f "$TOKEN_FILE" ]]; then
        local ts
        ts="$(date +%Y%m%d_%H%M%S)"
        local backup_file="${PROFILES_DIR}/auto_backup_${ts}.json"
        mv "$TOKEN_FILE" "$backup_file"
        echo -e "${GREEN}✓${NC} Current token backed up to: ${backup_file}"
    fi

    # Restart daemon so it detects missing token
    restart_daemon

    echo ""
    echo -e "${BOLD}${CYAN}Next Steps:${NC}"
    echo -e "1. Open or focus on ${BOLD}Zed Editor${NC}."
    echo -e "2. Send any message or open the Assistant panel."
    echo -e "3. Antigravity will automatically open your browser to log into your new Google Account."
    echo -e "4. Once logged in, run: ${BOLD}${GREEN}$0 save <nama_profil>${NC} to save it!"
}

# Command: delete
cmd_delete() {
    local profile_name="$1"
    if [[ -z "$profile_name" ]]; then
        echo -e "${RED}Error: Please specify profile name: $0 delete <name>${NC}" >&2
        exit 1
    fi

    local target_profile="${PROFILES_DIR}/${profile_name}.json"
    if [[ ! -f "$target_profile" ]]; then
        echo -e "${RED}Error: Profile '${profile_name}' not found.${NC}" >&2
        exit 1
    fi

    rm -f "$target_profile"
    echo -e "${GREEN}✓${NC} Profile '${profile_name}' deleted."
}

# Router
case "${1:-}" in
    status)
        cmd_status
        ;;
    list)
        cmd_list
        ;;
    save)
        cmd_save "${2:-}"
        ;;
    switch)
        cmd_switch "${2:-}"
        ;;
    new)
        cmd_new
        ;;
    delete)
        cmd_delete "${2:-}"
        ;;
    -h|--help|help|"")
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}" >&2
        print_usage
        exit 1
        ;;
esac
