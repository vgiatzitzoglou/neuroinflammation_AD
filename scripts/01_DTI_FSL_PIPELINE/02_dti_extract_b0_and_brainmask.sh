#!/bin/bash

# Loop through subject folders under DTI_DATA_ROOT.
DTI_DATA_ROOT="${DTI_DATA_ROOT:-./example_data/dti_subjects}"

for subject_folder_path in "$DTI_DATA_ROOT"/*/
    do

    [ ! -d "$subject_folder_path" ] && continue

    # Remove the trailing slash: AD014/ -> AD014
    subject_folder=${subject_folder_path%/}

    # Get the name of the subject (e.g., AD014)
    subject_name=$(basename "$subject_folder")

    # Correct Path: The DWI input file MUST include the folder path.
    DWI_input_file="${subject_folder}/${subject_name}.nii.gz"

    # Correct Path: The nodif output must also be placed inside the subject folder.
    nodif_output_file="${subject_folder}/nodif.nii.gz"

    # Check if the main DWI file exists
    if [ -f "$DWI_input_file" ]
    then
        echo "Processing $subject_name..."

        # A. Extract the b=0 volume (volume index 0, size 1)
        fslroi "$DWI_input_file" "$nodif_output_file" 0 1
        echo "Extracted $nodif_output_file from $DWI_input_file"

        # B. Run BET on the extracted b=0 volume
        # Output basename is saved as subject_name_brain (e.g., AD014_brain)
        bet "$nodif_output_file" "${subject_folder}/${subject_name}_brain" -m -f 0.2
        echo "Brain extraction complete for $subject_name"
    else
        echo "ERROR: Main DWI file $DWI_input_file NOT FOUND in folder $subject_folder"
    fi

done
