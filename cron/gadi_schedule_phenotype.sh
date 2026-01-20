#!/bin/bash
set -euo pipefail

# Root directory where releases are stored
OUT_DIR="/path/downloads_hpo"
mkdir -p "${OUT_DIR}"

# Get latest release metadata from GitHub
RELEASE_JSON=$(curl -s https://api.github.com/repos/obophenotype/human-phenotype-ontology/releases/latest)
LATEST_TAG=$(echo "$RELEASE_JSON" | grep -Po '"tag_name": "\K.*?(?=")')
PUBLISHED_AT=$(echo "$RELEASE_JSON" | grep -Po '"published_at": "\K.*?(?=")')

# Convert to epoch timestamps
RELEASE_EPOCH=$(date -d "$PUBLISHED_AT" +%s)
NOW_EPOCH=$(date +%s)
AGE_DAYS=$(( (NOW_EPOCH - RELEASE_EPOCH) / 86400 ))

echo "Latest HPO release: $LATEST_TAG ($AGE_DAYS days old)"

# Check if release is within 30 days
if [ "$AGE_DAYS" -gt 30 ]; then
  echo "No new release this month (latest is $AGE_DAYS days old)."
  exit 0
fi

# Timestamp format: e.g. month_year (October_2023)
TIMESTAMP=$(date +'%B_%Y')
TARGET_DIR="${OUT_DIR}/${TIMESTAMP}"
mkdir -p "${TARGET_DIR}"

echo "New release detected — downloading to ${TARGET_DIR} ..."
wget -q -O "${TARGET_DIR}/phenotype_to_genes.txt" "https://github.com/obophenotype/human-phenotype-ontology/releases/download/${LATEST_TAG}/phenotype_to_genes.txt"

echo "Download complete: ${TARGET_DIR}/phenotype_to_genes.txt"

# scp to gadi
GADI_USER="username"  # replace with your Gadi username
GADI_HOST="gadi-dm.nci.org.au"
GADI_DIR="/path/puzzleapp/db/phenotype"

scp -r "${TARGET_DIR}" "${GADI_USER}@${GADI_HOST}:${GADI_DIR}/" || die "Failed to copy files to Gadi"

echo "[$(date)] Files copied to Gadi successfully."
