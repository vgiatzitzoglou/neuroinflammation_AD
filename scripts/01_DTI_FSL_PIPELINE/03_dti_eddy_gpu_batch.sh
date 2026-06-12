#!/bin/bash

# steps:
# 1. loop through subject folders
# 2. check DWI, mask, bvec/bval, acqparams, index
# 3. run eddy_cuda if outputs are not already there

# config
main_dir="${DTI_DATA_ROOT:-./example_data/dti_subjects}"
subject_pattern="${DTI_SUBJECT_PATTERN:-*}"

eddy_executable="eddy_cuda11.0"
if ! command -v "$eddy_executable" > /dev/null 2>&1
then
    echo "error: $eddy_executable not found. check FSL/GPU setup"
    exit 1
fi
# ---------------------

for subject_folder in "$main_dir"/$subject_pattern
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
        echo "  - output already exists, skipping"
        continue
    fi

    # check inputs
    if [ -f "$dwi_file" ] && [ -f "$mask" ] && [ -f "$bvec_file" ] && [ -f "$bval_file" ] && [ -f "$acqparams_file" ] && [ -f "$index_file" ]
    then

        # run eddy
        "$eddy_executable" diffusion \
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
        echo "  - error: missing required file(s) for $subject_name, skipping"
        [ ! -f "$dwi_file" ] && echo "    - missing DWI file ($dwi_file)"
        [ ! -f "$mask" ] && echo "    - missing brain mask ($mask)"
        [ ! -f "$bvec_file" ] && echo "    - missing bvec file ($bvec_file)"
        [ ! -f "$bval_file" ] && echo "    - missing bval file ($bval_file)"
        [ ! -f "$acqparams_file" ] && echo "    - missing acqparams file ($acqparams_file)"
        [ ! -f "$index_file" ] && echo "    - missing index file ($index_file)"
    fi

done

echo "gpu batch done"
