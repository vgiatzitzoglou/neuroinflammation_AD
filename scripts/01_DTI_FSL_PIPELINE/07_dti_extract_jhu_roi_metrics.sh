#!/bin/bash

ATLAS="$FSLDIR/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz"
LABELS=(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44)  # es. ROI: https://neurovault.org/images/1401/
OUTPUT="DTI_ROI_results.csv"

echo "Subject,ROI,FA,MD,AD,RD" > $OUTPUT

for SUBJ in CIF*; do
    [ ! -d "$SUBJ" ] && continue
    ID=$(basename $SUBJ)

    FA="$SUBJ/FA.nii.gz"
    MD="$SUBJ/MD.nii.gz"
    AD="$SUBJ/L1.nii.gz"
    RD="$SUBJ/RD.nii.gz"

    # FA to MNI Registration and reversed warp
    flirt -in "$FA" -ref $FSLDIR/data/standard/FMRIB58_FA_1mm -omat "$SUBJ/FA2MNI.mat"
    fnirt --in="$FA" --aff="$SUBJ/FA2MNI.mat" \
          --cout="$SUBJ/FA2MNI_warp" \
          --config=FA_2_FMRIB58_1mm.cnf

    # Invert warp (MNI to DWI)
    invwarp -w "$SUBJ/FA2MNI_warp" -o "$SUBJ/MNI2FA_warp" -r "$FA"

    for ROI in "${LABELS[@]}"; do
        # binary mask of the chosen ROI
        fslmaths $ATLAS -thr $ROI -uthr $ROI -bin "$SUBJ/ROI_${ROI}_MNI.nii.gz"

        #ROI into FA space of the subject
        applywarp -i "$SUBJ/ROI_${ROI}_MNI.nii.gz" \
                  -r "$FA" -w "$SUBJ/MNI2FA_warp" \
                  -o "$SUBJ/ROI_${ROI}_FA.nii.gz"

        #Extract metrics
        FA_M=$(fslstats $FA -k "$SUBJ/ROI_${ROI}_FA.nii.gz" -M)
        MD_M=$(fslstats $MD -k "$SUBJ/ROI_${ROI}_FA.nii.gz" -M)
        AD_M=$(fslstats $AD -k "$SUBJ/ROI_${ROI}_FA.nii.gz" -M)
        RD_M=$(fslstats $RD -k "$SUBJ/ROI_${ROI}_FA.nii.gz" -M)

        echo "$ID,$ROI,$FA_M,$MD_M,$AD_M,$RD_M" >> $OUTPUT
    done
done
