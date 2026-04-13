#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Usage and args -----------------------------------------------------------

usage() {
    cat >&2 <<EOF
Usage:
  $0 CHART_DIRECTORY [ACTIONS_CSV]

Arguments:
  CHART_DIRECTORY   Directory containing CSV files (us_qam.csv, ds_qam.csv, us_ofdm.csv, ds_ofdm.csv)
  ACTIONS_CSV       Optional path to actions.csv; if supplied but not found, error

Examples:
  $0 chart-20260327-162053
  $0 chart-20260327-162053 actions.csv
EOF
}

# --- Check gnuplot -----------------------------------------------------------

if ! command -v gnuplot >/dev/null 2>&1; then
    echo "Error: gnuplot is not installed or not in PATH." >&2
    echo "On Ubuntu/Debian: sudo apt install gnuplot" >&2
    echo "On macOS (Homebrew): brew install gnuplot" >&2
    echo "On RHEL/CentOS/Fedora: sudo dnf install gnuplot" >&2
    exit 1
fi

# --- Parse arguments ---

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

CHART_DIR="$1"
ACTIONS_CSV="${2:-}"

# --- Validate directory ---

if [[ ! -d "$CHART_DIR" ]]; then
    echo "Error: directory does not exist: '$CHART_DIR'" >&2
    exit 1
fi

# --- Validate all required CSV files exist and are not empty ---

declare -a REQUIRED_FILES=(
    "us_qam.csv"
    "ds_qam.csv"
    "us_ofdm.csv"
    "ds_ofdm.csv"
)

for filename in "${REQUIRED_FILES[@]}"; do
    filepath="$CHART_DIR/$filename"
    
    if [[ ! -f "$filepath" ]]; then
        echo "Error: missing required CSV file: '$filepath'" >&2
        exit 1
    fi
    
    if [[ ! -s "$filepath" ]]; then
        echo "Error: empty CSV file: '$filepath'" >&2
        exit 1
    fi
done

# --- Validate actions file if provided ---

if [[ -n "$ACTIONS_CSV" && ! -f "$ACTIONS_CSV" ]]; then
    echo "Error: actions CSV supplied but not found: '$ACTIONS_CSV'" >&2
    exit 1
fi

# --- Generate all plots ---

echo "Generating all plots from directory: '$CHART_DIR'"
echo ""

# Plot 1: Upstream QAM
echo "  [1/5] Upstream QAM..."
gnuplot -e "DATA_FILE='$CHART_DIR/us_qam.csv'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/qam.gp"

# Plot 2: Downstream QAM
echo "  [2/5] Downstream QAM..."
gnuplot -e "DATA_FILE='$CHART_DIR/ds_qam.csv'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/qam.gp"

# Plot 3: Upstream OFDM
echo "  [3/5] Upstream OFDM..."
gnuplot -e "DATA_FILE='$CHART_DIR/us_ofdm.csv'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/us_ofdm.gp"

# Plot 4: Downstream OFDM
echo "  [4/5] Downstream OFDM..."
gnuplot -e "DATA_FILE='$CHART_DIR/ds_ofdm.csv'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/ds_ofdm.gp"

# Plot 5: Combined OFDM
echo "  [5/5] Combined OFDM (dual-panel)..."
gnuplot -e "DATA_FILE_US='$CHART_DIR/us_ofdm.csv'; DATA_FILE_DS='$CHART_DIR/ds_ofdm.csv'; ACTIONS_FILE='$ACTIONS_CSV'" \
    "$SCRIPT_DIR/plotting/ofdm_combined.gp"

echo ""
echo "✓ All plots generated successfully:"
echo "  - us_qam.png"
echo "  - ds_qam.png"
echo "  - us_ofdm.png"
echo "  - ds_ofdm.png"
echo "  - ofdm_combined.png"
