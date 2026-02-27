#!/bin/bash
# ─────────────────────────────────────────────
#  Claude CLI Chatbot
#  Requires: curl, jq
#  Usage: ./chatbot.sh
# ─────────────────────────────────────────────

# ── Config ────────────────────────────────────
MODEL="claude-haiku-4-5-20251001"
MAX_TOKENS=1024
SYSTEM_PROMPT="You are a helpful, friendly assistant. Keep responses concise and conversational."
API_URL="https://api.anthropic.com/v1/messages"
TMP_RESPONSE="/tmp/.chatbot_response_$$"

# ── Colors ────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
DIM="\033[2m"

# ── Cleanup on exit ───────────────────────────
cleanup() { rm -f "$TMP_RESPONSE"; }
trap cleanup EXIT

# ── Check dependencies ────────────────────────
check_deps() {
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}Error: '$cmd' is required but not installed.${RESET}"
            exit 1
        fi
    done
}

# ── Check API key ─────────────────────────────
check_api_key() {
    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo -e "${YELLOW}No ANTHROPIC_API_KEY found in environment.${RESET}"
        echo -n "Enter your Anthropic API key: "
        read -rs ANTHROPIC_API_KEY
        echo
        export ANTHROPIC_API_KEY
    fi
}

# ── Conversation history (JSON array) ─────────
HISTORY="[]"

# ── Send message — writes reply directly, no subshell ──
send_message() {
    local user_msg="$1"

    # Append user message to history
    HISTORY=$(printf '%s' "$HISTORY" | jq \
        --arg role "user" \
        --arg content "$user_msg" \
        '. + [{"role": $role, "content": $content}]')

    # Build request body
    local body
    body=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --arg system "$SYSTEM_PROMPT" \
        --argjson messages "$HISTORY" \
        '{model: $model, max_tokens: $max_tokens, system: $system, messages: $messages}')

    # Call API, write raw response to temp file
    curl -s \
        -X POST "$API_URL" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$body" > "$TMP_RESPONSE"

    # Extract reply text
    local reply
    reply=$(jq -r '.content[0].text // empty' "$TMP_RESPONSE" 2>/dev/null)

    if [[ -z "$reply" ]]; then
        local api_error
        api_error=$(jq -r '.error.message // "Unknown error. Check your API key."' "$TMP_RESPONSE" 2>/dev/null)
        echo -e "\n${RED}API Error: $api_error${RESET}\n"
        return 1
    fi

    # Append assistant reply to history
    HISTORY=$(printf '%s' "$HISTORY" | jq \
        --arg role "assistant" \
        --arg content "$reply" \
        '. + [{"role": $role, "content": $content}]')

    # Print reply directly (avoids subshell capture)
    echo -e "\n${GREEN}${BOLD}Claude:${RESET}"
    echo "$reply" | fold -s -w 78 | sed 's/^/  /'
    echo
}

# ── Banner ────────────────────────────────────
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔════════════════════════════════════╗"
    echo "  ║        Claude CLI Chatbot          ║"
    echo "  ║  Type 'exit' or 'quit' to leave    ║"
    echo "  ║  Type 'clear' to reset the chat    ║"
    echo "  ╚════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── Main loop ─────────────────────────────────
main() {
    check_deps
    check_api_key
    print_banner

    while true; do
        echo -ne "${CYAN}${BOLD}You:${RESET} "
        read -r user_input

        [[ -z "$user_input" ]] && continue

        lower_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

        case "$lower_input" in
            exit|quit|bye)
                echo -e "${DIM}Goodbye!${RESET}"
                exit 0
                ;;
            clear|reset)
                HISTORY="[]"
                clear
                print_banner
                echo -e "${DIM}Conversation cleared.${RESET}\n"
                continue
                ;;
            help)
                echo -e "${DIM}Commands: exit/quit, clear/reset, help${RESET}\n"
                continue
                ;;
        esac

        echo -ne "${DIM}  thinking...${RESET}"
        echo -ne "\r\033[K"

        send_message "$user_input"
    done
}

main