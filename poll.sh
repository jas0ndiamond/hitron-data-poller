#!/bin/bash

# poll hitron device for its WAN signal data

# creates a ./hitron-data/ directory, and writes json of results to a file with each run.

##############################################
# functions

# make a quiet request to the endpoint, skip cert check
# no curl retries, as this will likely be run again on its own
make_req () {
	local endpoint="$1"
	local varname="$2"

	local result
	result=$(curl -k -s -f -H "Accept: application/json" "$endpoint" || {
                 echo "Error: Failed to fetch $endpoint" >&2
                 exit 1
                }
	)

	# Assign to variable name passed as parameter
	printf -v "$varname" '%s' "$result"
}

##############################################
# main

################
# Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed or not found in PATH" >&2
    exit 1
fi

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed or not found in PATH" >&2
    exit 1
fi

################
# set variables

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# common modem ip
HOST="192.168.100.1"

# endpoints for modem data returning json.
# thanks DannyTheVito
DS_QAM_URL="https://$HOST/data/dsinfo.asp"
US_QAM_URL="https://$HOST/data/usinfo.asp"
DS_OFDM_URL="https://$HOST/data/dsofdminfo.asp"
US_OFDM_URL="https://$HOST/data/usofdminfo.asp"

TS_FIELD="timestamp"

# base timestamp, formatted for a filename, and as common datetime
BASE_TS=$(date +%s)
FILE_TS_SUFFIX="$(date -d "@$BASE_TS" +"%Y%m%d_%H%M%S")"
MEASUREMENT_TS="$(date -d "@$BASE_TS" +"%Y-%m-%d %H:%M:%S")"

TARGET_DIR="$SCRIPT_DIR/hitron-data"

OUT_FILE="$TARGET_DIR/data-$FILE_TS_SUFFIX.json"

################
# Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed or not found in PATH" >&2
    exit 1
fi

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed or not found in PATH" >&2
    exit 1
fi

################
# create the target directory if it's missing
if ! [ -d "$TARGET_DIR" ]; then
	#echo "Creating directory $TARGET_DIR"
	mkdir -p "$TARGET_DIR"
fi

################
# curl commands to the device endpoints- expect json response

# downstream qam
make_req "$DS_QAM_URL" DS_QAM_OUTPUT

# upstream qam
make_req "$US_QAM_URL" US_QAM_OUTPUT

# downstream ofdm
make_req "$DS_OFDM_URL" DS_OFDM_OUTPUT

# upstream ofdm
make_req "$US_OFDM_URL" US_OFDM_OUTPUT

################
# aggregate results into one json doc, and add a timestamp in the data

JSON_RESULT=$(jq -n\
 --arg timestamp "$MEASUREMENT_TS"\
 --arg timestamp_field "$TS_FIELD"\
 --argjson ds_qam "$DS_QAM_OUTPUT"\
 --argjson us_qam "$US_QAM_OUTPUT"\
 --argjson ds_ofdm "$DS_OFDM_OUTPUT"\
 --argjson us_ofdm "$US_OFDM_OUTPUT"\
 '.[$timestamp_field] = $timestamp | .ds_qam = $ds_qam | .us_qam = $us_qam | .ds_ofdm = $ds_ofdm | .us_ofdm = $us_ofdm')

if [[ -z "$JSON_RESULT" ]]; then
	echo "Error: parsing/merging json result" >&2
        exit 1
fi

# write the file if jq succeeded
echo "$JSON_RESULT" > "$OUT_FILE"
