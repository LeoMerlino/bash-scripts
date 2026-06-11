#!/bin/bash
font=$(cat <<'EOF' | shuf -n1
ProFont IIx Nerd Font Mono
RecMonoCasual Nerd Font
SeriousShanns Nerd Font Mono
MonaspiceRn Nerd Font Mono
MonaspiceKr Nerd Font Mono
Hurmit Nerd Font Mono
FantasqueSansM Nerd Font Mono
EOF
)

sed "s/\(font_family family=\).*/\1\"$font\"/" -i ~/.config/kitty/kitty.conf
kitty
