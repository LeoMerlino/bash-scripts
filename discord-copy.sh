#!/usr/bin/env bash
text=$(cat /dev/stdin)
echo -n \
"\`\`\`ansi
$text
\`\`\`" | sed 's/\[m/\[0m/g' | wl-copy
