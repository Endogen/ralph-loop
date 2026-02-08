#!/usr/bin/env bash
#
# Ralph Telegram Notifier
# Sends a message to Telegram using bot API
#
# Usage: ./notify.sh "Your message here"
#    or: source notify.sh && ralph_notify "Your message"
#
set -euo pipefail

# Load config from ~/.ralph.env
RALPH_ENV="${RALPH_ENV:-$HOME/.ralph.env}"

ralph_notify() {
  local message="${1:-}"
  
  if [[ -z "$message" ]]; then
    echo "Usage: ralph_notify <message>" >&2
    return 1
  fi
  
  # Load env if not already set
  if [[ -z "${RALPH_TELEGRAM_BOT_TOKEN:-}" ]] && [[ -f "$RALPH_ENV" ]]; then
    # shellcheck source=/dev/null
    source "$RALPH_ENV"
  fi
  
  # Check required vars
  if [[ -z "${RALPH_TELEGRAM_BOT_TOKEN:-}" ]]; then
    echo "❌ RALPH_TELEGRAM_BOT_TOKEN not set. Create ~/.ralph.env" >&2
    return 1
  fi
  
  if [[ -z "${RALPH_TELEGRAM_CHAT_ID:-}" ]]; then
    echo "❌ RALPH_TELEGRAM_CHAT_ID not set. Create ~/.ralph.env" >&2
    return 1
  fi
  
  # Send via Telegram Bot API
  local response
  response=$(curl -s -X POST \
    "https://api.telegram.org/bot${RALPH_TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${RALPH_TELEGRAM_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=Markdown" \
    2>&1)
  
  if echo "$response" | grep -q '"ok":true'; then
    echo "✅ Notification sent"
    return 0
  else
    echo "❌ Telegram API error: $response" >&2
    return 1
  fi
}

# If run directly (not sourced), send the message
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ralph_notify "$@"
fi
