#!/bin/bash

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

[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="chart-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"

FILES=($(find "$DIR" -name 'data-*.json' -type f | sort 2>/dev/null || true))
TOTAL_FILES=${#FILES[@]}
echo "Processing $TOTAL_FILES JSON files from: $DIR"

process_section() {
  local csv_file="$OUTPUT_DIR/$1"
  local header="$2"
  
  echo "$header" > "$csv_file"
  local file_count=0
  local skipped_count=0
  
  $VERBOSE && echo "  $1:"
  
  for file in "${FILES[@]}"; do
    ts=$(jq -r '.timestamp // empty' "$file" 2>/dev/null) || ts=""
    if [[ -z "$ts" ]]; then
      echo "Error: No timestamp in $(basename "$file")" >&2
      ((skipped_count++))
      continue
    fi
    
    case "$1" in
      "ds_qam.csv")
        jq -r --arg ts "$ts" \
          '.ds_qam[]? | [ $ts, (.portId//"null"), (.signalStrength//"null"), (.snr//"null") ] | @csv' \
          "$file" >> "$csv_file" 2>/dev/null || true
        ;;
      "us_qam.csv")
        jq -r --arg ts "$ts" \
          '.us_qam[]? | [ $ts, (.portId//"null"), (.signalStrength//"null") ] | @csv' \
          "$file" >> "$csv_file" 2>/dev/null || true
        ;;
      "ds_ofdm.csv")
        jq -r --arg ts "$ts" \
          '.ds_ofdm[]? | select(.Subcarr0freqFreq != "NA") | [ $ts, (.receive//"null"), (.SNR//"null"), (.Subcarr0freqFreq//"null"), (.plcpower//"null") ] | @csv' \
          "$file" >> "$csv_file" 2>/dev/null || true
        ;;
      "us_ofdm.csv")
        jq -r --arg ts "$ts" \
          '.us_ofdm[]? | select(.state != "DISABLED") | [ $ts, (.uschindex//"null"), (.frequency//"null"), (.digAtten//"null"), (.digAttenBo//"null"), (.repPower//"null"), (.repPower1_6//"null") ] | @csv' \
          "$file" >> "$csv_file" 2>/dev/null || true
        ;;
    esac
    
    ((file_count++))
    $VERBOSE && printf "    %d/%d files\r" "$file_count" "$TOTAL_FILES"
  done
  
  sort -k1,1 "$csv_file" -o "$csv_file" 2>/dev/null || true
  echo "  ✓ $1 ($file_count processed, $skipped_count skipped)"
}

echo "Output: $OUTPUT_DIR/"

process_section "ds_qam.csv" "timestamp,portId,signalStrength_dBmV,snr_dB"
process_section "us_qam.csv" "timestamp,portId,signalStrength_dBmV"
process_section "ds_ofdm.csv" "timestamp,receive,SNR_dB,subcarr0freq_Hz,plcpower_dBmV"
process_section "us_ofdm.csv" "timestamp,uschindex,frequency_Hz,digAtten,digAttenBo,repPower,repPower1_6"

echo ""
echo "✓ Complete: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR"/*.csv 2>/dev/null || true
echo ""
echo "Gnuplot (cd $OUTPUT_DIR first):"
echo "set xdata time"
echo "set timefmt '%Y-%m-%d %H:%M:%S'"
echo "plot 'ds_qam.csv' using 1:3 with lines title 'Signal Strength'"

