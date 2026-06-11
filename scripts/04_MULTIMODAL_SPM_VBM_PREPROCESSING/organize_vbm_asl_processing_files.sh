#!/bin/bash
# This script organizes VBM/ASL processing files from a complex source
# directory into a new, clean directory structure by processing an
# explicit list of subjects.
# This version skips files that already exist in the destination.

echo "--- Starting ASL Data Organization ---"

# --- Configuration ---

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!  This list has been populated with your 43 subjects.           !!
# !!  AD subject names have been corrected (e.g., AD14).            !!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBJECTS=(
    "AD14" "AD18" "AD23" "AD24" "AD27" "AD29" "AD30" "AD35"
    "AD36" "AD42" "C004" "C008" "C011" "C012" "C013" "C018" "C023"
    "C029" "C030" "C035" "C036" "C037" "C041" "C41(MCI181)" "MCI013"
    "MCI024" "MCI032" "MCI037" "MCI039" "MCI040" "MCI045" "MCI051"
    "MCI057" "MCI059" "MCI084" "MCI095" "MCI100" "MCI104" "MCI106"
    "MCI141" "MCI153" "MCI156" "MCI163"
)
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# Source directory for ASL scans
SOURCE_DIR="${ASL_SOURCE_DIR:-./example_data/asl_source}"

# Destination directory for organised ASL files
DEST_DIR="${ASL_DEST_DIR:-./organized_asl}"

# --- End Configuration ---

# Create the main destination folder
mkdir -p "$DEST_DIR"
echo "Creating/updating output directory: $DEST_DIR"

# Loop through each subject in the explicit list
for SUBJ_NAME in "${SUBJECTS[@]}"; do
    
    # --- 1. Determine Group from Subject ID ---
    GROUP=""
    if [[ "$SUBJ_NAME" == AD* ]]; then
        GROUP="AD"
    elif [[ "$SUBJ_NAME" == C* || "$SUBJ_NAME" == HC* ]]; then
        GROUP="HC"
    elif [[ "$SUBJ_NAME" == MCI* ]]; then
        GROUP="MCI"
    else
        # Handle the special case C41(MCI181)
        if [[ "$SUBJ_NAME" == "C41(MCI181)" ]]; then
            GROUP="HC" # Assuming 'C' prefix means HC group
        else
            echo "WARNING: Could not determine group for $SUBJ_NAME. Skipping."
            continue
        fi
    fi

    echo "--- Processing Subject: $SUBJ_NAME (Group: $GROUP) ---"

    # --- 2. Check if Source Subject Directory Exists ---
    subj_path="$SOURCE_DIR/$GROUP/$SUBJ_NAME"
    if [ ! -d "$subj_path" ]; then
        echo "  ERROR: Source directory not found: $subj_path. Skipping."
        continue
    fi

    # Create the new clean subject folder
    SUBJ_DEST_DIR="$DEST_DIR/$SUBJ_NAME"
    mkdir -p "$SUBJ_DEST_DIR"

    # --- 3. Define file patterns to find and rename ---
    declare -A FILE_MAP
    FILE_MAP=(
        ["c1*.nii"]="c1"
        ["c2*.nii"]="c2"
        ["c3*.nii"]="c3"
        ["c4*.nii"]="c4"
        ["c5*.nii"]="c5"
        ["rc1*.nii"]="rc1"
        ["rc2*.nii"]="rc2"
        ["smwc1*.nii"]="smwc1"
        ["smwc2*.nii"]="smwc2"
        ["GM_Object_map_*.nii"]="GM_Object_map"
        ["WM_Object_map_*.nii"]="WM_Object_map"
    )

    # --- 4. Find, Copy, and Rename ---
    for pattern in "${!FILE_MAP[@]}"; do
        NEW_PREFIX="${FILE_MAP[$pattern]}"
        
        # Find the file. Use -maxdepth 1 to stay in the subject folder
        # We also add -type f to ensure we only get files
        FOUND_FILE=$(find "$subj_path" -maxdepth 1 -type f -name "$pattern" -print -quit)
        
        if [ -n "$FOUND_FILE" ]; then
            # File was found
            # Get the extension (handles .nii and .nii.gz)
            EXTENSION="${FOUND_FILE##*.nii}" # This will be ".gz" or ""
            
            # Construct the new name, e.g., "c1_AD14.nii"
            NEW_NAME="${NEW_PREFIX}_${SUBJ_NAME}.nii${EXTENSION}"
            DEST_FILE="$SUBJ_DEST_DIR/$NEW_NAME"
            
            # --- MODIFIED SECTION ---
            # Check if the destination file already exists
            if [ -f "$DEST_FILE" ]; then
                echo "  SKIPPED: $NEW_NAME already exists."
            else
                # Copy the file only if it's missing
                cp "$FOUND_FILE" "$DEST_FILE"
                echo "  COPIED: $(basename "$FOUND_FILE")  ==>  $NEW_NAME"
            fi
            # --- END MODIFIED SECTION ---
            
        else
            # File was not found
            echo "  WARNING: Could not find file for pattern '$pattern' in $subj_path"
        fi
    done

done

echo "--- ASL Data Organization Finished! ---"


