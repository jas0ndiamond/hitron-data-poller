# hitron-data-poller

Inspired by https://github.com/DannyTheVito/Simple-Hitron-Logger/

Retrieve WAN signal data from a hitron device for tracking over time. May work for other modems running hitron's web server.

For me, this was checking impact of using a coaxial surge protector on WAN signal.

Run as a cronjob or with unix `watch`.

---
### Setup
1. Verify `curl` and `jq` are installed
2. Determine your hitron device ip. Typically this is `192.168.100.1`.
3. Open http://192.168.100.1 in your browser and look for a `DOCSIS WAN` tab with populated information.

---
### Run
1. Run the shell script, and look for json files created in `./hitron-data`.
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
### Notes
If curl requests to data endpoints fail, check if the script's endpoints are correct by refreshing the `DOCSIS WAN` page with browser tools open to the networking tab or request viewer.
