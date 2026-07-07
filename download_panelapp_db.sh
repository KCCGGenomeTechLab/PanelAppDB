#!/usr/bin/env bash
set -o pipefail

# PanelApp AU end-to-end:
# 1) Create a manifest (panel_id, version, name)
# 2) Download per-panel TSVs for those id+version pairs
# 3) Concatenate into a single TSV with header spaces converted to underscores
#
# Usage:
#   ./panelapp_to_tsv2.sh OUTPUT_DIR
#
# Notes:
# - Requires: curl, jq
# - API base can be overridden with env var PANELAPP_API_BASE
#   e.g., PANELAPP_API_BASE="https://panelapp.agha.umccr.org/api/v1" ./panelapp_to_tsv2.sh outdir

API_BASE_DEFAULT="https://panelapp-aus.org/api/v1"

EXPECTED_HEADER=$'Entity_Name\tEntity_type\tGene_Symbol\tSources(;_separated)\tLevel4\tLevel3\tLevel2\tModel_Of_Inheritance\tPhenotypes\tOmim\tOrphanet\tHPO\tPublications\tDescription\tFlagged\tGEL_Status\tUserRatings_Green_amber_red\tversion\tready\tMode_of_pathogenicity\tEnsemblId(GRch37)\tEnsemblId(GRch38)\tHGNC\tPosition_Chromosome\tPosition_GRCh37_Start\tPosition_GRCh37_End\tPosition_GRCh38_Start\tPosition_GRCh38_End\tSTR_Repeated_Sequence\tSTR_Normal_Repeats\tSTR_Pathogenic_Repeats\tRegion_Haploinsufficiency_Score\tRegion_Triplosensitivity_Score\tRegion_Required_Overlap_Percentage\tRegion_Variant_Type\tRegion_Verbose_Name'

USED_HEADER=$'Entity_Name\tEntity_type\tGene_Symbol\tSources\tLevel4\tLevel3\tLevel2\tModel_Of_Inheritance\tPhenotypes\tOmim\tOrphanet\tHPO\tPublications\tDescription\tFlagged\tGEL_Status\tUserRatings_Green_amber_red\tversion\tready\tMode_of_pathogenicity\tEnsemblId_GRch37\tEnsemblId_GRch38\tHGNC\tPosition_Chromosome\tPosition_GRCh37_Start\tPosition_GRCh37_End\tPosition_GRCh38_Start\tPosition_GRCh38_End\tSTR_Repeated_Sequence\tSTR_Normal_Repeats\tSTR_Pathogenic_Repeats\tRegion_Haploinsufficiency_Score\tRegion_Triplosensitivity_Score\tRegion_Required_Overlap_Percentage\tRegion_Variant_Type\tRegion_Verbose_Name\tPanel_ID\tPanel_Version'

PAGE_SUFFIX="01234"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

