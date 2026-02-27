#!/bin/bash
# ─────────────────────────────────────────────
#  Ollama CLI Chatbot
#  Requires: curl, jq, ollama
#  Usage: ./ollamaCmdBot.sh
# ─────────────────────────────────────────────

# ── Config ────────────────────────────────────
MODEL="mistral"
API_URL="http://localhost:11434/api/chat"
SYSTEM_PROMPT="You are a helpful, friendly assistant. Keep responses concise and conversational."
TMP_RESPONSE="/tmp/.ollamachat_response_$$"

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
for cmd in curl jq ollama; do
if ! command -v "$cmd" &>/dev/null; then
echo -e "${RED}Error: '$cmd' is required but not installed.${RESET}"
exit 1
fi
done
}

# ── Check Ollama is running ───────────────────
check_ollama() {
if ! curl -s http://localhost:11434 &>/dev/null; then
echo -e "${YELLOW}Ollama not running. Starting it now...${RESET}"
ollama serve &>/dev/null &
sleep 2
fi
}

# ── Conversation history ──────────────────────
HISTORY="[]"

# ── Send message ──────────────────────────────
send_message() {
local user_msg="$1"

HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "user" \
--arg content "$user_msg" \
'. + [{"role": $role, "content": $content}]')

local body
body=$(jq -n \
--arg model "$MODEL" \
--arg system "$SYSTEM_PROMPT" \
--argjson messages "$HISTORY" \
'{model: $model, system: $system, messages: $messages, stream: false}')

curl -s -X POST "$API_URL" \
-H "content-type: application/json" \
-d "$body" > "$TMP_RESPONSE"

local reply
reply=$(jq -r '.message.content // empty' "$TMP_RESPONSE" 2>/dev/null)

if [[ -z "$reply" ]]; then
echo -e "\n${RED}Error: No response from Ollama. Is the model installed? Run: ollama pull $MODEL${RESET}\n"
return 1
fi

HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "assistant" \
--arg content "$reply" \
'. + [{"role": $role, "content": $content}]')

echo -e "\n${GREEN}${BOLD}Ollama ($MODEL):${RESET}"
echo "$reply" | fold -s -w 78 | sed 's/^/  /'
echo
}

# ── Switch model ──────────────────────────────
switch_model() {
echo -e "${YELLOW}Installed models:${RESET}"
ollama list | tail -n +2 | awk '{print "  - "$1}'
echo -ne "\n${CYAN}Enter model name: ${RESET}"
read -r new_model
if [[ -n "$new_model" ]]; then
MODEL="$new_model"
HISTORY="[]"
echo -e "${GREEN}Switched to $MODEL. Conversation reset.${RESET}\n"
fi
}

# ── Banner ────────────────────────────────────
print_banner() {
echo -e "${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════╗"
echo "  ║       🦙 Ollama ChatBot            ║"
echo "  ║  Type 'exit' or 'quit' to leave    ║"
echo "  ║  Type 'clear' to reset the chat    ║"
echo "  ║  Type 'model' to switch models     ║"
echo "  ╚════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}  Using model: $MODEL${RESET}\n"
}

# ── Main loop ─────────────────────────────────
main() {
check_deps
check_ollama
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
echo -e "${DIM}Commands: exit/quit, clear/reset, model, help${RESET}\n"
continue
;;
model)
switch_model
continue
;;
esac

echo -ne "${DIM}  thinking...${RESET}"
echo -ne "\r\033[K"

send_message "$user_input"
done
}

main
