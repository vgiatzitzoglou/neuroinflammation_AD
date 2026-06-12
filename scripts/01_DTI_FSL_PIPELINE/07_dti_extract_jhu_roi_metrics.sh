#!/bin/bash

# JHU ROI extraction for dtifit maps. Run from the folder with subject dirs.
# TODO: check label list if using a different JHU atlas file.
atlas="$FSLDIR/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz"
labels=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44)
output="DTI_ROI_results.csv"

echo "Subject,ROI,FA,MD,AD,RD" > "$output"

for subj in CIF*; do
    [ ! -d "$subj" ] && continue
    id=$(basename "$subj")

    fa="$subj/FA.nii.gz"
    md="$subj/MD.nii.gz"
    ad="$subj/L1.nii.gz"
    rd="$subj/RD.nii.gz"

    # FA to MNI, then invert back so atlas ROIs land in subject space.
    flirt -in "$fa" -ref "$FSLDIR/data/standard/FMRIB58_FA_1mm" -omat "$subj/FA2MNI.mat"
    fnirt --in="$fa" --aff="$subj/FA2MNI.mat" \
          --cout="$subj/FA2MNI_warp" \
          --config=FA_2_FMRIB58_1mm.cnf

    invwarp -w "$subj/FA2MNI_warp" -o "$subj/MNI2FA_warp" -r "$fa"

    for roi in "${labels[@]}"; do
        fslmaths "$atlas" -thr "$roi" -uthr "$roi" -bin "$subj/ROI_${roi}_MNI.nii.gz"

        applywarp -i "$subj/ROI_${roi}_MNI.nii.gz" \
                  -r "$fa" -w "$subj/MNI2FA_warp" \
                  -o "$subj/ROI_${roi}_FA.nii.gz"

        fa_m=$(fslstats "$fa" -k "$subj/ROI_${roi}_FA.nii.gz" -M)
        md_m=$(fslstats "$md" -k "$subj/ROI_${roi}_FA.nii.gz" -M)
        ad_m=$(fslstats "$ad" -k "$subj/ROI_${roi}_FA.nii.gz" -M)
        rd_m=$(fslstats "$rd" -k "$subj/ROI_${roi}_FA.nii.gz" -M)

        echo "$id,$roi,$fa_m,$md_m,$ad_m,$rd_m" >> "$output"
    done
done
