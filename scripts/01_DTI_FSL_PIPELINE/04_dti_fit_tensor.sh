#!/bin/bash

for cif_folder in xxxxx*/
    do

    mask=$(find "$cif_folder" -maxdepth 1 -name "*_brain_mask.nii.gz")
    eddy_unwarped=$(find "$cif_folder" -maxdepth 1 -name "C*_eddy_unwarped.nii.gz")
    bvec_file=$(find "$cif_folder" -maxdepth 1 -name "*.bvec")
    bval_file=$(find "$cif_folder" -maxdepth 1 -name "*.bval")
    cif_name=$(basename "$cif_folder")

    if [ -f "$mask" ] && [ -f "$eddy_unwarped" ] && [ -f "$bvec_file" ] && [ -f "$bval_file" ]
    then
    
    echo "$eddy_unwarped FOUND"
    dtifit --data="$eddy_unwarped" --mask="$mask" --bvecs="$bvec_file" --bvals="$bval_file" --out="$cif_folder/${cif_name}_DTI"

    else

    echo "One or more files NOT FOUND and dtifit INCOMPLETE for $cif_folder"
    fi

done
