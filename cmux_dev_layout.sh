#!/usr/bin/env bash
# Creates a dev layout in the current cmux workspace:
#   ┌──────────┬──────────┐
#   │          │ lazygit  │
#   │  editor  ├──────────┤
#   │  (main)  │ iex -S   │
#   │          │ mix phx  │
#   └──────────┴──────────┘

# Split right from current pane — this becomes the top-right
TOP_RIGHT=$(cmux new-split right | awk '{print $2}')

# Split down from the top-right — this becomes the bottom-right
BOTTOM_RIGHT=$(cmux new-split down --surface "$TOP_RIGHT" | awk '{print $2}')

# Start lazygit in the top-right
cmux send --surface "$TOP_RIGHT" "lazygit\n"

# Start phx.server in the bottom-right
cmux send --surface "$BOTTOM_RIGHT" "iex -S mix phx.server\n"
