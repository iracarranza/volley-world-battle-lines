#!/bin/zsh
cd -- "${0:A:h}"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
else
  print 'Godot 4.7 is required. Open project.godot with Godot to play.'
  read -k 1
fi
