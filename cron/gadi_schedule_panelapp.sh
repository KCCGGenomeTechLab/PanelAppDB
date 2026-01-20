#!/bin/bash
# ------------------------------------------------------------------
# Download the latest PanelApp release file from GitHub
# and save it under a timestamped subdirectory.
# ------------------------------------------------------------------

die () {
    echo "$1" >&2
    exit 1
}

# Base output directory
OUT_DIR="/path/downloads"

# Timestamp format: e.g. month_year (October_2023)
TIMESTAMP=$(date +'%B_%Y')
TARGET_DIR="${OUT_DIR}/${TIMESTAMP}"
mkdir -p "$TARGET_DIR"

# File URL
URL="https://github.com/hiruna72/PanelApp_t0/releases/latest/download/all_panels.tsv"
URL2="https://github.com/hiruna72/PanelApp_t0/releases/latest/download/panel_manifest.tsv"

# Output file path
OUT_FILE="${TARGET_DIR}/all_panels.tsv"
OUT_FILE2="${TARGET_DIR}/panel_manifest.tsv"

echo "[$(date)] Downloading latest PanelApp release to: $OUT_FILE"

wget -q -O "$OUT_FILE" "$URL" || die "Failed to download $URL"
wget -q -O "$OUT_FILE2" "$URL2" || die "Failed to download $URL2"

echo "[$(date)] Download completed successfully."

# scp to gadi
GADI_USER="username"  # replace with your Gadi username
GADI_HOST="gadi-dm.nci.org.au"
GADI_DIR="/path/puzzleapp/db/panelapp"

scp -r "$TARGET_DIR" "${GADI_USER}@${GADI_HOST}:${GADI_DIR}/" || die "Failed to copy files to Gadi"

echo "[$(date)] Files copied to Gadi successfully."
