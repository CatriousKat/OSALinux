#!/usr/bin/env bash

# osalinux - AppleScript execution and translation layer for Linux

check_and_install() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "[osalinux] Missing '$cmd'. Installing package '$pkg'..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "$pkg" > /dev/null 2>&1
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$pkg" > /dev/null 2>&1
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm "$pkg" > /dev/null 2>&1
        else
            echo "Error: Please install $pkg manually." >&2
            exit 1
        fi
    fi
}

set_clipboard() {
    local text="$1"
    if [ "$XDG_SESSION_TYPE" = "wayland" ] && command -v wl-copy &> /dev/null; then
        echo -n "$text" | wl-copy
    else
        check_and_install "xclip" "xclip"
        echo -n "$text" | xclip -selection clipboard
    fi
}

get_clipboard() {
    if [ "$XDG_SESSION_TYPE" = "wayland" ] && command -v wl-paste &> /dev/null; then
        wl-paste -n
    else
        check_and_install "xclip" "xclip"
        xclip -selection clipboard -o
    fi
}

if [ "$1" = "-e" ]; then
    shift
    EXEC_CONTENT="$1"
elif [ -f "$1" ]; then
    EXEC_CONTENT=$(<"$1")
else
    echo "Usage: osalinux [-e 'command'] [script.applescript]" >&2
    exit 1
fi

declare -A OSAVARS

while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(--|#) ]] && continue
    [[ -z "${line// }" ]] && continue

    for var in "${!OSAVARS[@]}"; do
        line="${line//\$${var}/${OSAVARS[$var]}}"
    done

    # Translate: display dialog "text" [with title "title"]
    if [[ "$line" =~ display\ dialog\ \"([^\"]+)\" ]]; then
        check_and_install "zenity" "zenity"
        dialog_text="${BASH_REMATCH[1]}"
        title="osalinux"
        if [[ "$line" =~ with\ title\ \"([^\"]+)\" ]]; then
            title="${BASH_REMATCH[1]}"
        fi
        zenity --info --text="$dialog_text" --title="$title" > /dev/null 2>&1

    # Translate: say "text"
    elif [[ "$line" =~ say\ \"([^\"]+)\" ]]; then
        check_and_install "espeak-ng" "espeak-ng"
        espeak-ng "${BASH_REMATCH[1]}" > /dev/null 2>&1

    # Translate: do shell script "command"
    elif [[ "$line" =~ do\ shell\ script\ \"([^\"]+)\" ]]; then
        eval "${BASH_REMATCH[1]}"

    # Translate: open "filepath_or_url"
    elif [[ "$line" =~ open\ \"([^\"]+)\" ]]; then
        check_and_install "xdg-open" "xdg-utils"
        xdg-open "${BASH_REMATCH[1]}" > /dev/null 2>&1

    # Translate: set the clipboard to "text" / variable / expression
    elif [[ "$line" =~ set\ the\ clipboard\ to\ \"([^\"]+)\" ]]; then
        set_clipboard "${BASH_REMATCH[1]}"
    elif [[ "$line" =~ set\ the\ clipboard\ to\ ([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
        var_name="${BASH_REMATCH[1]}"
        set_clipboard "${OSAVARS[$var_name]}"

    # Translate: set var to string/number/clipboard/concatenation
    elif [[ "$line" =~ set\ ([a-zA-Z_][a-zA-Z0-9_]*)\ to\ \"([^\"]+)\" ]]; then
        OSAVARS["${BASH_REMATCH[1]}"]="${BASH_PRMATCH_2:-${BASH_REMATCH[2]}}"
    elif [[ "$line" =~ set\ ([a-zA-Z_][a-zA-Z0-9_]*)\ to\ ([0-9]+) ]]; then
        OSAVARS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ set\ ([a-zA-Z_][a-zA-Z0-9_]*)\ to\ the\ clipboard ]]; then
        OSAVARS["${BASH_REMATCH[1]}"]=$(get_clipboard)
    elif [[ "$line" =~ set\ ([a-zA-Z_][a-zA-Z0-9_]*)\ to\ (.*) ]]; then
        var_name="${BASH_REMATCH[1]}"
        expr="${BASH_REMATCH[2]}"
        for var in "${!OSAVARS[@]}"; do
            expr="${expr//\$${var}/${OSAVARS[$var]}}"
        done
        expr="${expr//&/+}"
        eval "val=\$$expr" 2>/dev/null || val=$(echo "$expr" | tr -d '"')
        OSAVARS["$var_name"]="$val"

    # Translate: delay X seconds
    elif [[ "$line" =~ delay\ ([0-9]+(\.[0-9]+)?) ]]; then
        sleep "${BASH_REMATCH[1]}"

    # Translate: activate application "Name"
    elif [[ "$line" =~ activate\ application\ \"([^\"]+)\" ]]; then
        check_and_install "wmctrl" "wmctrl"
        wmctrl -a "${BASH_REMATCH[1]}" > /dev/null 2>&1 || true

    elif [[ "$line" =~ ^[[:space:]]*tell[[:space:]] ]] || [[ "$line" =~ ^[[:space:]]*end\ tell ]]; then
        continue

    else
        eval "$line" > /dev/null 2>&1 || true
    fi
done <<< "$EXEC_CONTENT"
