# --- Caller is expected to set:
#        DATA_FILE = 'chart-20260327-162053/us_qam.csv'
#        [optional] ACTIONS_FILE
#        SCHEMA    = "us"  (optional, for consistency)

load "setup.gp"

set output "ds_qam.png"
set ylabel "signalStrength_dBmV"
set title "US QAM Signal Strength over Time"

#print "Using data file: ", DATA_FILE
print "DATA_FILE = [",DATA_FILE,"]"

# --- Plot with numeric x (so stats works) ---
unset xdata
plot DATA_FILE using 1:3 with lines title "signalStrength"

# --- Enable time axis and stats ---
stats DATA_FILE using 1 nooutput
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"

# --- Optional action markers (from setup.gp) ---
if (strlen(ACTIONS_FILE) > 0) {
    do for [i=1:|$ACTIONS|] {
        entry = $ACTIONS[i]
        parts = words(entry)
        t = word(entry,1)
        act = word(entry,2)
        if (act eq "sp_on") {
            set arrow from strptime("%Y-%m-%d %H:%M:%S",t), graph 0 \
                       to strptime("%Y-%m-%d %H:%M:%S",t), graph 1 \
                       nohead lc rgb "forest-green" lw 2 front
        }
        if (act eq "sp_off") {
            set arrow from strptime("%Y-%m-%d %H:%M:%S",t), graph 0 \
                       to strptime("%Y-%m-%d %H:%M:%S",t), graph 1 \
                       nohead lc rgb "red" lw 2 front
        }
    }
}

replot
