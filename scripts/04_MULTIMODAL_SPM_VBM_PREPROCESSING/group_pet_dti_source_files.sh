#!/bin/bash
#
# This script finds T1, PET, and DTI files from their
# separate locations and copies them into a new, organized structure.
#
# It uses the final list of "complete" subjects.
#
echo "--- Starting Final Data Organization Script ---"

# --- 1. SCRIPT CONFIGURATION ---

# Source directories for your data
PET_T1_SOURCE_DIR="${PET_T1_SOURCE_DIR:-./example_data/pet_t1}"
DTI_SOURCE_DIR="${DTI_SOURCE_DIR:-./example_data/dti}"

# Destination for your new, clean folder structure
OUTPUT_DIR="${OUTPUT_DIR:-./organized_pet_dti}"

# Final list of subjects who have all required files
SUBJECTS=(
    "AD014"
    "AD018"
    "AD023"
    "AD024"
    "AD027"
    "AD029"
    "AD030"
    "AD035"
    "AD036"
    "AD042"
    "C004"
    "C008"
    "C011"
    "C012"
    "C013"
    "C018"
    "C023"
    "C029"
    "C030"
    "C035"
    "C036"
    "C037"
    "C041"
    "C41(MCI181)"
    "MCI013"
    "MCI024"
    "MCI032"
    "MCI037"
    "MCI039"
    "MCI040"
    "MCI045"
    "MCI051"
    "MCI057"
    "MCI059"
    "MCI084"
    "MCI095"
    "MCI100"
    "MCI104"
    "MCI106"
    "MCI141"
    "MCI153"
    "MCI156"
    "MCI163"
)
# --- 2. SCRIPT LOGIC (No edits needed) ---

# Create the main output directory
mkdir -p "$OUTPUT_DIR"
echo "Creating/updating output directory: $OUTPUT_DIR"

echo "Processing ${#SUBJECTS[@]} complete subjects..."

