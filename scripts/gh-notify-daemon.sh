#!/usr/bin/env bash
# gh-notify-daemon.sh — Background GitHub notification watcher.
# Polls /notifications every 30s with If-Modified-Since conditional requests.
# Fires macOS popups + sounds per event type, appends to events.log.
#
# State: ~/.config/gh-notify/{events.log,sfx-state,seen-ids}
# Started by: gh-notify-bar.sh

STATE_DIR="${HOME}/.config/gh-notify"
EVENTS_LOG="${STATE_DIR}/events.log"
SFX_STATE="${STATE_DIR}/sfx-state"
SEEN_IDS="${STATE_DIR}/seen-ids"

# ── init state dir ────────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"
[[ -f "$SFX_STATE" ]] || echo "ON" > "$SFX_STATE"
touch "$EVENTS_LOG" "$SEEN_IDS"

# ── prevent duplicate instances ───────────────────────────────────────────────
LOCK_FILE="${STATE_DIR}/.daemon.lock"
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$LOCK_FILE" 2>/dev/null || true' EXIT

# ── resolve identity + auth ───────────────────────────────────────────────────
GH_TOKEN=$(gh auth token 2>/dev/null) || {
    echo "[$(date +%H:%M)] ERROR: gh auth token failed - run: gh auth login" >> "$EVENTS_LOG"
    exit 1
}
SELF=$(gh api /user --jq '.login' 2>/dev/null) || {
    echo "[$(date +%H:%M)] ERROR: gh api /user failed" >> "$EVENTS_LOG"
    exit 1
}

# ── helpers ───────────────────────────────────────────────────────────────────
play_sound() {
    local sound="$1"
    local sfx
    sfx=$(cat "$SFX_STATE" 2>/dev/null || echo "ON")
    [[ "$sfx" == "ON" ]] && afplay "/System/Library/Sounds/${sound}" 2>/dev/null &
}

send_notification() {
    local title="$1" subtitle="$2" message="$3"
    title="${title//\\/}"; title="${title//\"/\'}"
    subtitle="${subtitle//\\/}"; subtitle="${subtitle//\"/\'}"
    message="${message//\\/}"; message="${message//\"/\'}"
    osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\"" 2>/dev/null || true
}

log_event() {
    local icon="$1" label="$2" title="$3" repo="$4"
    local timestamp
    timestamp=$(date +"%H:%M")
    printf '[%s] %s %s - %s (%s)\n' "$timestamp" "$icon" "$label" "$title" "$repo" >> "$EVENTS_LOG"
    log_size=$(stat -f%z "$EVENTS_LOG" 2>/dev/null || echo 0)
    if [[ "$log_size" -gt 102400 ]]; then
        mv "$EVENTS_LOG" "${EVENTS_LOG}.$(date +%Y%m%d)"
        touch "$EVENTS_LOG"
    fi
}

