#!/bin/bash

# Folder with subject folders. Can override with DTI_DATA_ROOT.
input_dir="${DTI_DATA_ROOT:-./example_data/dti_subjects}"

# loop through subject folders
for subj_dir in "$input_dir"/*; do
  # skip non-folders
  if [ ! -d "$subj_dir" ]; then
    continue
  fi

  # subject id = folder name
  subj_number=$(basename "$subj_dir")

  # L1/L2/L3 names, edit if FSL output names are different
  L1_file="$subj_dir/${subj_number}_DTI_L1.nii.gz"
  L2_file="$subj_dir/${subj_number}_DTI_L2.nii.gz"
  L3_file="$subj_dir/${subj_number}_DTI_L3.nii.gz"

  # skip if tensor files missing
  if [ ! -f "$L1_file" ] || [ ! -f "$L2_file" ] || [ ! -f "$L3_file" ]; then
    echo "Warning: One or more of the required files (L1, L2, L3) for subject $subj_number are missing."
    continue
  fi

  # outputs
  AxD_output="$subj_dir/${subj_number}_DTI_AxD.nii.gz"
  RD_output="$subj_dir/${subj_number}_DTI_RD.nii.gz"

  # AD = L1
  fslmaths "$L1_file" -mul 1 "$AxD_output"

  # RD = (L2 + L3) / 2
  fslmaths "$L2_file" -add "$L3_file" -div 2 "$RD_output"

  echo "Computed Axial Diffusivity and Radial Diffusivity for subject $subj_number."
done

echo "done"
