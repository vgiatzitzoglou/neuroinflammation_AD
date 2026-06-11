# Neuroimaging Analysis Pipelines

Reusable MATLAB and shell scripts for neuroimaging preprocessing, PET SUVR extraction, DTI processing, VBM-style workflows, and single-subject analysis.

This repository contains pipeline code only. It does not include imaging data, participant tables, spreadsheets, or analysis outputs.

## Repository Structure

- `scripts/01_DTI_FSL_PIPELINE`: DTI conversion, b0 extraction, brain masking, eddy correction, tensor fitting, derived diffusivity maps, RGB FA maps, and JHU ROI extraction helpers.
- `scripts/02_PBR28_PET_SUVR`: PET SUVR processing and WM/GM ROI extraction scripts.
- `scripts/03_AMYLOID_FLUTEMETAMOL`: amyloid PET DICOM-to-SUVR processing scripts.
- `scripts/04_MULTIMODAL_SPM_VBM_PREPROCESSING`: SPM/VBM preprocessing, smoothing, normalisation, and ROI extraction scripts.
- `scripts/05_SSA_SINGLE_SUBJECT_ANALYSIS`: single-subject analysis, SPM model generation, cluster extraction, and T/Z-map export scripts.
- `scripts/06_QC_AND_HELPERS`: QC and cleanup helpers.

## Requirements

Different scripts require different tools:

- MATLAB
- SPM12 on the MATLAB path
- FSL command-line tools
- `dcm2niix`
- Access to your own DICOM/NIfTI data and atlas files

## Path Configuration

The public version uses generic local paths such as:

- `./example_data/...`
- `./atlases/...`
- `./outputs/...`
- `./masks/...`

Before running a pipeline, update the configuration section at the top of the relevant script, or create those folders locally with your own data.

Several shell scripts also accept environment-variable overrides. For example:

```bash
DTI_DATA_ROOT=/path/to/dti_subjects ./scripts/01_DTI_FSL_PIPELINE/05_dti_compute_rd_axd.sh
PET_T1_SOURCE_DIR=/path/to/pet_t1 DTI_SOURCE_DIR=/path/to/dti ./scripts/04_MULTIMODAL_SPM_VBM_PREPROCESSING/group_pet_dti_source_files.sh
```

## Data Policy

Keep this repository code-only. Do not commit raw images, derived images, spreadsheets, subject-level tables, logs, or generated outputs.

The `.gitignore` blocks common neuroimaging and analysis output formats to reduce accidental commits.

