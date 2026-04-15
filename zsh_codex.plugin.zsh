#!/bin/zsh

# Auto AI completion for Ollama - pure zsh + curl + jq
# Ctrl+X toggles between normal and AI hint modes

_ZSH_CODEX_MODE=1
_ZSH_CODEX_HINT=""
_ZSH_CODEX_TMP="/tmp/zsh_codex_hint_$$"

# Session command history (current terminal session only)
typeset -a _ZSH_CODEX_SESSION_HISTORY

# Config: ~/.config/zsh_codex.ini
# [ollama]
# model=qwen2.5-coder:3b
# host=http://localhost:11434

# System prompt - defined once globally
_ZSH_CODEX_SYSTEM_PROMPT="You are a shell assistant. Always start with the best example command, then show useful flags. Max 4 lines. Plain text, no markdown, no backticks."

_zsh_codex_config_get() {
    local section="$1" key="$2"
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/zsh_codex.ini"
    [[ -f "$cfg" ]] || return
    awk -F= '/\['"$section"'\]/{found=1} found && $1~/'"$key"'/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' "$cfg"
}

_zsh_codex_fetch() {
    local text="$1"
    local history="$2"
    local sysinfo="$3"
    local model=$(_zsh_codex_config_get "ollama" "model")
    local host=$(_zsh_codex_config_get "ollama" "host")

    [[ -z "$model" ]] && model="qwen2.5-coder:3b"
    [[ -z "$host" ]] && host="http://localhost:11434"

    if ! curl -s -m 2 "${host}/api/tags" >/dev/null 2>&1; then
        echo "Ollama не отвечает на $host"
        return
    fi

    local prompt="Context: ${sysinfo//$'\n'/ } | Recent: ${history//$'\n'/ } | Command: $text"

    # Escape for JSON: newlines -> \n, quotes -> \"
    local system_prompt="${_ZSH_CODEX_SYSTEM_PROMPT//$'\n'/\n}"
    system_prompt="${system_prompt//\"/\\\"}"
    prompt="${prompt//$'\n'/\n}"
    prompt="${prompt//\"/\\\"}"

    local raw_response=$(curl -s -m 60 -X POST "${host}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$model\",\"system\":\"$system_prompt\",\"prompt\":\"$prompt\",\"stream\":false,\"options\":{\"num_ctx\":6144,\"temperature\":0}}" 2>&1)
    
    # Write to temp file for reliable jq parsing
    local tmpf="/tmp/zsh_codex_resp_$$"
    printf '%s' "$raw_response" > "$tmpf"
    
    # Check for errors
    if [[ "$raw_response" == *'"error"'* ]]; then
        echo "ERROR: $(jq -r '.error // "Unknown"' < "$tmpf" 2>/dev/null)"
        rm -f "$tmpf"
        return
    fi
    
    # Extract and compact: remove empty lines
    jq -r '.response // empty' < "$tmpf" 2>/dev/null | sed '/^[[:space:]]*$/d'
    rm -f "$tmpf"
}

# Clean completion output - remove code blocks, backticks
_zsh_codex_clean() {
    local raw="$1"
    raw=${raw//\`\`\`/}
    raw=${raw//\`\`/}
    raw=$(echo "$raw" | sed 's/^`\+//; s/`\+$//')
    raw=$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    echo "$raw"
}

# Display AI hint using zle -M (below input line)
_zsh_codex_display() {
    local hint="$1"
    [[ -z "$hint" ]] && { zle -M ""; return; }
    hint=$(_zsh_codex_clean "$hint")
    zle -M "  🐑 $hint"
}

# Get last 10 commands from current session
_zsh_codex_get_history() {
    local count=10
    local start=$(( ${#_ZSH_CODEX_SESSION_HISTORY[@]} - $count ))
    [[ $start -lt 0 ]] && start=0
    printf '%s\n' "${_ZSH_CODEX_SESSION_HISTORY[@]:$start}"
}

# Gather system information
_zsh_codex_get_sysinfo() {
    local pwd="$PWD"
    local user="$USER"
    local hostname="$(hostname)"
    local kernel="$(uname -r)"
    local interfaces=$(ip -4 -br addr show 2>/dev/null | awk '/^[a-z]/ {print $1 ": " $3}' | head -5)
    [[ -z "$interfaces" ]] && interfaces=$(ifconfig 2>/dev/null | grep -E '^[a-z]' | head -5)
    
    echo "OS: $kernel | User: $user@$hostname | Dir: $pwd | Net: $(echo $interfaces | tr '\n' ', ')"
}

zsh_codex_complete() {
    zle .self-insert
}

zsh_codex_request() {
    local current="$BUFFER"
    
    [[ $_ZSH_CODEX_MODE -eq 0 ]] && { zle -M "󰌹 AI mode OFF"; return; }
    [[ -z "${current// /}" ]] && { zle -M "󰌹 Введите команду"; return; }
    
    local raw_resp=$(_zsh_codex_fetch "$current" "" "")
    _ZSH_CODEX_HINT=$raw_resp
    _zsh_codex_display "$_ZSH_CODEX_HINT"
}

# Clear on execute and save to session history
zsh_codex_enter() {
    local cmd="$BUFFER"
    [[ -n "$cmd" ]] && _ZSH_CODEX_SESSION_HISTORY+=("$cmd")
    _ZSH_CODEX_HINT=""
    zle .accept-line
}

# Toggle AI mode (Ctrl+X)
zsh_codex_toggle() {
    if [[ $_ZSH_CODEX_MODE -eq 0 ]]; then
        _ZSH_CODEX_MODE=1
        RPROMPT="%F{8}󰌹 AI mode  %f"
    else
        _ZSH_CODEX_MODE=0
        RPROMPT=""
        _ZSH_CODEX_HINT=""
    fi
    zle .reset-prompt
}

# Register widgets
zle -N zsh_codex_request
zle -N zsh_codex_toggle

# Bindings
bindkey '^X' zsh_codex_toggle      # Ctrl+X - toggle AI mode on/off
bindkey '^O' zsh_codex_request     # Ctrl+O - ask AI for help