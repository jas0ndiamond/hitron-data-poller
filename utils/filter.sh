#!/usr/bin/env bash
set -euo pipefail

# filter.sh - Post-process modem data JSON files to remove invalid/disabled entries
#
# This script applies jq filters to JSON files created by poll.sh to clean up data
# by removing entries marked as "DISABLED" or "NA" (indicating invalid or non-functional
# modem channels).
#
# The filter removes:
#   - Upstream OFDM (us_ofdm) entries with state != "DISABLED"
#   - Downstream OFDM (ds_ofdm) entries with ffttype != "NA"
#
# Usage:
#   ./filter.sh [-v] <file-or-directory>
#
# Arguments:
#   -v                Enable verbose output (shows which files were processed)
#   <file-or-directory>  Single JSON file or directory of JSON files to process
#
# Examples:
#   ./filter.sh hitron-data/
#   ./filter.sh -v data-test/data-20260000_000000.json
#
# Dependencies:
#   - jq: JSON query tool
#   - sponge: Unix tool to write back to same file (from moreutils package)

#FILTER='(.us_ofdm |= map(select(.state != "DISABLED")))'
FILTER='(.us_ofdm |= map(select(.state != "DISABLED"))) | (.ds_ofdm |= map(select(.ffttype != "NA")))'
verbose=0

usage() {
  echo "Usage: $0 [-v] <file-or-directory>" >&2
  exit 1
}

while getopts ":v" opt; do
  case "$opt" in
    v) verbose=1 ;;
    \?) usage ;;
  esac
done

shift $((OPTIND - 1))

[[ $# -eq 1 ]] || usage

target="$1"

if ! command -v jq >/dev/null 2>&1; then
  echo "Please install jq (for example: brew install jq, apt install jq, or yum install jq)." >&2
  exit 1
fi

if ! command -v sponge >/dev/null 2>&1; then
  echo "Please install sponge (usually from the moreutils package; for example: brew install moreutils or apt install moreutils)." >&2
  exit 1
fi

process_file() {
  local file="$1"

  if [[ $verbose -eq 1 ]]; then
    echo "Processing: $file"
  fi

  if jq -e "$FILTER" "$file" >/dev/null 2>&1; then
    jq "$FILTER" "$file" | sponge "$file"
    if [[ $verbose -eq 1 ]]; then
      echo "Applied filter to: $file"
    fi
  elif [[ $verbose -eq 1 ]]; then
    echo "No changes needed for: $file"
  fi
}

if [[ -f "$target" ]]; then
  process_file "$target"
elif [[ -d "$target" ]]; then
  find "$target" -type f -name '*.json' -print0 |
    while IFS= read -r -d '' file; do
      process_file "$file"
    done
else
  echo "Error: '$target' is not a file or directory." >&2
  exit 1
fi
