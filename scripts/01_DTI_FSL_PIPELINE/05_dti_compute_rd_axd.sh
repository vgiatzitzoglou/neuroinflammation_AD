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
  l1_file="$subj_dir/${subj_number}_DTI_L1.nii.gz"
  l2_file="$subj_dir/${subj_number}_DTI_L2.nii.gz"
  l3_file="$subj_dir/${subj_number}_DTI_L3.nii.gz"

  # skip if tensor files missing
  if [ ! -f "$l1_file" ] || [ ! -f "$l2_file" ] || [ ! -f "$l3_file" ]; then
    echo "warning: missing L1/L2/L3 for $subj_number"
    continue
  fi

  # outputs
  axd_output="$subj_dir/${subj_number}_DTI_AxD.nii.gz"
  rd_output="$subj_dir/${subj_number}_DTI_RD.nii.gz"

  # AD = L1
  fslmaths "$l1_file" -mul 1 "$axd_output"

  # RD = (L2 + L3) / 2
  fslmaths "$l2_file" -add "$l3_file" -div 2 "$rd_output"

  echo "computed AD/RD for $subj_number"
done

echo "done"
