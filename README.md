# neuroinflammation scripts

These are the scripts I kept together for the neuroinflammation / PET / DTI analyses.
It is mostly MATLAB and shell code for preprocessing, SUVR extraction, VBM-type steps,
DTI metrics, QC checks, and single-subject SPM analyses.

This is code only. I have not included imaging data, spreadsheets, subject tables, logs,
or result files.

## folder notes

- `scripts/01_DTI_FSL_PIPELINE`: FSL/DTI steps, from conversion through FA/MD/AD/RD and JHU values.
- `scripts/02_PBR28_PET_SUVR`: PBR28 PET SUVR and WM/GM extraction scripts.
- `scripts/03_AMYLOID_FLUTEMETAMOL`: amyloid PET DICOM-to-SUVR processing scripts.
- `scripts/04_MULTIMODAL_SPM_VBM_PREPROCESSING`: SPM/VBM and multimodal preprocessing scripts.
- `scripts/05_SSA_SINGLE_SUBJECT_ANALYSIS`: single-subject analysis scripts.
- `scripts/06_QC_AND_HELPERS`: small QC/checking scripts.

## things needed

Depends on which script is being run, but usually:

- MATLAB
- SPM12 on the MATLAB path
- FSL command-line tools
- `dcm2niix`
- local DICOM/NIfTI data and atlas files

## paths

The paths here are deliberately generic, e.g.

- `./example_data/...`
- `./atlases/...`
- `./outputs/...`
- `./masks/...`

Before running anything, check the path block at the top of the script. Some scripts also
accept environment variables so I do not have to edit the file every time. For example:

```bash
DTI_DATA_ROOT=/path/to/dti_subjects ./scripts/01_DTI_FSL_PIPELINE/05_dti_compute_rd_axd.sh
PET_T1_SOURCE_DIR=/path/to/pet_t1 DTI_SOURCE_DIR=/path/to/dti ./scripts/04_MULTIMODAL_SPM_VBM_PREPROCESSING/group_pet_dti_source_files.sh
```

## note to self

Keep this repo code-only. Do not commit raw scans, processed images, spreadsheets,
subject-level tables, logs, or generated outputs.

The `.gitignore` blocks the common neuroimaging/data outputs, but still check before pushing.
