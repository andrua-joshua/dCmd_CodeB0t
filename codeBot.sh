#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Claude Coding Agent
#  Usage: ./codeagent.sh [context_folder]
#  Requires: curl, jq, python3
# ═══════════════════════════════════════════════════════════

# ── Config ─────────────────────────────────────────────────
MODEL="claude-sonnet-4-6"
MAX_TOKENS=4096
API_URL="https://api.anthropic.com/v1/messages"
TMP_RESPONSE="/tmp/.codeagent_response_$$"
TMP_CMD_OUT="/tmp/.codeagent_cmd_$$"
TMP_HIGHLIGHTER="/tmp/.codeagent_hl_$$.py"
MAX_AGENT_LOOPS=30
CONTEXT_DIR="${1:-$(pwd)}"
USAGE_LOG="$HOME/.codebot_usage.log"

# ── Token tracking ──────────────────────────────────────────
TOT_INPUT_TOKENS=0
TOT_OUTPUT_TOKENS=0
SESSION_START=$(date +%s)

# ── Colors ─────────────────────────────────────────────────
RESET="\033[0m";  BOLD="\033[1m";   DIM="\033[2m"
CYAN="\033[36m";  GREEN="\033[32m"; YELLOW="\033[33m"
RED="\033[31m";   BLUE="\033[34m";  MAGENTA="\033[35m"

# ── Write syntax highlighter python script via heredoc ──────
write_highlighter() {
cat > "$TMP_HIGHLIGHTER" << 'HLPY'
#!/usr/bin/env python3
import sys, re

# Build ANSI codes using chr(27) so they work inside a single-quoted heredoc
E = chr(27)  # ESC character

def ansi(code):
    return E + "[" + code + "m"

RESET      = ansi("0")
BOLD       = ansi("1")
BG_DARK    = ansi("48;5;235")
FG_DEFAULT = ansi("97")
C_KEYWORD  = ansi("38;5;204")   # coral    — keywords
C_STRING   = ansi("38;5;185")   # yellow   — strings
C_COMMENT  = ansi("38;5;244")   # grey     — comments
C_NUMBER   = ansi("38;5;141")   # purple   — numbers
C_FUNC     = ansi("38;5;117")   # blue     — functions
C_VAR      = ansi("38;5;215")   # orange   — bash variables
C_SYMBOL   = ansi("38;5;251")   # lt grey  — punctuation
C_BOLD     = ansi("1;97")       # bold white
C_HEADER   = ansi("1;38;5;75")  # bold cyan-blue
C_INLINE   = ansi("38;5;222")   # warm yellow — inline code

KEYWORDS = {
    "bash":   r'\b(if|then|else|elif|fi|for|while|do|done|case|esac|in|function|return|local|export|echo|exit|shift|break|continue|source|trap|read|unset|declare|eval|exec)\b',
    "python": r'\b(def|class|import|from|as|return|if|elif|else|for|while|in|not|and|or|is|None|True|False|pass|break|continue|raise|try|except|finally|with|yield|lambda|global|nonlocal|del|assert|async|await)\b',
    "js":     r'\b(var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|delete|typeof|instanceof|in|of|class|extends|import|export|default|async|await|try|catch|finally|throw|null|undefined|true|false)\b',
    "go":     r'\b(func|var|const|type|struct|interface|map|chan|if|else|for|range|return|import|package|go|defer|select|case|default|break|continue|fallthrough|goto|nil|true|false|make|new|append|len|cap|close|delete)\b',
    "java":   r'\b(public|private|protected|class|interface|extends|implements|new|return|if|else|for|while|do|switch|case|break|continue|static|final|void|int|long|double|float|boolean|char|byte|short|null|true|false|import|package|try|catch|finally|throw|throws|this|super|instanceof)\b',
}

# Use lambda in re.sub to avoid ANSI codes being misread as backreferences
def wrap(pre, post=""):
    # Returns a replacement function for re.sub
    _post = post if post else RESET
    def replacer(m):
        return pre + m.group(0) + _post
    return replacer

def wrap_group1(pre, post=""):
    _post = post if post else RESET
    def replacer(m):
        return pre + m.group(1) + _post
    return replacer

def highlight_code(code, lang):
    lang = lang.lower().strip()
    kw_pattern = KEYWORDS.get(lang, None)

    result = []
    for line in code.split('\n'):
        hl = line  # start on raw text, add BG at the end

        # 1. Numbers first — on raw text so regex won't hit ANSI digits later
        hl = re.sub(r'(?<![\";\'\w])(\d+\.?\d*)(?![\w;])', lambda m: C_NUMBER + m.group(1) + RESET, hl)

        # 2. Strings
        hl = re.sub(r'("(?:[^"\\]|\\.)*")', lambda m: C_STRING + m.group(1) + RESET, hl)
        hl = re.sub(r"('(?:[^'\\]|\\.)*')",  lambda m: C_STRING + m.group(1) + RESET, hl)

        # 3. Comments (skip if line already has ESC = already inside a string color)
        if lang in ("bash", "python"):
            hl = re.sub(r'((?:^|(?<=[^\x1b]))(#.+))$', lambda m: C_COMMENT + m.group(1) + RESET, hl)
        elif lang in ("js", "go", "java"):
            hl = re.sub(r'(//.*?)$', lambda m: C_COMMENT + m.group(1) + RESET, hl)

        # 4. Function calls
        hl = re.sub(r'\b([a-zA-Z_][a-zA-Z0-9_]*)(\s*\()',
                    lambda m: C_FUNC + m.group(1) + RESET + C_SYMBOL + m.group(2) + RESET, hl)

        # 5. Keywords
        if kw_pattern:
            hl = re.sub(kw_pattern, lambda m: C_KEYWORD + m.group(1) + RESET, hl)

        # 6. Bash variables
        if lang == "bash":
            hl = re.sub(r'(\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?)', lambda m: C_VAR + m.group(1) + RESET, hl)

        # Wrap entire line in dark background + default fg
        hl = BG_DARK + FG_DEFAULT + hl + RESET
        result.append(hl)
    return '\n'.join(result)

def process(text):
    output = []
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]

        # Fenced code block
        fence_match = re.match(r'^```(\w*)', line)
        if fence_match:
            lang = fence_match.group(1) or "bash"
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                code_lines.append(lines[i])
                i += 1
            code = '\n'.join(code_lines)
            label  = lang.upper() if lang else "CODE"
            header = BG_DARK + BOLD + C_FUNC + "  \u250c\u2500 " + label + " " + "\u2500" * max(0, 54 - len(label)) + RESET
            footer = BG_DARK + C_SYMBOL + "  \u2514" + "\u2500" * 57 + RESET
            highlighted = highlight_code(code, lang)
            indented = '\n'.join("  " + l for l in highlighted.split('\n'))
            output.append(header)
            output.append(indented)
            output.append(footer)
            i += 1
            continue

        # Headers
        hdr = re.match(r'^(#{1,3})\s+(.*)', line)
        if hdr:
            output.append(C_HEADER + BOLD + hdr.group(1) + " " + hdr.group(2) + RESET)
            i += 1
            continue

        # Inline **bold** and `code`
        line = re.sub(r'\*\*(.+?)\*\*', lambda m: C_BOLD + m.group(1) + RESET, line)
        line = re.sub(r'`([^`]+)`',     lambda m: C_INLINE + "`" + m.group(1) + "`" + RESET, line)

        output.append(line)
        i += 1

    return '\n'.join(output)

