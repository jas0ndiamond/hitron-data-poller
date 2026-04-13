# hitron-data-poller

Inspired by https://github.com/DannyTheVito/Simple-Hitron-Logger/

Retrieve WAN signal data from a hitron device for tracking over time. May work for other devices running hitron's web server.

For me, this was checking impact of using a coaxial surge protector on WAN signal.

Run as a cronjob or with unix `watch`.

---
### Setup
1. Verify `curl` and `jq` are installed
2. Determine your hitron device ip. Typically this is `192.168.100.1`.
3. Open the device web page (typically https://192.168.100.1) in a web browser and look for a `DOCSIS WAN` tab with populated information.

---
### Run
1. Run the shell script via `/path/to/poll.sh`, and look for json files created in `./hitron-data`.
2. Graph with local tools like gnuplot, or post to a MongoDB/InfluxDB instance and view with a Grafana dashboard.
3. Retrieve field data with `jq`:
```
$ jq .ds_qam[3].snr < data-20260000_000000.json
"38.605"
```
```
$ jq -r '"\(.timestamp) => \(.ds_qam[3].snr)"' data-20260000_000000.json
2026-02-27 21:24:01 => 38.605
```

---
### Charting Workflow

Generate PNG charts from accumulated modem signal measurements using this three-step workflow:

#### Step 1: Accumulate Data
Run `poll.sh` repeatedly (via cronjob or `watch`) to accumulate modem signal measurements:
```bash
./poll.sh
```
This creates JSON files in the `./hitron-data` directory (or whichever data directory you configure).

#### Step 2: Generate Charting Data
Once you have accumulated several measurements, convert the JSON data into CSV format organized by signal category:
```bash
./generate-graph-data.sh hitron-data
```
This processes all JSON files in `hitron-data` and creates a `chart-YYYYMMDD-HHMMSS/` directory containing CSV files for each signal category:
- `us_qam.csv` — Upstream QAM signal strength
- `ds_qam.csv` — Downstream QAM signal strength and SNR
- `us_ofdm.csv` — Upstream OFDM measurements
- `ds_ofdm.csv` — Downstream OFDM measurements

#### Step 3: Plot Charts
Generate PNG charts from the CSV data using gnuplot:
```bash
./plot.sh chart-YYYYMMDD-HHMMSS/us_qam.csv
./plot.sh chart-YYYYMMDD-HHMMSS/ds_qam.csv
```
This creates PNG files with date-labeled x-axes:
- `us_qam.png` — Upstream QAM signal over time
- `ds_qam.png` — Downstream QAM signal and SNR over time

---
### Utils

Post-process modem data JSON files collected by `poll.sh` using utility scripts in the `utils/` directory.

#### filter.sh
Removes invalid or disabled modem channel entries from JSON data files.

This script applies jq filters to remove:
- Upstream OFDM entries marked as "DISABLED"
- Downstream OFDM entries marked as "NA" (not applicable)

These entries represent non-functional modem channels that would skew chart data.

**Usage:**
```bash
./utils/filter.sh [-v] <file-or-directory>
```

**Examples:**
```bash
# Filter all JSON files in a directory
./utils/filter.sh hitron-data/

# Filter with verbose output
./utils/filter.sh -v data-test/data-20260000_000000.json
```

**Dependencies:** `jq`, `sponge` (from moreutils package)

#### scrub_whitespace.sh
Trims leading and trailing whitespace from JSON string values.

The modem's web server sometimes returns data with inconsistent whitespace formatting. This script recursively walks the JSON structure and removes extraneous whitespace from all string values. Only files with actual changes are written back to disk.

**Usage:**
```bash
./utils/scrub_whitespace.sh [-v] <file-or-glob-or-directory>
```

**Examples:**
```bash
# Clean all JSON files in a directory with verbose output
./utils/scrub_whitespace.sh -v hitron-data/

# Clean files matching a glob pattern
./utils/scrub_whitespace.sh data-test/data-*.json

# Clean a single file
./utils/scrub_whitespace.sh data-test/data-20260000_000000.json
```

**Dependencies:** `jq`, `sponge` (from moreutils package)

---
### Notes
* If curl requests to data endpoints fail, check if the script's endpoints are correct by refreshing the `DOCSIS WAN` page with browser tools open to the networking tab or request viewer.
* Curl requests do not use retry, as this script is intended to run with higher frequency.
* Curl requests are done over http rather than https. Often the web server has weaker keys, and curl's certificate validation will fail. Using curl with https in spite of this requires the `-k` flag.
  * Determine server key length with `echo | openssl s_client -connect 192.168.100.1:443 -servername 192.168.100.1 | openssl x509 -noout -text | grep "Public-Key"`
