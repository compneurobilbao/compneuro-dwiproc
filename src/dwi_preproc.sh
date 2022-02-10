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
#anat data
anat=/project/data/${patient}/anat/*.nii.gz
#dwi data
dwi=/project/data/${patient}/dwi/*.nii.gz
bvals=/project/data/${patient}/dwi/*.bval
bvecs=/project/data/${patient}/dwi/*.bvec
json=/project/data/${patient}/dwi/*.json

#Readout Time and phase encoding direction
rd_time=$(grep "TotalReadoutTime" $json | awk '{ print $2 }' | sed 's/,//g')
pe_direction=$(grep "PhaseEncodingDirection" $json | awk '{ print $2 }' | sed 's/,//g' | sed 's/"//g')

if [[ $pe_direction = "j" ]]
then
    direction="AP"
else
    direction="PA"
fi

#Creating participant preproc folder
mkdir -p /project/Preproc/Dwiprep/${patient}
cd /project/Preproc/Dwiprep/${patient}
mkdir -p qc_data

#Denoising dwi data
dwidenoise $dwi dwi_den.nii.gz
dwipreproc -rpe_none -pe_dir $direction -readout_time $rd_time -fslgrad $bvecs $bvals \
    -eddyqc_all qc_data -eddy_options ' --ol_nstd=4 --repol --cnr_maps ' \
    -nthreads 4 -export_grad_fsl rotated.bvec rotated.bval dwi_den.nii.gz dwi_clean.nii.gz

#Generating dwi mask
dwi2mask dwi_clean.nii.gz dwi_mask.nii.gz -fslgrad rotated.bvec rotated.bval

#Tensor fitting
dtifit --data=dwi_clean.nii.gz --out=dwi --mask=dwi_mask.nii.gz --bvecs=rotated.bvec --bvals=rotated.bval

#Generate quality checks
mv dwipreproc-tmp-* dwiprep_files
eddy_quad dwiprep_files/dwi_post_eddy -idx dwiprep_files/eddy_indices.txt -par dwiprep_files/eddy_config.txt -m dwi_mask.nii.gz -b dwiprep_files/bvals