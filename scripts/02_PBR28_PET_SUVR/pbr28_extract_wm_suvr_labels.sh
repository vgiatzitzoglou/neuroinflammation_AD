#!/bin/bash

# WM SUVR per label using cerebellum GM as reference.
# Assumes roughly:
#   ./AD018/processed/swAD018_PET.nii
#   ./AD018/processed/AD018_WM_ObjectMap.nii
#   ./AD018/processed/cereb.nii
# and similarly for other subjects (AD*, MCI*, C*, etc.)

OUTPUT="PET_WM_SUVR_labels.csv"
echo "Subject,Label,WM_mean,Cereb_mean,SUVR" > "$OUTPUT"

# loop through subject folders (adjust pattern if needed)
for subjdir in AD* MCI* C*; do
    # skip non-directories
    [ -d "$subjdir" ] || continue

    subj=${subjdir%/}
    proc="${subj}/processed"

    if [ ! -d "$proc" ]; then
        echo "warning: No 'processed' folder for $subj, skipping."
        continue
    fi

    echo "=============================="
    echo "Processing subject: $subj"
    echo "Folder: $proc"

    # locate PET image
    PET="${proc}/sw${subj}_PET.nii"
    if [ ! -f "$PET" ]; then
        # fallback: any *PET*.nii
        PET=$(find "$proc" -maxdepth 1 -type f -name "*PET*.nii" | head -n 1)
    fi

    if [ -z "$PET" ] || [ ! -f "$PET" ]; then
        echo "missing: PET file not found for $subj, skipping."
        continue
    fi

    # locate WM object map
    WM_MAP="${proc}/${subj}_WM_ObjectMap.nii"
    if [ ! -f "$WM_MAP" ]; then
        echo "missing: WM_ObjectMap not found for $subj ($WM_MAP), skipping."
        continue
    fi

    # locate cerebellum GM mask
    CEREB="${proc}/cereb.nii"
    if [ ! -f "$CEREB" ]; then
        echo "missing: cereb.nii not found for $subj, skipping."
        continue
    fi

    echo "PET    : $PET"
    echo "WM map : $WM_MAP"
    echo "Cereb  : $CEREB"

    # mean PET in cerebellum GM (reference)
    CEREB_MEAN=$(fslstats "$PET" -k "$CEREB" -M)
    if [ -z "$CEREB_MEAN" ]; then
        echo "missing: Could not compute cerebellum mean for $subj, skipping."
        continue
    fi
    echo "Cerebellum GM mean = $CEREB_MEAN"

    # find max label in WM map
    # fslstats -R prints "min max"
    MAX_LABEL=$(fslstats "$WM_MAP" -R | awk '{print int($2)}')
    echo "Max WM label = $MAX_LABEL"

    if [ "$MAX_LABEL" -lt 1 ]; then
        echo "warning: No labels >0 in WM map for $subj, skipping."
        continue
    fi

    # loop through all labels
    for label in $(seq 1 "$MAX_LABEL"); do
        # make binary ROI for this label
        ROI_MASK="${proc}/tmp_${subj}_label${label}.nii.gz"

        fslmaths "$WM_MAP" -thr "$label" -uthr "$label" -bin "$ROI_MASK" >/dev/null 2>&1

        # if ROI is empty, skip
        nonzero=$(fslstats "$ROI_MASK" -V | awk '{print $1}')
        if [ "$nonzero" -eq 0 ]; then
            rm -f "$ROI_MASK"
            continue
        fi

        # mean PET in this WM label
        WM_MEAN=$(fslstats "$PET" -k "$ROI_MASK" -M)

        # compute SUVR = WM_mean / cereb_mean
        SUVR=$(echo "$WM_MEAN / $CEREB_MEAN" | bc -l)

        echo "$subj,$label,$WM_MEAN,$CEREB_MEAN,$SUVR" >> "$OUTPUT"

        rm -f "$ROI_MASK"
    done

    echo "Done with $subj."
    echo ""
done

echo "Finished. Results saved to $OUTPUT"
