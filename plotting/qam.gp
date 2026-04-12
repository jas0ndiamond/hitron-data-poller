# plot_us_or_ds.gp — reads DATA_FILE and ACTIONS_FILE from -e

# Defaults if caller didn't set
DATA_FILE = "unknown.csv"
ACTIONS_FILE = ""

# Output file base name from DATA_FILE
OUTPUT_BASE = strcol(0)
# Strip path and extension
if (strstrt(DATA_FILE,"/")>=0) OUTPUT_BASE = strcol(strstr(DATA_FILE,"/")+1)
if (strstrt(OUTPUT_BASE,".")>=0) OUTPUT_BASE = substr(OUTPUT_BASE,1,strstr(OUTPUT_BASE,".")-1)

set terminal pngcairo size 1000,600 font ",12"
set output sprintf("%s_%s.png", OUTPUT_BASE, "signals")

set datafile separator ","
set format x "%H:%M:%S"
set xlabel "Timestamp"
set ylabel "Signal (dBmV) / SNR (dB)"
set title "QAM Signal and SNR over Time"
set grid

# Step 1: plot main CSV without time axis so stats works
unset xdata
plot DATA_FILE using 1:3 with lines title "signalStrength_dBmV", \
     "" using 1:4 with lines title "snr_dB"

# Step 2: get timestamp range
stats DATA_FILE using 1 nooutput

# Step 3: switch to time axis
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"

# Step 4: optionally read and draw actions
if (ACTIONS_FILE ne "") {
    file_exists(file) = int(system("[ -f '".file."' ] && echo 1 || echo 0"))

    if (file_exists(ACTIONS_FILE)) {
        set table $ACTIONS
        plot ACTIONS_FILE using 1:(0) with table
        unset table

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
    } else {
        print "Error: ACTIONS_FILE exists in script args but not found on disk: ", ACTIONS_FILE
        exit 1
    }
} else {
    print "No actions CSV supplied; skipping action markers."
}

replot
