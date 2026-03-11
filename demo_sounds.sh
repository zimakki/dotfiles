#!/bin/zsh

sounds=(
  "Glass"
  "Blow"
  "Ping"
  "Purr"
  "Tink"
)

echo "Playing macOS system sounds for task completion notifications...\n"

for sound in "${sounds[@]}"; do
  sound_path="/System/Library/Sounds/${sound}.aiff"
  
  if [[ -f "$sound_path" ]]; then
    echo "Playing: $sound"
    afplay "$sound_path"
    sleep 1
  else
    echo "⚠️  $sound not found"
  fi
done

echo "\nDemo complete!"
