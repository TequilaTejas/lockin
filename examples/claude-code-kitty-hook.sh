#!/bin/bash
# Claude Code Notification hook for Lockin's kitty exception.
#
# When a Claude Code session running inside kitty needs your input (permission
# prompt, question), this pings Lockin via its URL scheme. If your screen is
# locked, Lockin brings kitty forward; press Return after answering and focus
# snaps back to the locked window.
#
# Install:
#   1. Copy this file somewhere stable, e.g. ~/.claude/lockin-kitty-input.sh,
#      and chmod +x it.
#   2. Add to ~/.claude/settings.json:
#        "hooks": {
#          "Notification": [
#            { "hooks": [ { "type": "command",
#                           "command": "\"$HOME/.claude/lockin-kitty-input.sh\"",
#                           "async": true, "timeout": 10 } ] }
#          ]
#        }
#
# The script exits silently outside kitty and when Lockin is not running.
[ -n "$KITTY_WINDOW_ID" ] || exit 0
pgrep -xq Lockin || exit 0
open -g "lockin://kitty-input"
exit 0