panelapp_panels_to_tsv() {
  # Args:
  #   $1 = out_path (manifest TSV)
  #   $2 = api_base
  local out_path="$1"
  local api_base="$2"

  echo "Writing panel manifest to: $out_path"
  printf 'panel_id\tversion\tname\n' >"$out_path" || die "Cannot write to $out_path"

  local url="${api_base%/}/panels/?page=1&page_size=100"
  while [ -n "$url" ]; do
    echo "Fetching page: $url"
    local json
    if ! json="$(curl -fsSL "$url")"; then
      die "curl failed for $url"
    fi

    # Append rows: id, version, cleaned name
    jq -r '
      .results[]
      | {id: (.id // .panel_id // .pk), version: (.version|tostring), name: (.name|tostring)}
      | select(.id and .version and .name)
      | [(.id|tostring), .version, (.name|gsub("\t";" ")|gsub("\r|\n";" "))]
      | @tsv
    ' <<<"$json" >>"$out_path" || die "jq failed to parse page results"

    url="$(jq -r '.next // ""' <<<"$json")"
  done
}

download_all() {
  # Args:
  #   $1 = out_dir (directory containing manifest and for storing TSVs)
  #   $2 = api_base
  #   $3 = [optional] count_limit (number of panels to download, for testing)
  local out_dir="$1"
  local api_base="$2"
  local count_limit="${3:-0}"  # 0 = no limit
  local manifest="$out_dir/panel_manifest.tsv"
  local panels_dir="$out_dir/panels"

  [ -s "$manifest" ] || die "Manifest not found or empty: $manifest"
  mkdir -p "$panels_dir" || die "Failed to create panels dir: $panels_dir"

  echo "Downloading panel TSVs into: $panels_dir"
  local total downloaded=0
  total="$(($(wc -l <"$manifest") - 1))" || total=0

  # Skip header line by starting from line 2
  tail -n +2 "$manifest" | while IFS=$'\t' read -r panel_id version name; do
    [ -n "$panel_id" ] && [ -n "$version" ] || continue
    local url="https://panelapp-aus.org/panels/${panel_id}/download/${PAGE_SUFFIX}/"
    # sanitize name for filename (remove spaces and slashes)
    name="${name// /_}"
    name="${name//\//_}"
    local out_file="${panels_dir}/${name}_${panel_id}_${version}.tsv"

    echo " - [$((++downloaded))/$total] ${panel_id} v${version} ${name}"
    if ! curl -fsSL \
     -H "User-Agent: Mozilla/5.0" \
     -H "Accept: text/plain" \
     -o "$out_file" \
     "$url"; then
      die "Failed to download panel ${panel_id} (v${version}) from ${url}"
    fi
    sleep 1  # uncomment to be gentle on the server

    # stop early if limit is reached (only if count_limit > 0)
    if (( count_limit > 0 && downloaded >= count_limit )); then
      echo "Reached count limit: $count_limit (stopping early)"
      break
    fi
  done
}

concat_tsvs() {
  # Args:
  #   $1 = out_dir
  local out_dir="$1"
  local panels_dir="$out_dir/panels"
  local combined="$out_dir/all_panels.tsv"

  [ -d "$panels_dir" ] || die "Panels directory not found: $panels_dir"

  # Ensure at least one panel TSV exists
  if ! ls -1 "$panels_dir"/*.tsv >/dev/null 2>&1; then
    die "No TSV files found in $panels_dir"
  fi

  echo "Writing combined TSV: $combined"
  printf '%s\n' "$USED_HEADER" >"$combined" || die "Cannot write $combined"

  # Append body (skip header) of each panel TSV to combined + add Panel_ID and Panel_Version columns the file has name {id}_{version}.tsv
  for f in "$panels_dir"/*.tsv; do
    base=${f##*/}              # e.g. "Additional findings_Paediatric_3302_0.278.tsv"
    stem=${base%.tsv}          # "Additional findings_Paediatric_3302_0.278"

    panel_version=${stem##*_}        # "0.278"        (after last underscore)
    rest=${stem%_*}            # "Additional findings_Paediatric_3302"
    panel_id=${rest##*_}       # "3302"         (after second-to-last underscore)
    name=${rest%_*}            # "Additional findings_Paediatric" (optional)

    # Validate THIS panel's header against the expected schema (space -> _,
    # CR stripped) so a panel with reordered/renamed/missing columns fails
    # loudly instead of silently misaligning the combined output.
    local header_us
    header_us="$(head -n 1 "$f" | tr -d '\r' | sed 's/ /_/g')"
    if [[ "$header_us" != "$EXPECTED_HEADER" ]]; then
      echo "Expected (repr): $(printf '%q' "$EXPECTED_HEADER")" >&2
      echo "Found    (repr): $(printf '%q' "$header_us")" >&2
      die "Header does not match expected format in: $f"
    fi

    tail -n +2 "$f" | awk -v OFS='\t' -v id="$panel_id" -v ver="$panel_version" -v fn="$base" '
      # PanelApp download endpoint wraps fields that contain tabs/commas in
      # double quotes (CSV-style) but leaves the literal tab inside them, which
      # otherwise splits one field into several columns. Parse quote-aware:
      # tabs inside quotes become spaces, doubled quotes ("") unescape to one,
      # and wrapping quotes are dropped, so every row lands on exactly 36 cols.
      {
        line = $0
        sub(/\r+$/, "", line)                     # strip CR (Windows line endings)
        if (line == "") next                      # skip empty lines

        nf = 0; field = ""; inq = 0
        n = length(line)
        for (i = 1; i <= n; i++) {
          c = substr(line, i, 1)
          if (c == "\"") {
            if (inq && substr(line, i + 1, 1) == "\"") { field = field "\""; i++ }
            else { inq = !inq }
          } else if (c == "\t" && !inq) {
            fld[++nf] = field; field = ""
          } else if (c == "\t") {
            field = field " "                       # tab inside a quoted field
          } else {
            field = field c
          }
        }
        fld[++nf] = field                         # last field

        rec = fld[1]
        for (j = 2; j <= nf; j++) rec = rec OFS fld[j]
        print rec, id, ver

        if (nf != 36)
          printf("WARN: %s: row parsed to %d fields (expected 36), panel %s v%s\n",
                 fn, nf, id, ver) > "/dev/stderr"
      }
    ' >>"$combined" || die "Failed to append $f"
  done

  # Assertion: every data row in the combined TSV must have exactly 38 columns
  # (36 source columns + Panel_ID + Panel_Version). Fail loudly otherwise.
  local bad_rows
  bad_rows="$(tail -n +2 "$combined" | awk -F'\t' 'NF != 38 { c++ } END { print c + 0 }')"
  if [ "$bad_rows" -ne 0 ]; then
    die "$bad_rows row(s) in $combined do not have 38 columns (see WARN lines above)"
  fi

  echo "Concatenation complete: $combined ($(($(wc -l <"$combined") - 1)) rows, all 38 columns)"
}

main() {
  require_cmd curl
  require_cmd jq

  local out_dir="$1"
  local api_base="${PANELAPP_API_BASE:-$API_BASE_DEFAULT}"

  if [ -z "$out_dir" ]; then
    echo "Usage: $0 OUTPUT_DIR" >&2
    exit 2
  fi
  if [ -e "$out_dir" ]; then
    die "Output directory already exists: $out_dir"
  fi

  mkdir -p "$out_dir" || die "Failed to create output dir: $out_dir"

  local manifest="$out_dir/panel_manifest.tsv"

  panelapp_panels_to_tsv "$manifest" "$api_base" || die "Failed to create panel manifest"
  download_all "$out_dir" "$api_base" || die "Failed to download panel TSVs"
  concat_tsvs "$out_dir" || die "Failed to concatenate panel TSVs"

  echo
  echo "Done."
  echo " - Manifest: $manifest"
  echo " - Panels dir: $out_dir/panels"
  echo " - Combined TSV: $out_dir/all_panels.tsv"
}

main "$@"
