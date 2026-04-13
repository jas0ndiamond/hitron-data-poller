#!/usr/bin/env bash
set -euo pipefail

# scrub_whitespace.sh - Trim leading/trailing whitespace from JSON string values
#
# This script post-processes JSON files created by poll.sh to clean up whitespace
# issues that may occur when modem web servers return data with inconsistent formatting.
#
# The script recursively walks the JSON structure and removes leading/trailing
# whitespace from all string values, then compares hashes to detect changes.
# Only modified files are written back to disk.
#
# Usage:
#   ./scrub_whitespace.sh [-v] <file-or-glob-or-directory>
#
# Arguments:
#   -v                    Enable verbose output (shows processing status with ✓/✗/⚠️  indicators)
#   <file-or-glob-or-dir>  Single file, glob pattern, or directory of JSON files
#
# Examples:
#   ./scrub_whitespace.sh -v hitron-data/
#   ./scrub_whitespace.sh data-test/data-*.json
#   ./scrub_whitespace.sh -v data-test/data-20260000_000000.json
#
# Dependencies:
#   - jq: JSON query tool
#   - sponge: Unix tool to write back to same file (from moreutils package)
#   - sha256sum: For hash comparison (detect changes)

verbose=0

usage() {
  echo "Usage: $0 [-v] <file-or-glob-or-directory>" >&2
  exit 1
}

while getopts ":v" opt; do
  case $opt in
    v) verbose=1 ;;
    \?) usage ;;
  esac
done
shift $((OPTIND-1))

[[ $# -eq 1 ]] || usage
target="$1"

command -v jq >/dev/null 2>&1 || { echo "Install jq" >&2; exit 1; }
command -v sponge >/dev/null 2>&1 || { echo "Install sponge (moreutils)" >&2; exit 1; }

FILTER='walk(if type=="string" then sub("^\\s+";"")|sub("\\s+$";"") else . end)'

process_file() {
  local file="$1"
  [[ $verbose == 1 ]] && echo "Processing: $file"
  
  # Skip non-JSON
  jq -e '.' "$file" >/dev/null 2>&1 || { 
    [[ $verbose == 1 ]] && echo "⚠️  Skipping non-JSON: $file"
    return 0 
  }
  
  # Check if needs trimming (hash comparison)
  local orig_hash filtered_hash
  orig_hash=$(sha256sum "$file" | cut -d' ' -f1)
  filtered_hash=$(jq "$FILTER" "$file" | sha256sum | cut -d' ' -f1)
  
  if [[ "$orig_hash" != "$filtered_hash" ]]; then
    jq "$FILTER" "$file" | sponge "$file"
    [[ $verbose == 1 ]] && echo "✓ Trimmed whitespace: $file"
  elif [[ $verbose == 1 ]]; then
    echo "✗ No changes: $file"
  fi
}

# Handle inputs
if [[ -f "$target" ]]; then
  process_file "$target"
elif [[ -d "$target" ]]; then
  find "$target" -type f \( -name '*.json' -o -name '*.jsonl' \) -print0 | 
    while IFS= read -r -d '' file; do process_file "$file"; done
else
  shopt -s nullglob
  for file in $target; do [[ -f "$file" ]] && process_file "$file"; done
  shopt -u nullglob
fi
