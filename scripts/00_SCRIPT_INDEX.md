# rough script index

This is just my map of what is in the scripts folder. Some of these are cleaner than
others. Check the paths at the top of the script before running anything.

## shared bits

- `+pipeline/default_subjects.m`: subject ID list reused by several MATLAB scripts.

## 01_DTI_FSL_PIPELINE

DTI/FSL scripts:

- `01_dti_convert_dicom_to_nifti.sh`: DICOM to NIfTI conversion with `dcm2niix`.
- `02_dti_extract_b0_and_brainmask.sh`: b0 extraction and BET brainmask.
- `03_dti_eddy_gpu_batch.sh`: GPU eddy correction batch.
- `03b_dti_eddy_single_subject_template.sh`: single-subject eddy script, edit the subject path before using.
- `04_dti_fit_tensor.sh`: tensor fitting with `dtifit`.
- `05_dti_compute_rd_axd.sh`: compute axial and radial diffusivity from eigenvalue images.
- `06_dti_create_rgb_fa_map.sh`: RGB FA map creation.
- `07_dti_extract_jhu_roi_metrics.sh`: JHU ROI extraction for FA/MD/AD/RD.
- `fsl_acqparams.txt` and `fsl_index.txt`: FSL eddy parameter files.

## 02_PBR28_PET_SUVR

PBR28/neuroinflammation PET scripts:

- `pbr28_extract_suvr_wm_gm_multiformat.m`: main WM/GM SUVR extraction script.
- `run_pet_processing_v3.m`: PET SUVR SPM processing script that writes `_2` output files.
- `run_pet_suvr_extraction_v2.m`: JHU WM extraction for `_2` outputs; includes the atlas reslicing fix.
- `pbr28_extract_wm_suvr_labels.sh`: shell label-wise WM SUVR extraction helper.

## 03_AMYLOID_FLUTEMETAMOL

Amyloid/flutemetamol PET scripts:

- `amyloid_flutemetamol_full_dicom_to_suvr_pipeline.m`
- `calculate_amyloid_suvr.m`

## 04_MULTIMODAL_SPM_VBM_PREPROCESSING

SPM/VBM/multimodal scripts:

- `run_processing_batch.m`: multimodal T1/PET/DTI processing batch.
- `run_roi_extraction.m`: multimodal ROI extraction.
- `run_smoothing.m`: smoothing warped multimodal outputs.
- `run_acpc_realignment.m`: AC-PC / MNI realignment.
- `run_dti_processing_v2.m`: DTI coregistration/normalisation/smoothing.
- `run_vbm_segmentation.m`: VBM segmentation.
- `run_vbm_smoothing.m`: smooth VBM `mwc1`/`mwc2` outputs.
- `run_vbm_wm_jhu_extraction.m`: newer JHU WM extraction version with atlas reslicing.
- `group_pet_dti_source_files.sh` and `organize_vbm_asl_processing_files.sh`: source organisation helpers.

## 05_SSA_SINGLE_SUBJECT_ANALYSIS

Single-subject analysis / SPM cluster scripts:

- `run_ssa_pipeline.m`: main SSA run script. This is the one to start with.
- `ssa_batch.m`: cluster extraction / PET summary function for existing `SPM.mat` files.
- `run_ssa_all.m`: wrapper for running `ssa_batch` from a prepared subject table.
- `run_ssa_missing.m`: looks for `SPM.mat` files that do not yet have SSA outputs.
- `create_frequency_map.m`: disease frequency map.
- `export_t_z_maps.m`: export T and Z maps.
- `+ssa/`: helper functions for the SSA scripts. I split these out because the old SSA files repeated the same code too much.

## 06_QC_AND_HELPERS

QC and cleanup scripts:

- `cleanup.m`
- `check_origin.m`
- `check_realignment.m`

## naming note

For MATLAB functions, I tried to keep the file name matching the function name so MATLAB
does not complain. Some script names are still descriptive rather than pretty.
