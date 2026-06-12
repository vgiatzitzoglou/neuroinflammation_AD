#!/bin/bash

DTI_DATA_ROOT="${DTI_DATA_ROOT:-./example_data/dti_subjects}"

for cif_folder in "$DTI_DATA_ROOT"/*/
    do

    V1_file=$(find "$cif_folder" -maxdepth 1 -name "*_DTI_V1.nii.gz")
    FA_file=$(find "$cif_folder" -maxdepth 1 -name "*_DTI_FA.nii.gz")
    cif_name=$(basename "${cif_folder%/}")

    if [ -f "$V1_file" ] && [ -f "$FA_file" ]
    then

    echo "$V1_file and $FA_file found"
    fslmaths "$V1_file" -abs -mul "$FA_file" "$cif_folder/${cif_name}_RGB"

    else

    echo "missing V1 or FA, RGB map not made for $cif_folder"
    fi

done
