# ofdm_combined.gp — Plot both upstream and downstream OFDM measurements on combined charts

# This script expects two data files to be passed via -e:
#   DATA_FILE_US: path to us_ofdm.csv
#   DATA_FILE_DS: path to ds_ofdm.csv

# Derive output base name from the first data file's directory
OUTPUT_BASE = DATA_FILE_US
# Strip path (find last "/" and take substring after it)
idx_slash = strstrt(OUTPUT_BASE, "/")
while (idx_slash > 0) {
    OUTPUT_BASE = substr(OUTPUT_BASE, idx_slash + 1, strlen(OUTPUT_BASE))
    idx_slash = strstrt(OUTPUT_BASE, "/")
}
# Strip extension and remove "us_ofdm" suffix to get chart name
idx_dot = strstrt(OUTPUT_BASE, ".")
if (idx_dot > 0) {
    OUTPUT_BASE = substr(OUTPUT_BASE, 1, idx_dot - 1)
}
# Remove "us_ofdm" suffix
if (strstrt(OUTPUT_BASE, "us_ofdm") > 0) {
    OUTPUT_BASE = "ofdm_combined"
}

set terminal pngcairo size 1400,800 font ",11"
set output sprintf("%s.png", OUTPUT_BASE)

set datafile separator ","
set format x "%Y-%m-%d"
set grid
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set xtics rotate by -45

# Create two subplots
set multiplot layout 2,1 title "OFDM Measurements over Time"

# Subplot 1: Downstream OFDM (Signal and SNR)
set ylabel "Signal (dBmV) / SNR (dB)"
set title "Downstream OFDM: Signal and SNR"
set bmargin 0
plot DATA_FILE_DS using 1:5 with lines title "plcpower_dBmV", \
     "" using 1:3 with lines title "SNR_dB"

# Subplot 2: Upstream OFDM (Power and Attenuation)
set ylabel "Power (dBmV) / Attenuation (dB)"
set title "Upstream OFDM: Transmission Power"
set bmargin 5
set xlabel "Date"
plot DATA_FILE_US using 1:6 with lines title "repPower (dBmV)", \
     "" using 1:4 with lines title "digAtten (dB)"

unset multiplot
