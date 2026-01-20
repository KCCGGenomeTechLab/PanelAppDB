#!/bin/bash
# ------------------------------------------------------------------
# Download the latest PanelApp release file from GitHub
# and save it under a timestamped subdirectory.
# ------------------------------------------------------------------

die () {
    echo "$1" >&2
    exit 1
}

/path/gadi_schedule_panelapp.sh || die "PanelApp download failed"
/path/gadi_schedule_phenotype.sh || die "Phenotype download failed"

echo "[$(date)] All downloads completed successfully."

# cron job entry (example): run every month on the 1st at 6am
# 0 6 1 * * /path/gadi_schedule.sh >> /path/downloads/gadi_schedule.log 2>&1