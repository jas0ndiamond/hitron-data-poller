#!/bin/bash

# generate-graph-data.sh — Convert Hitron JSON poll data to time-series CSV files
#
# Processes raw modem telemetry JSON files (created by poll.sh) and converts them
# into time-series CSV files organized by signal category (US/DS QAM/OFDM).
#
# Features:
#   - Filters out disabled/inactive channels (DISABLED state, NA values)
#   - Scrubs leading/trailing whitespace from all field values
#   - Sorts output by timestamp
#   - Generates properly formatted CSV headers
#
# Usage:
#   $0 [-v] [-o DIR] [INPUT_DIR]
#
# Options:
#   -v             Verbose mode (show processing details)
#   -o DIR         Output directory (default: chart-YYYYMMDD-HHMMSS)
#   -h             Show this help message
#
# Arguments:
#   INPUT_DIR      Input directory with data-*.json (default: ./hitron-data)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${1:-${SCRIPT_DIR}/hitron-data}"
VERBOSE=false
OUTPUT_DIR=""

print_usage() {
  cat <<'EOF'
Usage: $0 [-v] [-o DIR] [INPUT_DIR]
Generate time-series CSVs from Hitron JSON data for gnuplot.

  -v             Verbose mode (show processing details)
  -o DIR         Output directory (default: chart-YYYYMMDD-HHMMSS)
  INPUT_DIR      Input directory with data-*.json (default: ./hitron-data)
EOF
}

while getopts "vho:" opt; do
  case $opt in
    v) VERBOSE=true ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    h) print_usage; exit 0 ;;
    *) print_usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

DIR="${1:-${SCRIPT_DIR}/hitron-data}"
[[ ! -d "$DIR" ]] && { echo "Error: Input directory $DIR not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq required but not found" >&2; exit 1; }

OUTPUT_DIR="${OUTPUT_DIR:-chart-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTPUT_DIR"

FILES=($(find "$DIR" -name 'data-*.json' -type f | sort 2>/dev/null || true))
TOTAL_FILES=${#FILES[@]}
echo "Processing $TOTAL_FILES JSON files from: $DIR → $OUTPUT_DIR"

# jq filter to trim leading/trailing whitespace from all string values
TRIM_FILTER='walk(if type == "string" then gsub("^\\s+"; "") | gsub("\\s+$"; "") else . end)'

# Single pass: read each file once, write to all 4 CSVs
file_count=0
skipped_count=0
$VERBOSE && echo "Processing:"

for file in "${FILES[@]}"; do
  ts=$(jq -r '.timestamp // empty' "$file" 2>/dev/null) || ts=""
  if [[ -z "$ts" ]]; then
    echo "Error: No timestamp in $(basename "$file")" >&2
    ((skipped_count++))
    continue
  fi

  ((file_count++))
  $VERBOSE && printf "  %d/%d: %s\r" "$file_count" "$TOTAL_FILES" "$(basename "$file")"

  # Apply whitespace trimming to the entire JSON, then extract data
  TRIMMED=$(jq "$TRIM_FILTER" "$file" 2>/dev/null)

  # ds_qam - Extract timestamp, portId, signalStrength, snr
  echo "$TRIMMED" | jq -r --arg ts "$ts" \
    '.ds_qam[]? | [ $ts, (.portId//"null"), (.signalStrength//"null"), (.snr//"null") ] | @csv' \
    >> "$OUTPUT_DIR/ds_qam.csv" 2>/dev/null || true

  # us_qam - Extract timestamp, portId, signalStrength
  echo "$TRIMMED" | jq -r --arg ts "$ts" \
    '.us_qam[]? | [ $ts, (.portId//"null"), (.signalStrength//"null") ] | @csv' \
    >> "$OUTPUT_DIR/us_qam.csv" 2>/dev/null || true

  # ds_ofdm - Filter out NA channels (ffttype != "NA"), extract relevant fields
  echo "$TRIMMED" | jq -r --arg ts "$ts" \
    '.ds_ofdm[]? | select(.ffttype != "NA") | [ $ts, (.receive//"null"), (.SNR//"null"), (.Subcarr0freqFreq//"null"), (.plcpower//"null") ] | @csv' \
    >> "$OUTPUT_DIR/ds_ofdm.csv" 2>/dev/null || true

  # us_ofdm - Filter out DISABLED channels (state != "DISABLED"), extract relevant fields
  echo "$TRIMMED" | jq -r --arg ts "$ts" \
    '.us_ofdm[]? | select(.state != "DISABLED") | [ $ts, (.uschindex//"null"), (.frequency//"null"), (.digAtten//"null"), (.digAttenBo//"null"), (.repPower//"null"), (.repPower1_6//"null") ] | @csv' \
    >> "$OUTPUT_DIR/us_ofdm.csv" 2>/dev/null || true
done

# Write headers and sort each CSV
echo "timestamp,portId,signalStrength_dBmV,snr_dB" > "$OUTPUT_DIR/ds_qam.csv.tmp"
sort -k1,1 "$OUTPUT_DIR/ds_qam.csv" >> "$OUTPUT_DIR/ds_qam.csv.tmp" 2>/dev/null || true
mv "$OUTPUT_DIR/ds_qam.csv.tmp" "$OUTPUT_DIR/ds_qam.csv"

echo "timestamp,portId,signalStrength_dBmV" > "$OUTPUT_DIR/us_qam.csv.tmp"
sort -k1,1 "$OUTPUT_DIR/us_qam.csv" >> "$OUTPUT_DIR/us_qam.csv.tmp" 2>/dev/null || true
mv "$OUTPUT_DIR/us_qam.csv.tmp" "$OUTPUT_DIR/us_qam.csv"

echo "timestamp,receive,SNR_dB,subcarr0freq_Hz,plcpower_dBmV" > "$OUTPUT_DIR/ds_ofdm.csv.tmp"
sort -k1,1 "$OUTPUT_DIR/ds_ofdm.csv" >> "$OUTPUT_DIR/ds_ofdm.csv.tmp" 2>/dev/null || true
mv "$OUTPUT_DIR/ds_ofdm.csv.tmp" "$OUTPUT_DIR/ds_ofdm.csv"

echo "timestamp,uschindex,frequency_Hz,digAtten,digAttenBo,repPower,repPower1_6" > "$OUTPUT_DIR/us_ofdm.csv.tmp"
sort -k1,1 "$OUTPUT_DIR/us_ofdm.csv" >> "$OUTPUT_DIR/us_ofdm.csv.tmp" 2>/dev/null || true
mv "$OUTPUT_DIR/us_ofdm.csv.tmp" "$OUTPUT_DIR/us_ofdm.csv"

$VERBOSE && echo ""
echo "✓ Complete: $OUTPUT_DIR/ ($file_count processed, $skipped_count skipped)"
ls -lh "$OUTPUT_DIR"/*.csv

