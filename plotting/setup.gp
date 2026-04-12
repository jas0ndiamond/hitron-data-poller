# setup.gp  – invoked by plot_us_qam.gp and plot_ds_qam.gp

# --- Defaults (can be overridden by shell -e) ---
#DATA_FILE    = "unknown.csv"

if (!exists("DATA_FILE")) {
    DATA_FILE = "unknown.csv"
}

ACTIONS_FILE = ""
#SCHEMA       = "us"   # or "ds"

# --- Ensure gnuplot knows where to find the data files ---
if (DATA_FILE eq "unknown.csv") {
    print "Error: DATA_FILE not set; pass via -e DATA_FILE='...'"
    exit 1
}

print "Using data file: ", DATA_FILE

file_exists(file) = int(system("[ -f '".file."' ] && echo 1 || echo 0"))

if (strlen(DATA_FILE) > 0) {
    if (!file_exists(DATA_FILE)) {
        print "Data file not found: ", DATA_FILE
        exit 1
    }
}

#if (strlen(DATA_FILE) > 0 && system("[ -f ".DATA_FILE." ]") || 0) {
#    print "Data file not found: ", DATA_FILE
#    exit 1
#}

# --- Optional actions file ---
if (strlen(ACTIONS_FILE) > 0) {
    if (system("[ -f ".ACTIONS_FILE." ]") || 0) {
        print "Actions file not found: ", ACTIONS_FILE
        exit 1
    }
    # Read actions into datablock
    set table $ACTIONS
    plot ACTIONS_FILE using 1:(0) with table
    unset table
}

# --- General plotting defaults ---
set datafile separator ","
set format x "%H:%M:%S"
set xlabel "Timestamp"
set grid

set terminal pngcairo size 1000,600 font ",12"

# --- Time axis setup --- (after stats, see below)
#set xdata time
#set timefmt "%Y-%m-%d %H:%M:%S"
