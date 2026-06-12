#!/bin/bash

# config
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

    echo "starting $subject_name (GPU)"

    # required files inside the subject folder
    dwi_file="$subject_folder/${subject_name}.nii.gz"
    mask="$subject_folder/${subject_name}_brain_mask.nii.gz"
    bvec_file="$subject_folder/${subject_name}.bvec"
    bval_file="$subject_folder/${subject_name}.bval"
    acqparams_file="$subject_folder/acqparams.txt"
    index_file="$subject_folder/index.txt"

    eddy_output="$subject_folder/${subject_name}_eddy_unwarped.nii.gz"


    # skip if already done
    if [ -f "$eddy_output" ]; then
        echo "  - Output already exists, skipping."
        continue
    fi

    # check inputs
    if [ -f "$dwi_file" ] && [ -f "$mask" ] && [ -f "$bvec_file" ] && [ -f "$bval_file" ] && [ -f "$acqparams_file" ] && [ -f "$index_file" ]
    then

        # run eddy
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

      echo "done with $subject_name"

    else
        # enough detail to see what is missing
        echo "  - ERROR: Missing required file(s) for $subject_name. Skipping."
        [ ! -f "$dwi_file" ] && echo "    - MISSING: DWI File ($dwi_file)"
        [ ! -f "$mask" ] && echo "    - MISSING: Brain Mask ($mask)"
        [ ! -f "$bvec_file" ] && echo "    - MISSING: Bvec File ($bvec_file)"
        [ ! -f "$bval_file" ] && echo "    - MISSING: Bval File ($bval_file)"
        [ ! -f "$acqparams_file" ] && echo "    - MISSING: Acqparams File ($acqparams_file)"
        [ ! -f "$index_file" ] && echo "    - MISSING: Index File ($index_file)"
    fi

done

echo "gpu batch done"