if __name__ == "__main__":
    text = sys.stdin.read()
    sys.stdout.write(process(text) + '\n')
HLPY
    chmod +x "$TMP_HIGHLIGHTER"
}

# ── Cleanup ─────────────────────────────────────────────────
cleanup() {
    rm -f "$TMP_RESPONSE" "$TMP_CMD_OUT" "$TMP_HIGHLIGHTER"
    print_usage_summary
}
trap cleanup EXIT

# ── Deps check ──────────────────────────────────────────────
check_deps() {
    for cmd in curl jq python3; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}Error: '$cmd' is required but not installed.${RESET}"
            exit 1
        fi
    done
}

# ── API key ─────────────────────────────────────────────────
check_api_key() {
    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo -e "${YELLOW}No ANTHROPIC_API_KEY found in environment.${RESET}"
        echo -n "Enter your Anthropic API key: "
        read -rs ANTHROPIC_API_KEY
        echo
        export ANTHROPIC_API_KEY
    fi
}

# ── Token tracking ───────────────────────────────────────────
accumulate_tokens() {
    local in_tok out_tok
    in_tok=$(jq -r '.usage.input_tokens  // 0' "$TMP_RESPONSE" 2>/dev/null)
    out_tok=$(jq -r '.usage.output_tokens // 0' "$TMP_RESPONSE" 2>/dev/null)
    TOT_INPUT_TOKENS=$((TOT_INPUT_TOKENS + in_tok))
    TOT_OUTPUT_TOKENS=$((TOT_OUTPUT_TOKENS + out_tok))
}

