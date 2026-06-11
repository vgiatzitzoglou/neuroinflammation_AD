#!/bin/bash



N_THREADS=xxxxxxxxxxx/24

# Define the single subject folder you want to process
subject_folder="xxxxxxxxxxx"

# Check if the C004 directory exists
if [ ! -d "$subject_folder" ]; then
    echo "ERROR: Subject folder $subject_folder not found. Exiting."
    exit 1
fi

# --- 1. FIND MAIN DWI FILE & EXTRACT SUBJECT NAME ---
dwi_file=$(find "$subject_folder" -maxdepth 1 -name "xxxxxxxxx???.nii.gz")

if [ ! -f "$dwi_file" ]; then
    echo "DWI file (xxxxxxxxxx???.nii.gz) NOT FOUND in $subject_folder. Exiting."
    exit 1
fi

# Extract the subject name ("xxxxxxxxxx") from the DWI filename
subject_name=$(basename "$dwi_file" .nii.gz)

# --- 2. CONSTRUCT PATHS USING THE EXACT SUBJECT NAME ---
# This ensures we use xxxxxxxxx.bvec/bval and avoid xxxxxxxxx.bvec/bval duplicates
mask="$subject_folder/${subject_name}_brain_mask.nii.gz"
bvec_file="$subject_folder/${subject_name}.bvec"
bval_file="$subject_folder/${subject_name}.bval"
acqparams_file="$subject_folder/acqparams.txt"
index_file="$subject_folder/index.txt"
eddy_output="$subject_folder/${subject_name}_eddy_unwarped.nii.gz"


# --- 3. CHECK FOR COMPLETION ---
if [ -f "$eddy_output" ]
then
    echo "${eddy_output} already exists, skipping ..."
    exit 0
fi

# --- 4. CHECK ALL INPUT FILES EXIST ---
if [ -f "$mask" ] && \
   [ -f "$bvec_file" ] && \
   [ -f "$bval_file" ] && \
   [ -f "$acqparams_file" ] && \
   [ -f "$index_file" ]
then
    
    # --- 5. EXECUTE EDDY with adjusted core count ---
    eddy_cpu diffusion --imain="$dwi_file" \
                       --mask="$mask" \
                       --index="$index_file" \
                       --acqp="$acqparams_file" \
                       --nthr="$N_THREADS" \
                       --bvecs="$bvec_file" \
                       --bvals="$bval_file" \
                       --flm=quadratic \
                       --out="$subject_folder/${subject_name}_eddy_unwarped" \
                       --data_is_shelled \
                       --fwhm=0
                       
    echo "MASK FOUND and Eddy DONE for $subject_folder"
    
else
    echo "--------------------------------------------------------"
    echo "ERROR: Missing files for $subject_folder. Eddy INCOMPLETE."
    # Detailed error check is omitted here for brevity, but recommended
    echo "--------------------------------------------------------"
    exit 1
fi

