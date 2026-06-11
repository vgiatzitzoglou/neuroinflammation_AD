# Script Index

This folder is organised by pipeline purpose. Files were moved, not deleted. Older versions and exact duplicates are preserved under `99_ARCHIVE_REDUNDANT_OR_OLD_VERSIONS`.

## 01_DTI_FSL_PIPELINE

DTI shell/FSL processing scripts:

- `01_dti_convert_dicom_to_nifti.sh`: DICOM to NIfTI conversion with `dcm2niix`.
- `02_dti_extract_b0_and_brainmask.sh`: b0 extraction and BET brainmask.
- `03_dti_eddy_gpu_batch.sh`: GPU eddy correction batch.
- `03b_dti_eddy_single_subject_template.sh`: single-subject eddy template with placeholder paths.
- `04_dti_fit_tensor.sh`: tensor fitting with `dtifit`.
- `05_dti_compute_rd_axd.sh`: compute axial and radial diffusivity from eigenvalue images.
- `06_dti_create_rgb_fa_map.sh`: RGB FA map creation.
- `07_dti_extract_jhu_roi_metrics.sh`: JHU ROI extraction for FA/MD/AD/RD.
- `fsl_acqparams.txt` and `fsl_index.txt`: FSL eddy parameter files.

Roberto's original DTI folder is retained as reference in `99_ARCHIVE_REDUNDANT_OR_OLD_VERSIONS/roberto_original_dti_reference`.

## 02_PBR28_PET_SUVR

PBR28/neuroinflammation PET SUVR extraction and ROI scripts:

- `pbr28_extract_suvr_wm_gm_multiformat.m`: canonical PBR28 WM/GM SUVR extraction script.
- `run_pet_processing_v3.m`: PET SUVR SPM processing script that writes `_2` output files.
- `run_pet_suvr_extraction_v2.m`: matching JHU WM extraction script for `_2` outputs; includes atlas reslicing fix.
- `pbr28_extract_wm_suvr_labels.sh`: shell label-wise WM SUVR extraction helper.

Archived old versions:

- `run_pet_processing_old_no_suffix2.m`
- `run_pet_suvr_extraction_old_no_reslice.m`
- `pbr28_suvr_extraction_old_wrong_jhu_path.m`

## 03_AMYLOID_FLUTEMETAMOL

Amyloid/flutemetamol PET scripts:

- `amyloid_flutemetamol_full_dicom_to_suvr_pipeline.m`
- `calculate_amyloid_suvr.m`

## 04_MULTIMODAL_SPM_VBM_PREPROCESSING

SPM/VBM/multimodal preprocessing scripts:

- `run_processing_batch.m`: multimodal T1/PET/DTI processing batch.
- `run_roi_extraction.m`: multimodal ROI extraction.
- `run_smoothing.m`: smoothing warped multimodal outputs.
- `run_acpc_realignment.m`: AC-PC / MNI realignment helper.
- `run_dti_processing_v2.m`: DTI coregistration/normalisation/smoothing helper.
- `run_vbm_segmentation.m`: VBM segmentation.
- `run_vbm_smoothing.m`: smooth VBM `mwc1`/`mwc2` outputs.
- `run_vbm_wm_jhu_extraction.m`: newer JHU WM extraction version with atlas reslicing.
- `group_pet_dti_source_files.sh` and `organize_vbm_asl_processing_files.sh`: source organisation helpers.

## 05_SSA_SINGLE_SUBJECT_ANALYSIS

Single-subject analysis and SPM cluster scripts:

- `masterSSA.m`: main SSA pipeline for AD/MCI/HC specificity check.
- `ssa_batch.m`: core SSA function.
- `run_ssa_all.m`, `run_ssa_batch.m`, `run_ssa_missing.m`: SSA wrappers.
- `batch_create_spm_models.m`: create SPM single-subject models.
- `create_frequency_map.m`: disease frequency map.
- `export_t_z_maps.m`: export T and Z maps.
- `ssa_master_specificity_remaining_controls.m`: old `master.m` renamed descriptively.
- `ssa_master_ad_mci_full_pipeline_fixed_scaling.m`: old `runADleft.m` renamed descriptively.

## 06_QC_AND_HELPERS

QC and cleanup scripts:

- `cleanup.m`
- `check_origin.m`
- `check_realignment.m`

## 90_SCRIPT_OUTPUTS_AND_NOTES

Non-script outputs and notes that were previously mixed into the script folder:

- old CSV outputs
- SPSS/SPM output files
- step-by-step Word notes
- subject-list CSVs

## Naming Note

For MATLAB files that define a function, I mostly preserved the MATLAB function name or renamed the file to match the function. This keeps the files more likely to run in MATLAB. Descriptive renames were mainly applied to shell scripts and MATLAB scripts without a primary function.
