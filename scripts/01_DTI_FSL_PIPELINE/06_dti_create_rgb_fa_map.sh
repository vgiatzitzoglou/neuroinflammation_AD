#!/bin/bash

for cif_folder in xxxxxxxxxx*/
    do

    V1_file=$(find "$cif_folder" -maxdepth 1 -name "xxxxxxxx???_DTI_V1.nii.gz")
    FA_file=$(find "$cif_folder" -maxdepth 1 -name "xxxxxxx???_DTI_FA.nii.gz")
    cif_name=$(basename "$cif_folder")

    if [ -f "$V1_file" ] && [ -f "$FA_file" ]
    then

    echo "$V1_file and $FA_file FOUND"
    fslmaths "$V1_file" -abs -mul "$FA_file" "$cif_folder/${cif_name}_RGB"

    else

    echo "One or more files NOT FOUND and dtifit INCOMPLETE for $cif_folder"
    fi

done