print_usage_summary() {
    local end_time duration cost_in cost_out total_cost total_tokens
    end_time=$(date +%s)
    duration=$((end_time - SESSION_START))
    mins=$((duration / 60))
    secs=$((duration % 60))

    # Cost: $3/M input, $15/M output
    # Use awk for float math
    cost_in=$(awk  "BEGIN {printf \"%.6f\", $TOT_INPUT_TOKENS  / 1000000 * 3}")
    cost_out=$(awk "BEGIN {printf \"%.6f\", $TOT_OUTPUT_TOKENS / 1000000 * 15}")
    total_cost=$(awk "BEGIN {printf \"%.6f\", $cost_in + $cost_out}")
    total_tokens=$((TOT_INPUT_TOKENS + TOT_OUTPUT_TOKENS))

    echo -e "\n${CYAN}${BOLD}"
    echo   "  ╔══════════════════════════════════════════════╗"
    echo   "  ║            SESSION USAGE SUMMARY             ║"
    echo   "  ╠══════════════════════════════════════════════╣"
    printf "  ║  %-20s  %22s  ║\n" "Duration"      "${mins}m ${secs}s"
    printf "  ║  %-20s  %22s  ║\n" "Input tokens"  "$TOT_INPUT_TOKENS"
    printf "  ║  %-20s  %22s  ║\n" "Output tokens" "$TOT_OUTPUT_TOKENS"
    printf "  ║  %-20s  %22s  ║\n" "Total tokens"  "$total_tokens"
    printf "  ║  %-20s  %22s  ║\n" "Input cost"    "\$$cost_in"
    printf "  ║  %-20s  %22s  ║\n" "Output cost"   "\$$cost_out"
    printf "  ║  %-20s  %22s  ║\n" "Total cost"    "\$$total_cost"
    echo   "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # Append to log
    local ts
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$ts | in=$TOT_INPUT_TOKENS out=$TOT_OUTPUT_TOKENS total=$total_tokens cost=\$$total_cost dur=${mins}m${secs}s dir=$CONTEXT_DIR" >> "$USAGE_LOG"
}

show_history() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo -e "${DIM}  No usage history found.${RESET}\n"
        return
    fi

    echo -e "${CYAN}${BOLD}"
    echo   "  ╔══════════════════════════════════════════════════════════════════════════╗"
    echo   "  ║                         LAST 10 SESSIONS                                ║"
    echo   "  ╠══════════════════════════════════════════════════════════════════════════╣"
    tail -10 "$USAGE_LOG" | while IFS= read -r line; do
        printf "  ║  %-72s  ║\n" "$line"
    done
    echo   "  ╠══════════════════════════════════════════════════════════════════════════╣"

    # All-time cost
    local alltime
    alltime=$(awk -F'cost=\\$' 'NF>1{sum += $2} END {printf "%.6f", sum}' "$USAGE_LOG")
    printf "  ║  %-72s  ║\n" "All-time total cost: \$$alltime"
    echo   "  ╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ── System prompt ────────────────────────────────────────────
build_system_prompt() {
    cat <<SYSPROMPT
You are an expert coding agent. You have been given access to a codebase at: $CONTEXT_DIR

You can explore and understand the codebase by issuing shell commands. To run a command, respond with a special block in this EXACT format:

<cmd>
YOUR_SHELL_COMMAND_HERE
</cmd>

Rules:
- You may issue ONE <cmd> block per response, or none if you have a final answer.
- After each command, you will automatically receive its output — keep iterating until you fully answer the user's request.
- Use standard Unix tools: ls, find, cat, grep, wc, head, tail, diff, etc.
- All commands run inside: $CONTEXT_DIR
- Do NOT use interactive editors (vim, nano). Use cat, sed, awk, or shell heredocs for file writes.
- When you have fully completed the task, respond normally with NO <cmd> block.
- Be concise in explanations between commands. Show your reasoning briefly.
SYSPROMPT
}

# ── Conversation history ─────────────────────────────────────
HISTORY="[]"

append_history() {
    local role="$1"
    local content="$2"
    HISTORY=$(printf '%s' "$HISTORY" | jq \
        --arg role "$role" \
        --arg content "$content" \
        '. + [{"role": $role, "content": $content}]')
}

# ── Call Claude API ──────────────────────────────────────────
call_claude() {
    local system_prompt
    system_prompt=$(build_system_prompt)

    local body
    body=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --arg system "$system_prompt" \
        --argjson messages "$HISTORY" \
        '{model: $model, max_tokens: $max_tokens, system: $system, messages: $messages}')

    curl -s \
        -X POST "$API_URL" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$body" > "$TMP_RESPONSE"

    # Accumulate tokens from this call
    accumulate_tokens

    jq -r '.content[0].text // empty' "$TMP_RESPONSE" 2>/dev/null
}

