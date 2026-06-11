#!/bin/bash

# Define the directory where the subject files are stored
input_dir="${DTI_DATA_ROOT:-./example_data/dti_subjects}"

# Loop through each subject in the Example directory (assuming each subject folder has a name like "1234")
for subj_dir in "$input_dir"/*; do
  # Skip non-directories (in case there are any files or non-folder items in the Example directory)
  if [ ! -d "$subj_dir" ]; then
    continue
  fi

  # Extract the subject number from the directory name
  subj_number=$(basename "$subj_dir")

  # Define paths for L1, L2, L3 files (adjust based on your file naming convention)
  L1_file="$subj_dir/${subj_number}_DTI_L1.nii.gz"
  L2_file="$subj_dir/${subj_number}_DTI_L2.nii.gz"
  L3_file="$subj_dir/${subj_number}_DTI_L3.nii.gz"

  # Check if the L1, L2, and L3 files exist
  if [ ! -f "$L1_file" ] || [ ! -f "$L2_file" ] || [ ! -f "$L3_file" ]; then
    echo "Warning: One or more of the required files (L1, L2, L3) for subject $subj_number are missing."
    continue
  fi

  # Define the output paths for Axial Diffusivity (AxD) and Radial Diffusivity (RD)
  AxD_output="$subj_dir/${subj_number}_DTI_AxD.nii.gz"
  RD_output="$subj_dir/${subj_number}_DTI_RD.nii.gz"

  # Compute Axial Diffusivity (AxD) as L1
  fslmaths "$L1_file" -mul 1 "$AxD_output"

  # Compute Radial Diffusivity (RD) as (L2 + L3) / 2
  fslmaths "$L2_file" -add "$L3_file" -div 2 "$RD_output"

  echo "Computed Axial Diffusivity and Radial Diffusivity for subject $subj_number."
done

echo "✅ Done! All subjects processed."
