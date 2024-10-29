#!/bin/bash

###########################################################
#                                                         #
#                    DWI Preprocessing                    #
#                                                         #
###########################################################

# Path to the data folder
data_path=$1
# Path to the output folder
output_path=$2
#Patient code
patient=$3
#Timestamp initial (using for log file name)
timestamp_initial=$4

#dwi data
dwi=${data_path}/${patient}/dwi/*.nii.gz
bvals=${data_path}/${patient}/dwi/*.bval
bvecs=${data_path}/${patient}/dwi/*.bvec
json=${data_path}/${patient}/dwi/*.json

#Readout Time and phase encoding direction
if [ $(jq .TotalReadoutTime $json) == "null" ]; then
    rd_time=$(jq .EstimatedTotalReadoutTime $json)
else
    rd_time=$(jq .TotalReadoutTime $json)
fi

if [ $(jq .PhaseEncodingDirection $json | sed 's/"//g') == "null" ]; then
    pe_direction=$(jq .PhaseEncodingAxis $json | sed 's/"//g')
else
    pe_direction=$(jq .PhaseEncodingDirection $json | sed 's/"//g')
fi


#Creating participant preproc folder
mkdir -p ${output_path}/Dwiprep/${patient}
cd ${output_path}/Dwiprep/${patient}
mkdir -p qc_data

timepoint=$(date +"%H:%M")
echo "$timepoint    **Starting Preprocessing...**" >> ${output_path}/log/Dwipreproc_${timestamp_initial}.txt

#Denoising dwi data
dwidenoise $dwi dwi_den.nii.gz

#Preproc dwi data
#Check if fieldmapping data has been acquired to perform topup correction
if [  -d "${data_path}/${patient}/fmap" ]; then

    timepoint=$(date +"%H:%M")
    echo "$timepoint    **Using topup for fieldmapping correction...**" >> ${output_path}/log/Dwipreproc_${timestamp_initial}.txt

    dwi_ap=${data_path}/${patient}/fmap/*SEfmapDWI_dir-AP_epi.nii.gz
    dwi_pa=${data_path}/${patient}/fmap/*SEfmapDWI_dir-PA_epi.nii.gz
    fslmerge -t ${data_path}/${patient}/fmap/dwi_topup ${dwi_ap} ${dwi_pa}
    topimg=${data_path}/${patient}/fmap/dwi_topup.nii.gz

    dwifslpreproc -rpe_pair -pe_dir $pe_direction -readout_time $rd_time -fslgrad $bvecs $bvals \
    -eddyqc_all qc_data -eddy_options ' --ol_nstd=4 --repol --cnr_maps ' \
    -export_grad_fsl -nthreads 4 rotated.bvec rotated.bval dwi_den.nii.gz dwi_clean.nii.gz \
    -se_epi $topimg -align_seepi
else
    timepoint=$(date +"%H:%M")
    echo "$timepoint    **Fieldmapping folder not found, not performing topup correction...**" >> ${output_path}/log/Dwipreproc_${timestamp_initial}.txt
    dwifslpreproc -rpe_none -pe_dir $pe_direction -readout_time $rd_time -fslgrad $bvecs $bvals \
        -eddyqc_all qc_data -nthreads 4 -eddy_options ' --ol_nstd=4 --repol --cnr_maps ' \
        -export_grad_fsl rotated.bvec rotated.bval dwi_den.nii.gz dwi_clean.nii.gz
fi

#Generating bzero
dwiextract -bzero -fslgrad rotated.bvec rotated.bval dwi_clean.nii.gz dwi_bzero_4D.nii.gz
fslmaths dwi_bzero_4D.nii.gz -Tmean dwi_bzero.nii.gz

#Generating dwi mask
dwi2mask dwi_clean.nii.gz dwi_mask.nii.gz -fslgrad rotated.bvec rotated.bval

timepoint=$(date +"%H:%M")
echo "$timepoint    **Tensor fitting...**" >> ${output_path}/log/Dwipreproc_${timestamp_initial}.txt
#Tensor fitting
dwi2tensor -force -mask dwi_mask.nii.gz dwi_clean.nii.gz -fslgrad rotated.bvec rotated.bval dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -vector dwi_directions.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -fa dwi_FA.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -adc dwi_MD.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -ad dwi_AD.nii.gz dwi_tensor.nii.gz
tensor2metric -force -mask dwi_mask.nii.gz -rd dwi_RD.nii.gz dwi_tensor.nii.gz