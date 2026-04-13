# plot_us_or_ds.gp — reads DATA_FILE and ACTIONS_FILE from -e

# Output file base name from DATA_FILE
OUTPUT_BASE = DATA_FILE
# Strip path (find last "/" and take substring after it)
idx_slash = strstrt(OUTPUT_BASE, "/")
while (idx_slash > 0) {
    OUTPUT_BASE = substr(OUTPUT_BASE, idx_slash + 1, strlen(OUTPUT_BASE))
    idx_slash = strstrt(OUTPUT_BASE, "/")
}
# Strip extension (find "." and take substring before it)
idx_dot = strstrt(OUTPUT_BASE, ".")
if (idx_dot > 0) {
    OUTPUT_BASE = substr(OUTPUT_BASE, 1, idx_dot - 1)
}

set terminal pngcairo size 1000,600 font ",12"
set output sprintf("%s.png", OUTPUT_BASE)

set datafile separator ","
set format x "%Y-%m-%d"
set xlabel "Date"
set ylabel "Signal (dBmV) / SNR (dB)"
set title "QAM Signal and SNR over Time"
set grid
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set xtics rotate by -45
set bmargin 5

# Step 1: optionally read and draw actions
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
}

# Step 2: plot data with time axis properly configured
# Detect column count to handle both US QAM (3 cols) and DS QAM (4 cols)
col_count = int(system("head -2 " . DATA_FILE . " | tail -1 | awk -F',' '{print NF}'"))

if (col_count >= 4) {
    # Has SNR column (downstream QAM)
    plot DATA_FILE using 1:3 with lines title "signalStrength_dBmV", \
         "" using 1:4 with lines title "snr_dB"
} else {
    # Only signal column (upstream QAM)
    plot DATA_FILE using 1:3 with lines title "signalStrength_dBmV"
}
