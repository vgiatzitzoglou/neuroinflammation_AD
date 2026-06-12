#!/bin/bash

# steps:
# 1. loop through DTI subject folders
# 2. take the first b0 volume with fslroi
# 3. run BET to make the brain mask for eddy/dtifit

# loop through subject folders under DTI_DATA_ROOT
DTI_DATA_ROOT="${DTI_DATA_ROOT:-./example_data/dti_subjects}"

for subject_folder_path in "$DTI_DATA_ROOT"/*/
    do

    [ ! -d "$subject_folder_path" ] && continue

    # remove the trailing slash: AD014/ -> AD014
    subject_folder=${subject_folder_path%/}

    # subject id from folder name
    subject_name=$(basename "$subject_folder")

    dwi_input_file="${subject_folder}/${subject_name}.nii.gz"

    nodif_output_file="${subject_folder}/nodif.nii.gz"

    # check if the main DWI file exists
    if [ -f "$dwi_input_file" ]
    then
        echo "processing $subject_name..."

        # extract b0, then make BET mask
        fslroi "$dwi_input_file" "$nodif_output_file" 0 1
        echo "extracted $nodif_output_file from $dwi_input_file"

        bet "$nodif_output_file" "${subject_folder}/${subject_name}_brain" -m -f 0.2
        echo "brain extraction done for $subject_name"
    else
        echo "error: main DWI file $dwi_input_file not found in folder $subject_folder"
    fi

done
