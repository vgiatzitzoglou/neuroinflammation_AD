# neuroinflammation scripts

Scripts I kept for the neuroinflammation / PET / DTI dissertation work.
This is not every helper I ever made. I removed the VBM/multimodal/QC extras
because they were making the repo look much bigger than the actual dissertation analysis.

This repo is code only. No scans, spreadsheets, participant identifiers,
subject tables, logs, or result files.

## folders

- `scripts/01_DTI_FSL_PIPELINE`: DTI conversion, b0/brain mask, eddy, tensor fitting, AD/RD, and JHU ROI values.
- `scripts/02_PBR28_PET_SUVR`: PBR28 PET SUVR processing and WM/GM ROI table extraction.
- `scripts/03_AMYLOID_FLUTEMETAMOL`: flutemetamol amyloid SUVR processing script.
- `scripts/05_SSA_SINGLE_SUBJECT_ANALYSIS`: single-subject analysis against a control reference set.

## needed

Depends on the script, but usually:

- MATLAB
- SPM12 on the MATLAB path
- FSL command-line tools
- `dcm2niix`
- local DICOM/NIfTI data and atlas files

## paths

The paths are generic on purpose:

- `./example_data/...`
- `./atlases/...`
- `./outputs/...`
- `./masks/...`

Check the path block at the top of a script before running it. A few shell scripts
also accept environment variables, e.g.

```bash
DTI_DATA_ROOT=/path/to/dti_subjects ./scripts/01_DTI_FSL_PIPELINE/05_dti_compute_rd_axd.sh
```

Note to self: the PBR28 script expects SPM tissue/deformation outputs to already
exist next to the T1 files. I did not keep every old setup/QC helper here.

Subject identifiers are supplied at runtime from local folder names or input
tables. They are not stored in this repository.

## do not commit

Keep this repo code-only. Do not commit raw scans, processed images, spreadsheets,
subject-level tables, logs, or generated outputs.
