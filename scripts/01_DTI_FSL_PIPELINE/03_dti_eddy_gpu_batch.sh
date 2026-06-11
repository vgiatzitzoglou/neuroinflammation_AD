#!/bin/bash

# --- CONFIGURATION ---
MAIN_DIR="${DTI_DATA_ROOT:-./example_data/dti_subjects}"
SUBJECT_PATTERN="${DTI_SUBJECT_PATTERN:-*}"

EDDY_EXECUTABLE="eddy_cuda11.0"
if ! command -v "$EDDY_EXECUTABLE" &> /dev/null
then
    echo "ERROR: $EDDY_EXECUTABLE not found. Please ensure FSL is set up for GPU."
    exit 1
fi
# ---------------------

for subject_folder in "$MAIN_DIR"/$SUBJECT_PATTERN
do
    [ ! -d "$subject_folder" ] && continue
    subject_name=$(basename "$subject_folder")

    echo "--- Starting $subject_name (GPU) ---"

    # --- 1. FIND ALL REQUIRED INPUT FILES (inside the subject folder) ---
    dwi_file="$subject_folder/${subject_name}.nii.gz"
    mask="$subject_folder/${subject_name}_brain_mask.nii.gz"
    bvec_file="$subject_folder/${subject_name}.bvec"
    bval_file="$subject_folder/${subject_name}.bval"
    acqparams_file="$subject_folder/acqparams.txt"
    index_file="$subject_folder/index.txt"

    eddy_output="$subject_folder/${subject_name}_eddy_unwarped.nii.gz"


    # --- 2. CHECK FOR COMPLETION ---
    if [ -f "$eddy_output" ]; then
        echo "  - Output already exists, skipping."
        continue
    fi

    # --- 3. CHECK ALL INPUT FILES EXIST ---
    if [ -f "$dwi_file" ] && [ -f "$mask" ] && [ -f "$bvec_file" ] && [ -f "$bval_file" ] && [ -f "$acqparams_file" ] && [ -f "$index_file" ]
    then

        # --- 4. EXECUTE EDDY (GPU ACCELERATED) ---
        "$EDDY_EXECUTABLE" diffusion \
                           --imain="$dwi_file" \
                           --mask="$mask" \
                           --index="$index_file" \
                           --acqp="$acqparams_file" \
                           --bvecs="$bvec_file" \
                           --bvals="$bval_file" \
                           --flm=quadratic \
                           --out="$subject_folder/${subject_name}_eddy_unwarped" \
                           --data_is_shelled \
                           --fwhm=0

      echo "GPU_BATCH_COMPLETED_FOR_SUBJECT: $subject_name"

    else
        # --- 5. DETAILED ERROR LOGGING ---
        echo "  - ERROR: Missing required file(s) for $subject_name. Skipping."
        [ ! -f "$dwi_file" ] && echo "    - MISSING: DWI File ($dwi_file)"
        [ ! -f "$mask" ] && echo "    - MISSING: Brain Mask ($mask)"
        [ ! -f "$bvec_file" ] && echo "    - MISSING: Bvec File ($bvec_file)"
        [ ! -f "$bval_file" ] && echo "    - MISSING: Bval File ($bval_file)"
        [ ! -f "$acqparams_file" ] && echo "    - MISSING: Acqparams File ($acqparams_file)"
        [ ! -f "$index_file" ] && echo "    - MISSING: Index File ($index_file)"
    fi

done

echo "--- GPU Batch Processing Complete ---"
