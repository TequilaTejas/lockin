#!/bin/bash
# Claude Code Notification hook for Anchor's kitty exception.
#
# When a Claude Code session running inside kitty needs your input (permission
# prompt, question), this pings Anchor via its URL scheme. If your screen is
# locked, Anchor brings kitty forward; press Return after answering and focus
# snaps back to the locked window.
#
# Install:
#   1. Copy this file somewhere stable, e.g. ~/.claude/anchor-kitty-input.sh,
#      and chmod +x it.
#   2. Add to ~/.claude/settings.json:
#        "hooks": {
#          "Notification": [
#            { "hooks": [ { "type": "command",
#                           "command": "\"$HOME/.claude/anchor-kitty-input.sh\"",
#                           "async": true, "timeout": 10 } ] }
#          ]
#        }
#
# The script exits silently outside kitty and when Anchor is not running.
[ -n "$KITTY_WINDOW_ID" ] || exit 0
pgrep -xq Anchor || exit 0
open -g "anchor://kitty-input"
exit 0
