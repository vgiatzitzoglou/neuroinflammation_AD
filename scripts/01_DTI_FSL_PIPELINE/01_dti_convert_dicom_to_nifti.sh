#!/bin/bash

for cif_folder in C*; do
   
    if [ ! -d "$cif_folder" ]; then
        continue 
    fi

    
    cif_name=$(basename "$cif_folder")

  
    subfolder_pattern="$cif_folder"/*Mv1/scans/*_DTI_64dir_2x2x2
    
    for subfolder in $subfolder_pattern; do
        
        dicom_folder="$subfolder/DICOM/"

        if [ -d "$dicom_folder" ]; then
            echo "found DICOM folder: $dicom_folder"
            
           
            dcm2niix -f "$cif_name" -o "$cif_folder" -z y "$dicom_folder"

            echo "DICOM folder converted: $dicom_folder"
        else
            echo "DICOM folder not found at expected path: $dicom_folder"
        fi
    done
done