# Loop through each subject in your list
for SUB in "${SUBJECTS[@]}"; do
    
    echo "--- Processing Subject: $SUB ---"
    
    # Create a new, clean folder for this subject
    SUB_DIR="$OUTPUT_DIR/$SUB"
    mkdir -p "$SUB_DIR"
    
    # --- Determine Group from Subject ID ---
    GROUP=""
    if [[ "$SUB" == AD* ]]; then
        GROUP="AD"
    elif [[ "$SUB" == MCI* ]]; then
        GROUP="MCI"
    elif [[ "$SUB" == C* ]]; then
        GROUP="HC" # Use "HC" as the folder name for "C" subjects
    else
        echo "WARNING: Cannot determine group for $SUB. Skipping."
        continue
    fi
    echo "Determined Group: $GROUP (from Subject ID $SUB)"

    # --- ** FIX ** ---
    # Define file prefixes, which may be different from the folder name
    # By default, they are the same as the subject ID
    PET_T1_PREFIX=$SUB
    DTI_PREFIX=$SUB

    # This 'case' statement handles subjects where the file prefix (e.g., "AD14")
    # is different from the subject/folder ID (e.g., "AD014").
    case "$SUB" in
        "AD014") PET_T1_PREFIX="AD14" ;;
        "AD018") PET_T1_PREFIX="AD18" ;;
        "AD023") PET_T1_PREFIX="AD23" ;;
        "AD024") PET_T1_PREFIX="AD24" ;;
        "AD027") PET_T1_PREFIX="AD27" ;;
        "AD029") PET_T1_PREFIX="AD29" ;;
        "AD030") PET_T1_PREFIX="AD30" ;;
        "AD035") PET_T1_PREFIX="AD35" ;;
        "AD036") PET_T1_PREFIX="AD36" ;;
        "AD042") PET_T1_PREFIX="AD42" ;;
        "C004")  PET_T1_PREFIX="C4" ;;
        "C008")  PET_T1_PREFIX="C8" ;;
        "C011")  PET_T1_PREFIX="C11" ;;
        "C012")  PET_T1_PREFIX="C12" ;;
        "C013")  PET_T1_PREFIX="C13" ;;
        "C018")  PET_T1_PREFIX="C18" ;;
        "C023")  PET_T1_PREFIX="C23" ;;
        "C029")  PET_T1_PREFIX="C29" ;;
        "C030")  PET_T1_PREFIX="C30" ;;
        "C035")  PET_T1_PREFIX="C35" ;;
        "C036")  PET_T1_PREFIX="C36" ;;
        "C037")  PET_T1_PREFIX="C37" ;;
        "C041")  PET_T1_PREFIX="C41" ;;
        "C41(MCI181)") PET_T1_PREFIX="C41" ;;
    esac
    
    if [ "$PET_T1_PREFIX" != "$SUB" ]; then
        echo "Using special T1/PET file prefix: $PET_T1_PREFIX"
    fi
    # --- End of Fix ---


    # --- A. Find and Copy T1 & PET Scans ---
    # Path is: ${PET_T1_SOURCE_DIR}/{GROUP}/{SUB}
    # This path automatically ignores the {SUB}Contrast folders
    
    SEARCH_PATH_PET_T1="$PET_T1_SOURCE_DIR/$GROUP/$SUB"
    
    if [ -d "$SEARCH_PATH_PET_T1" ]; then
        echo "Searching for T1/PET in: $SEARCH_PATH_PET_T1"

        # Find T1 Scan - USES THE NEW PET_T1_PREFIX
        T1_FILE=$(find "$SEARCH_PATH_PET_T1" -type f -name "*${PET_T1_PREFIX}*MR_cc_reor.nii*" -print -quit)
        if [ -n "$T1_FILE" ]; then
            echo "Found T1: $T1_FILE"
            if [[ "$T1_FILE" == *.nii.gz ]]; then
                cp "$T1_FILE" "$SUB_DIR/T1.nii.gz"
            else
                cp "$T1_FILE" "$SUB_DIR/T1.nii"
            fi
        else
            echo "ERROR: T1 scan for $SUB not found (pattern: *${PET_T1_PREFIX}*MR_cc_reor.nii*)"
        fi

        # Find PET Scan - USES THE NEW PET_T1_PREFIX
        PET_FILE=$(find "$SEARCH_PATH_PET_T1" -type f -name "*${PET_T1_PREFIX}*PBR28*add.nii*" -print -quit)
        if [ -n "$PET_FILE" ]; then
            echo "Found PET: $PET_FILE"
            if [[ "$PET_FILE" == *.nii.gz ]]; then
                cp "$PET_FILE" "$SUB_DIR/PET.nii.gz"
            else
                cp "$PET_FILE" "$SUB_DIR/PET.nii"
            fi
        else
            echo "ERROR: PET scan for $SUB not found (pattern: *${PET_T1_PREFIX}*PBR28*add.nii*)"
        fi
    else
        echo "ERROR: PET/T1 directory not found for $SUB at: $SEARCH_PATH_PET_T1"
    fi

    # --- B. Find and Copy DTI Maps ---
    # Path is: ${DTI_SOURCE_DIR}/{GROUP}/{SUB}
    
    # ** Special rule for C* subjects -> HC folder **
    DTI_GROUP=$GROUP
    SEARCH_PATH_DTI="$DTI_SOURCE_DIR/$DTI_GROUP/$SUB" # Default path
    
    if [[ "$SUB" == C* ]]; then
        if [ -d "$DTI_SOURCE_DIR/HC/$SUB" ]; then
            DTI_GROUP="HC"
            SEARCH_PATH_DTI="$DTI_SOURCE_DIR/HC/$SUB"
        elif [ -d "$DTI_SOURCE_DIR/C/$SUB" ]; then
            DTI_GROUP="C"
            SEARCH_PATH_DTI="$DTI_SOURCE_DIR/C/$SUB"
        fi
        echo "Adjusted DTI group for $SUB to $DTI_GROUP"
    fi
    
    
    if [ -d "$SEARCH_PATH_DTI" ]; then
        echo "Searching for DTI in: $SEARCH_PATH_DTI"

        # Find DTI FA Map - USES THE DTI_PREFIX (which is just SUB)
        FA_FILE=$(find "$SEARCH_PATH_DTI" -type f -name "*${DTI_PREFIX}*DTI_FA.nii*" -print -quit)
        if [ -n "$FA_FILE" ]; then
            echo "Found FA: $FA_FILE"
            if [[ "$FA_FILE" == *.nii.gz ]]; then
                cp "$FA_FILE" "$SUB_DIR/dti_FA.nii.gz"
            else
                cp "$FA_FILE" "$SUB_DIR/dti_FA.nii"
            fi
        else
            echo "ERROR: DTI FA map for $SUB not found (pattern: *${DTI_PREFIX}*DTI_FA.nii*)"
        fi

        # Find DTI MD Map - USES THE DTI_PREFIX (which is just SUB)
        MD_FILE=$(find "$SEARCH_PATH_DTI" -type f -name "*${DTI_PREFIX}*DTI_MD.nii*" -print -quit)
        if [ -n "$MD_FILE" ]; then
            echo "Found MD: $MD_FILE"
            if [[ "$MD_FILE" == *.nii.gz ]]; then
                cp "$MD_FILE" "$SUB_DIR/dti_MD.nii.gz"
            else
                cp "$MD_FILE" "$SUB_DIR/dti_MD.nii"
            fi
        else
            echo "ERROR: DTI MD map for $SUB not found (pattern: *${DTI_PREFIX}*DTI_MD.nii*)"
        fi
    else
        echo "ERROR: DTI directory not found for $SUB at: $SEARCH_PATH_DTI"
    fi

done

echo "--- Organization complete! ---"
echo "Your clean data is in '$OUTPUT_DIR'."


