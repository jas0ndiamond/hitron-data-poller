#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Usage and args -----------------------------------------------------------

usage() {
    cat >&2 <<EOF
Usage:
  $0 DATA_CSV [ACTIONS_CSV]

Arguments:
  DATA_CSV      required path to the main CSV (e.g., us_qam.csv or ds_qam.csv)
  ACTIONS_CSV   optional path to actions.csv; if supplied but not found, error.

Examples:
  $0 chart-20260327-162053/us_qam.csv
  $0 chart-20260327-162053/ds_qam.csv actions.csv
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

DATA_CSV="$1"
if [[ ! -f "$DATA_CSV" ]]; then
    echo "Error: data CSV does not exist: '$DATA_CSV'" >&2
    exit 1
fi

ACTIONS_CSV="${2:-}"

if [[ -n "$ACTIONS_CSV" && ! -f "$ACTIONS_CSV" ]]; then
    echo "Error: actions CSV supplied but not found: '$ACTIONS_CSV'" >&2
    exit 1
fi

# --- Check gnuplot -----------------------------------------------------------

if ! command -v gnuplot >/dev/null 2>&1; then
    echo "Error: gnuplot is not installed or not in PATH." >&2
    echo "On Ubuntu/Debian: sudo apt install gnuplot" >&2
    echo "On macOS (Homebrew): brew install gnuplot" >&2
    echo "On RHEL/CentOS/Fedora: sudo dnf install gnuplot" >&2
    exit 1
fi

# --- Run gnuplot scripts that already honor DATA_CSV and ACTIONS_CSV args ---

# Assume the gnuplot script has a variable like:
#   DATA_FILE = ARG1
#   ACTIONS_FILE = (ARG2 eq "" ? "none" : ARG2)
# so we pass them via gnuplot -e

echo "Plotting data file: '$DATA_CSV'"

# Example: call a generic gnuplot script that reads DATA_FILE and optionally ACTIONS_FILE
gnuplot -e "DATA_FILE='$DATA_CSV'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/qam.gp"

echo "Done."