api_get() {
    local path="$1"
    # Accept both /relative/path and full https://api.github.com/... URLs
    local url
    if [[ "$path" == https://* ]]; then
        url="$path"
    else
        url="https://api.github.com${path}"
    fi
    curl -sf "$url" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        2>/dev/null
}

# ── process a single notification ─────────────────────────────────────────────
process_notification() {
    local notif="$1"
    local id reason title repo_name subj_url subj_type

    id=$(printf '%s' "$notif" | jq -r '.id // empty')
    [[ -z "$id" ]] && return
    reason=$(printf '%s' "$notif" | jq -r '.reason')
    title=$(printf '%s' "$notif" | jq -r '.subject.title')
    repo_name=$(printf '%s' "$notif" | jq -r '.repository.full_name')
    subj_url=$(printf '%s' "$notif" | jq -r '.subject.url // empty')
    subj_type=$(printf '%s' "$notif" | jq -r '.subject.type')

    # Skip already-seen
    if grep -qF "$id" "$SEEN_IDS" 2>/dev/null; then
        return
    fi
    printf '%s\n' "$id" >> "$SEEN_IDS"
    seen_count=$(wc -l < "$SEEN_IDS" | tr -d ' ')
    if [[ "$seen_count" -gt 10000 ]]; then
        tail -5000 "$SEEN_IDS" > "${SEEN_IDS}.tmp" && mv "${SEEN_IDS}.tmp" "$SEEN_IDS"
    fi

    local event_icon event_label sound
    event_icon="🔔"
    event_label="Activity"
    sound="Ping.aiff"

    case "$reason" in
        comment|mention)
            event_icon="💬"
            event_label="New comment"
            sound="Tink.aiff"
            ;;
        review_requested)
            event_icon="👀"
            event_label="Review requested"
            sound="Tink.aiff"
            ;;
        assign)
            event_icon="📌"
            event_label="Assigned"
            sound="Ping.aiff"
            ;;
        author)
            if [[ "$subj_type" == "PullRequest" && -n "$subj_url" ]]; then
                local pr_data merged state
                pr_data=$(api_get "$subj_url") || pr_data=""

                if [[ -n "$pr_data" ]]; then
                    merged=$(printf '%s' "$pr_data" | jq -r '.merged')
                    state=$(printf '%s' "$pr_data" | jq -r '.state')

                    if [[ "$merged" == "true" ]]; then
                        event_icon="🔀"
                        event_label="Merged"
                        sound="Hero.aiff"
                    elif [[ "$state" == "open" ]]; then
                        local reviews_data approver
                        reviews_data=$(api_get "${subj_url}/reviews") || reviews_data=""

                        if [[ -n "$reviews_data" ]]; then
                            approver=$(printf '%s' "$reviews_data" | jq -r \
                            --arg self "$SELF" \
                            '[.[] | select(.state == "APPROVED" and .user.login != $self)] | last | .user.login // empty')
                        else
                            approver=""
                        fi

                        if [[ -n "$approver" ]]; then
                            event_icon="✅"
                            event_label="Approved by ${approver}"
                            sound="Glass.aiff"
                        fi
                    fi
                fi
            fi
            ;;
    esac

    log_event "$event_icon" "$event_label" "$title" "$repo_name"
    send_notification "GitHub: ${event_label}" "$repo_name" "$title"
    play_sound "$sound"
}

# ── poll loop ─────────────────────────────────────────────────────────────────
LAST_MODIFIED=""

while true; do
    # Build conditional request args
    EXTRA_ARGS=()
    if [[ -n "$LAST_MODIFIED" ]]; then
        EXTRA_ARGS=("-H" "If-Modified-Since: ${LAST_MODIFIED}")
    fi

    # Fetch notifications with response headers (-i for status + headers)
    raw_response=$(curl -si "https://api.github.com/notifications" \
        -H "Authorization: Bearer ${GH_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "${EXTRA_ARGS[@]}" 2>/dev/null) || { sleep 30; continue; }

    # Extract HTTP status code from first header line
    http_status=$(printf '%s\n' "$raw_response" | head -1 | grep -oE '[0-9]{3}' | head -1)

    # 304 = nothing changed since last poll; skip processing
    if [[ "$http_status" == "304" ]]; then
        sleep 30
        continue
    fi

    # Store Last-Modified for next conditional request
    new_lm=$(printf '%s\n' "$raw_response" | grep -i "^last-modified:" | head -1 | sed 's/[Ll]ast-[Mm]odified: //' | tr -d '\r')
    [[ -n "$new_lm" ]] && LAST_MODIFIED="$new_lm"

    # Extract body: everything after the blank line separating headers from body
    body=$(printf '%s\n' "$raw_response" | awk 'found{print} /^\r?$/{found=1}')

    # Validate response is a JSON array before processing
    if ! printf '%s\n' "$body" | jq -e 'type == "array"' > /dev/null 2>&1; then
        sleep 30
        continue
    fi

    # Process each unread notification
    count=$(printf '%s\n' "$body" | jq 'length')
    for i in $(seq 0 $((count - 1))); do
        notif=$(printf '%s\n' "$body" | jq ".[${i}]")
        process_notification "$notif"
    done

    sleep 30
done
