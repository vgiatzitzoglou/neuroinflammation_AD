#!/bin/bash

N_THREADS="${N_THREADS:-24}"

# Usage:
#   DTI_SUBJECT_DIR=/path/to/subject ./03b_dti_eddy_single_subject_template.sh
# or:
#   ./03b_dti_eddy_single_subject_template.sh /path/to/subject
subject_folder="${1:-${DTI_SUBJECT_DIR:-}}"

# subject folder, either as argument or env var
if [ -z "$subject_folder" ] || [ ! -d "$subject_folder" ]; then
    echo "ERROR: Provide a valid subject folder via argument 1 or DTI_SUBJECT_DIR."
    exit 1
fi

# find main DWI file and subject name
dwi_file=$(find "$subject_folder" -maxdepth 1 -name "*.nii.gz" ! -name "*brain*" ! -name "*eddy*" -print -quit)

if [ ! -f "$dwi_file" ]; then
    echo "DWI file not found in $subject_folder. Exiting."
    exit 1
fi

# subject name from the DWI filename
subject_name=$(basename "$dwi_file" .nii.gz)

# use exact subject name so bvec/bval names match
mask="$subject_folder/${subject_name}_brain_mask.nii.gz"
bvec_file="$subject_folder/${subject_name}.bvec"
bval_file="$subject_folder/${subject_name}.bval"
acqparams_file="$subject_folder/acqparams.txt"
index_file="$subject_folder/index.txt"
eddy_output="$subject_folder/${subject_name}_eddy_unwarped.nii.gz"


# skip if already done
if [ -f "$eddy_output" ]
then
    echo "${eddy_output} already exists, skipping ..."
    exit 0
fi

# check all input files exist
if [ -f "$mask" ] && \
   [ -f "$bvec_file" ] && \
   [ -f "$bval_file" ] && \
   [ -f "$acqparams_file" ] && \
   [ -f "$index_file" ]
then
    
    # run eddy with adjusted core count
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
                       
    echo "eddy done for $subject_folder"
    
else
    echo "--------------------------------------------------------"
    echo "ERROR: Missing files for $subject_folder. Eddy not run."
    # TODO: add detailed missing-file printout if this becomes annoying.
    echo "--------------------------------------------------------"
    exit 1
fi
