#!/bin/zsh
# The map graybox: traversal only, separate from the Contact Lab.
cd -- "${0:A:h}"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" map_graybox.tscn
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD" map_graybox.tscn
else
  print 'Godot 4.7 is required. Open project.godot with Godot to play.'
  read -k 1
fi
