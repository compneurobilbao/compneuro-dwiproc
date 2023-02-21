#!/bin/bash

###########################################################
#                                                         #
#                    DWI Preprocessing                    #
#                                                         #
###########################################################

#Patient code
patient=$1 
#Timestamp initial (using for log file name)
timestamp_initial=$2

#dwi data
dwi=/project/data/${patient}/dwi/*.nii.gz
bvals=/project/data/${patient}/dwi/*.bval
bvecs=/project/data/${patient}/dwi/*.bvec
json=/project/data/${patient}/dwi/*.json

#Readout Time and phase encoding direction
rd_time=$(grep "TotalReadoutTime" $json | awk '{ print $2 }' | sed 's/,//g')
pe_direction=$(grep "PhaseEncodingDirection" $json | awk '{ print $2 }' | sed 's/,//g' | sed 's/"//g')

#Creating participant preproc folder
mkdir -p /project/Preproc/Dwiprep/${patient}
cd /project/Preproc/Dwiprep/${patient}
mkdir -p qc_data

timepoint=$(date +"%H:%M")
echo "$timepoint    **Starting Preprocessing...**" >> /app/log/Dwipreproc_${timestamp_initial}.txt

#Denoising dwi data
dwidenoise $dwi dwi_den.nii.gz

#Preproc dwi data
#Check if fieldmapping data has been acquired to perform topup correction
if [  -d "/project/data/${patient}/fmap" ]; then

    timepoint=$(date +"%H:%M")
    echo "$timepoint    **Using topup for fieldmapping correction...**" >> /app/log/Dwipreproc_${timestamp_initial}.txt

    dwi_ap=/project/data/${patient}/fmap/*SEfmapDWI_dir-AP_epi.nii.gz
    dwi_pa=/project/data/${patient}/fmap/*SEfmapDWI_dir-PA_epi.nii.gz
    fslmerge -t /project/data/${patient}/fmap/dwi_topup ${dwi_ap} ${dwi_pa}
    topimg=/project/data/${patient}/fmap/dwi_topup.nii.gz

    dwipreproc -rpe_pair -pe_dir $pe_direction -readout_time $rd_time -fslgrad $bvecs $bvals \
    -eddyqc_all qc_data -eddy_options ' --ol_nstd=4 --repol --cnr_maps ' \
    -export_grad_fsl rotated.bvec rotated.bval dwi_den.nii.gz dwi_clean.nii.gz \
    -se_epi $topimg -align_seepi
else
    timepoint=$(date +"%H:%M")
    echo "$timepoint    **Fieldmapping folder not found, not performing topup correction...**" >> /app/log/Dwipreproc_${timestamp_initial}.txt
    dwipreproc -rpe_none -pe_dir $pe_direction -readout_time $rd_time -fslgrad $bvecs $bvals \
        -eddyqc_all qc_data -eddy_options ' --ol_nstd=4 --repol --cnr_maps ' \
        -export_grad_fsl rotated.bvec rotated.bval dwi_den.nii.gz dwi_clean.nii.gz
fi

#Generating bzero
dwiextract -bzero -fslgrad rotated.bvec rotated.bval dwi_clean.nii.gz dwi_bzero_4D.nii.gz
fslmaths dwi_bzero_4D.nii.gz -Tmean dwi_bzero.nii.gz

#Generating dwi mask
dwi2mask dwi_clean.nii.gz dwi_mask.nii.gz -fslgrad rotated.bvec rotated.bval

timepoint=$(date +"%H:%M")
echo "$timepoint    **Tensor fitting...**" >> /app/log/Dwipreproc_${timestamp_initial}.txt
#Tensor fitting
dwi2tensor -force -mask dwi_mask.nii.gz dwi_clean.nii.gz -fslgrad rotated.bvec rotated.bval dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -vector dwi_directions.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -fa dwi_FA.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -adc dwi_MD.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -ad dwi_AD.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -rd dwi_RD.nii.gz dwi_tensor.nii.gz

#Generate quality checks
mv dwipreproc-tmp-* dwiprep_files
eddy_quad dwiprep_files/dwi_post_eddy -idx dwiprep_files/eddy_indices.txt -par dwiprep_files/eddy_config.txt -m dwi_mask.nii.gz -b dwiprep_files/bvals