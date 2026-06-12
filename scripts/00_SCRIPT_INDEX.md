# rough script index

This is the trimmed version. I kept the scripts that map to the dissertation methods:
PBR28 SUVR, amyloid SUVR, DTI metrics, and SSA. Old VBM/multimodal/QC helpers are gone.

## shared bits

- `+pipeline/default_subjects.m`: subject ID list reused by the MATLAB scripts.

## 01_DTI_FSL_PIPELINE

Rough order if rerunning DTI:

1. `01_dti_convert_dicom_to_nifti.sh`
2. `02_dti_extract_b0_and_brainmask.sh`
3. `03_dti_eddy_gpu_batch.sh`
4. `04_dti_fit_tensor.sh`
5. `05_dti_compute_rd_axd.sh`
6. `07_dti_extract_jhu_roi_metrics.sh`

- `01_dti_convert_dicom_to_nifti.sh`: DICOM to NIfTI with `dcm2niix`.
- `02_dti_extract_b0_and_brainmask.sh`: b0 extraction and BET mask.
- `03_dti_eddy_gpu_batch.sh`: eddy correction batch.
- `04_dti_fit_tensor.sh`: `dtifit` for FA/MD/eigenvalue maps.
- `05_dti_compute_rd_axd.sh`: AD/RD from eigenvalues.
- `07_dti_extract_jhu_roi_metrics.sh`: JHU ROI values for FA/MD/AD/RD.
- `fsl_acqparams.txt`, `fsl_index.txt`: eddy parameter files.

## 02_PBR28_PET_SUVR

Rough order:

1. `run_pet_processing_v3.m`
2. `pbr28_extract_suvr_wm_gm_multiformat.m`

- `run_pet_processing_v3.m`: makes the PBR28 SUVR image. Assumes SPM segmentation/deformation files already exist.
- `pbr28_extract_suvr_wm_gm_multiformat.m`: extracts WM/GM ROI values and grouped tract/lobe tables.

## 03_AMYLOID_FLUTEMETAMOL

- `amyloid_flutemetamol_full_dicom_to_suvr_pipeline.m`: amyloid SUVR script. This is path-dependent, so check it carefully.

## 05_SSA_SINGLE_SUBJECT_ANALYSIS

Rough order:

1. `run_ssa_pipeline.m`
2. `run_ssa_missing.m` only if something half-ran
3. `create_frequency_map.m` / `export_t_z_maps.m` after SSA outputs exist

- `run_ssa_pipeline.m`: main SSA run script.
- `ssa_batch.m`: cluster/PET summary wrapper for existing `SPM.mat` files.
- `run_ssa_all.m`: use a prepared subject table.
- `run_ssa_missing.m`: rerun subjects missing SSA outputs.
- `create_frequency_map.m`: makes group frequency maps from cluster files.
- `export_t_z_maps.m`: exports T/Z maps from SSA results.
- `+ssa/`: small functions used by the SSA scripts.

## note

This is still working research code, not a general package. Some names are historical
because MATLAB can be annoying when file and function names stop matching.
