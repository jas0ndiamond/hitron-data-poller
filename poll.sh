#!/bin/bash

# poll hitron device for its WAN signal data

# creates a ./hitron-data/ directory, and writes json of results to a file with each run.

##############################################

# make a quiet request to the endpoint, skip cert check
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

################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# common modem ip
HOST="192.168.100.1"

# endpoints for modem data returning json.
# thanks DannyTheVito
DS_QAM_URL="https://$HOST/data/dsinfo.asp"
US_QAM_URL="https://$HOST/data/usinfo.asp"
DS_OFDM_URL="https://$HOST/data/dsofdminfo.asp"
US_OFDM_URL="https://$HOST/data/usofdminfo.asp"

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
TS="$(date +"%Y%m%d_%H%M%S")"

TARGET_DIR="$SCRIPT_DIR/hitron-data"

if ! [ -d "$TARGET_DIR" ]; then
	#echo "Creating directory $TARGET_DIR"
	mkdir -p "$TARGET_DIR"
fi

FILE="$TARGET_DIR/data-$TS.json"

################
# curl commands to the endpoints

# downstream qam
make_req "$DS_QAM_URL" DS_QAM_OUTPUT

# upstream qam
make_req "$US_QAM_URL" US_QAM_OUTPUT

# downstream ofdm
make_req "$DS_OFDM_URL" DS_OFDM_OUTPUT

# upstream ofdm
make_req "$US_OFDM_URL" US_OFDM_OUTPUT

OUT_FILE="$TARGET_DIR/data-$TS.json"

#echo "$DS_QAM_OUTPUT $US_QAM_OUTPUT $DS_OFDM_OUTPUT $US_OFDM_OUTPUT" |
jq -n\
 --argjson ds_qam "$DS_QAM_OUTPUT"\
 --argjson us_qam "$US_QAM_OUTPUT"\
 --argjson ds_ofdm "$DS_OFDM_OUTPUT"\
 --argjson us_ofdm "$US_OFDM_OUTPUT"\
 '{ds_qam: $ds_qam, us_qam: $us_qam, ds_ofdm: $ds_ofdm, us_ofdm: $us_ofdm}' > "$OUT_FILE" || {
	echo "Error: parsing json result" >&2
        exit 1
}