# ── Extract <cmd> block ──────────────────────────────────────
get_cmd_block() {
    echo "$1" | awk '/<cmd>/{found=1; next} /<\/cmd>/{found=0} found{print}'
}

# ── Execute shell command inside CONTEXT_DIR ─────────────────
run_cmd() {
    local cmd="$1"
    cd "$CONTEXT_DIR" || return 1
    bash -c "$cmd" 2>&1 | head -c 8000
}

# ── Print helpers ────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║        >>>>>> D_CMD CodeB0t              ║"
    echo "  ║  Context: $(printf '%-32s' "$CONTEXT_DIR")║"
    echo "  ║  exit/quit  clear  history  help         ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_claude_text() {
    # Strip <cmd> blocks, then highlight remaining text
    local text
    text=$(echo "$1" | awk '/<cmd>/{skip=1} /<\/cmd>/{skip=0; next} !skip{print}')
    if [[ -n "$(echo "$text" | tr -d '[:space:]')" ]]; then
        echo -e "${GREEN}${BOLD}Agent:${RESET}"
        echo "$text" | python3 "$TMP_HIGHLIGHTER" | sed 's/^/  /'
        echo
    fi
}

print_cmd_running() {
    echo -e "${YELLOW}${BOLD}  ⚙ Running:${RESET} ${DIM}$1${RESET}"
}

print_cmd_output() {
    echo -e "${BLUE}${BOLD}  ↳ Output:${RESET}"
    echo "$1" | head -50 | sed 's/^/    /'
    local lines
    lines=$(echo "$1" | wc -l | tr -d ' ')
    if [[ "$lines" -gt 50 ]]; then
        echo -e "    ${DIM}... ($lines lines total, truncated)${RESET}"
    fi
    echo
}

# ── Agent loop ───────────────────────────────────────────────
run_agent_loop() {
    local loop_count=0

    while [[ $loop_count -lt $MAX_AGENT_LOOPS ]]; do
        loop_count=$((loop_count + 1))

        echo -ne "${DIM}  thinking...${RESET}"
        local reply
        reply=$(call_claude)
        echo -ne "\r\033[K"

        if [[ -z "$reply" ]]; then
            local api_err
            api_err=$(jq -r '.error.message // "Empty response"' "$TMP_RESPONSE" 2>/dev/null)
            echo -e "${RED}API Error: $api_err${RESET}\n"
            return 1
        fi

        append_history "assistant" "$reply"
        print_claude_text "$reply"

        local cmd
        cmd=$(get_cmd_block "$reply")
        cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ -z "$cmd" ]]; then
            break
        fi

        print_cmd_running "$cmd"
        local output
        output=$(run_cmd "$cmd")
        print_cmd_output "$output"

        append_history "user" "Command output:
\`\`\`
$output
\`\`\`"
    done

    if [[ $loop_count -ge $MAX_AGENT_LOOPS ]]; then
        echo -e "${YELLOW}  ⚠ Reached max iterations ($MAX_AGENT_LOOPS).${RESET}\n"
    fi
}

# ── Main ─────────────────────────────────────────────────────
main() {
    check_deps
    check_api_key
    write_highlighter

    if [[ ! -d "$CONTEXT_DIR" ]]; then
        echo -e "${RED}Error: '$CONTEXT_DIR' is not a valid directory.${RESET}"
        exit 1
    fi

    CONTEXT_DIR=$(cd "$CONTEXT_DIR" && pwd)
    print_banner

    # Seed with file tree
    local init_snapshot
    init_snapshot=$(cd "$CONTEXT_DIR" && find . -not -path '*/\.*' -not -path '*/node_modules/*' \
        -not -path '*/__pycache__/*' | sort | head -100)
    append_history "user" "Project loaded. Here is the top-level file tree:
\`\`\`
$init_snapshot
\`\`\`
Ready for your instructions."

    call_claude > /dev/null
    local ack
    ack=$(jq -r '.content[0].text // empty' "$TMP_RESPONSE" 2>/dev/null)
    append_history "assistant" "$ack"

    echo -e "${DIM}  Project context loaded ($(echo "$init_snapshot" | wc -l | tr -d ' ') files indexed).${RESET}\n"

    # Main chat loop
    while true; do
        echo -ne "${CYAN}${BOLD}You:${RESET} "
        read -r user_input

        [[ -z "$user_input" ]] && continue

        local lower
        lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

        case "$lower" in
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
            history)
                show_history
                continue
                ;;
            help)
                echo -e "${DIM}Commands: exit/quit, clear/reset, history, help${RESET}"
                echo -e "${DIM}Pass a folder: ./codeagent.sh /path/to/project${RESET}\n"
                continue
                ;;
        esac

        append_history "user" "$user_input"
        run_agent_loop
    done
}

main