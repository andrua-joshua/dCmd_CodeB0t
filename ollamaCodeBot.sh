#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Ollama Coding Agent
#  Usage: ./ollamaCodeBot.sh [context_folder]
#  Requires: curl, jq, ollama
# ═══════════════════════════════════════════════════════════

# ── Config ─────────────────────────────────────────────────
MODEL="codellama"
API_URL="http://localhost:11434/api/chat"
TMP_RESPONSE="/tmp/.ollamacode_response_$$"
MAX_CONTEXT_FILES=20
CONTEXT_DIR="${1:-$(pwd)}"
USAGE_LOG="$HOME/.ollamacodebot_usage.log"
SESSION_START=$(date +%s)

SYSTEM_PROMPT="You are an expert penetration tester, red team operator and software engineer. \
Help with recon, exploitation, privilege escalation, writing offensive and defensive code, \
CTF challenges, vulnerability analysis and technical reporting. Be precise and technical."

# ── Colors ─────────────────────────────────────────────────
RESET="\033[0m";  BOLD="\033[1m";   DIM="\033[2m"
CYAN="\033[36m";  GREEN="\033[32m"; YELLOW="\033[33m"
RED="\033[31m";   BLUE="\033[34m";  MAGENTA="\033[35m"

# ── Cleanup ────────────────────────────────────────────────
cleanup() {
rm -f "$TMP_RESPONSE"
local session_end
session_end=$(date +%s)
local duration=$(( session_end - SESSION_START ))
echo -e "\n${DIM}Session duration: ${duration}s | Log: $USAGE_LOG${RESET}"
}
trap cleanup EXIT

# ── Check dependencies ─────────────────────────────────────
check_deps() {
for cmd in curl jq ollama; do
if ! command -v "$cmd" &>/dev/null; then
echo -e "${RED}Error: '$cmd' is required but not installed.${RESET}"
exit 1
fi
done
}

# ── Check Ollama is running ────────────────────────────────
check_ollama() {
if ! curl -s http://localhost:11434 &>/dev/null; then
echo -e "${YELLOW}Ollama not running. Starting...${RESET}"
ollama serve &>/dev/null &
sleep 2
fi
}

# ── Load project context ───────────────────────────────────
load_context() {
local context=""
local count=0

if [[ -d "$CONTEXT_DIR" ]]; then
echo -e "${DIM}  Loading context from: $CONTEXT_DIR${RESET}"
while IFS= read -r file; do
[[ $count -ge $MAX_CONTEXT_FILES ]] && break
if [[ -f "$file" ]]; then
context+="\n--- FILE: $file ---\n"
context+=$(cat "$file" 2>/dev/null)
context+="\n"
((count++))
fi
done < <(find "$CONTEXT_DIR" -type f \
! -path "*/.git/*" \
! -name "*.png" ! -name "*.jpg" \
! -name "*.zip" ! -name "*.bin" \
2>/dev/null | head -"$MAX_CONTEXT_FILES")

echo -e "${DIM}  Loaded $count file(s) as context${RESET}\n"
fi

echo "$context"
}

# ── Conversation history ───────────────────────────────────
HISTORY="[]"

# ── Send message ──────────────────────────────────────────
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
echo -e "\n${RED}Error: No response. Is '$MODEL' installed? Run: ollama pull $MODEL${RESET}\n"
return 1
fi

HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "assistant" \
--arg content "$reply" \
'. + [{"role": $role, "content": $content}]')

# Log usage
echo "[$(date)] model=$MODEL chars_in=${#user_msg} chars_out=${#reply}" >> "$USAGE_LOG"

echo -e "\n${GREEN}${BOLD}Ollama ($MODEL):${RESET}"
echo "$reply" | fold -s -w 78 | sed 's/^/  /'
echo
}

# ── Switch model ──────────────────────────────────────────
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

# ── Banner ─────────────────────────────────────────────────
print_banner() {
echo -e "${MAGENTA}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║     🦙 Ollama Coding Agent           ║"
echo "  ║  Type 'exit' or 'quit' to leave      ║"
echo "  ║  Type 'clear' to reset the chat      ║"
echo "  ║  Type 'model' to switch models       ║"
echo "  ║  Type 'context' to reload files      ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "${DIM}  Model:   $MODEL"
echo -e "  Context: $CONTEXT_DIR${RESET}\n"
}

# ── Main ──────────────────────────────────────────────────
main() {
check_deps
check_ollama
print_banner

# Load project context into first system message
local ctx
ctx=$(load_context)
if [[ -n "$ctx" ]]; then
HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "user" \
--arg content "Here is my project context:\n$ctx\nI will ask you questions about it." \
'. + [{"role": $role, "content": $content}]')

HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "assistant" \
--arg content "Got it! I have reviewed your project files. How can I help you?" \
'. + [{"role": $role, "content": $content}]')
fi

while true; do
echo -ne "${MAGENTA}${BOLD}You:${RESET} "
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
echo -e "${DIM}Commands: exit/quit, clear/reset, model, context, help${RESET}\n"
continue
;;
model)
switch_model
continue
;;
context)
ctx=$(load_context)
HISTORY=$(printf '%s' "$HISTORY" | jq \
--arg role "user" \
--arg content "Updated project context:\n$ctx" \
'. + [{"role": $role, "content": $content}]')
echo -e "${DIM}Context reloaded.${RESET}\n"
continue
;;
esac

echo -ne "${DIM}  thinking...${RESET}"
echo -ne "\r\033[K"

send_message "$user_input"
done
}

main
