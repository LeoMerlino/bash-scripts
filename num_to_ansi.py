#!/usr/bin/env python3

# AI ALERT!!!!!!
# AI ALERT!!!!!!
# AI ALERT!!!!!!
# AI ALERT!!!!!!

import argparse
import sys

def value_to_ansi(value: float) -> str:
    """Return the ANSI true‑color escape for a 0‑100 value (green→red)."""
    # Clamp to the valid range
    v = max(0.0, min(100.0, value))

    # Linear interpolation
    r = int(255 * v / 100)          # 0 → 0, 100 → 255
    g = int(255 * (100 - v) / 100)  # 0 → 255, 100 → 0
    b = 0

    # 38;2;r;g;b sets the foreground colour in true‑color terminals
    return f'\033[38;2;{r};{g};{b}m'

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print an ANSI colour code that varies from green (0) to red (100)."
    )
    parser.add_argument(
        "value",
        type=float,
        help="Number in the range 0‑100 (values outside are clamped).",
    )
    args = parser.parse_args()

    ansi_code = value_to_ansi(args.value)
    # Print only the escape sequence (no newline) so it can be used directly in scripts
    sys.stdout.write(ansi_code)

if __name__ == "__main__":
    main()

