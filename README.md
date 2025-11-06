# PanelAppDB 
Routinely (weekly) release PanelApp Australia database [panelapp-aus.org](panelapp-aus.org) compiled as a single .tsv file 

`download_panelap_db.sh` script downloads all PanelApp AU panels, generates a manifest of panel IDs and versions, and combines individual panel TSVs into a single consolidated TSV file.

### Download the latest release

1. `panel_manifest.tsv` — contains panel_id, version, and name for each panel
2. `all_panels.tsv` — a single TSV combining all individual panel TSVs with the extra `Panel_ID` (the numeric ID of the panel) and `Panel_Version` (the version of the panel) columns

```
wget https://github.com/KCCGGenomeTechLab/PanelAppDB/releases/latest/download/all_panels.tsv
wget https://github.com/KCCGGenomeTechLab/PanelAppDB/releases/latest/download/panel_manifest.tsv
```