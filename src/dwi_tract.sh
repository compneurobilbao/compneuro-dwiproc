#!/bin/bash

###########################################################
#                                                         #
#                    DWI Tractography                     #
#                                                         #
###########################################################

#Participant code
participant=$1 
#Timestamp initial (using for log file name)
timestamp_initial=$2
#Partition for SC matrix calculation (placed in brain_templates)
partition=$3

anat=/project/Preproc/BET/${participant}_T1w_brain.nii.gz 
cd /project/Preproc/Dwiprep/${participant}

#Atlas Registration
timepoint=$(date +"%H:%M")
echo "$timepoint    **Registering partition to subject space...**" >> /project/log/Dwipreproc_${timestamp_initial}.txt

mkdir -p dwireg

epi_reg --epi=dwi_bzero.nii.gz --t1=${anat} --t1brain=${anat} --out=dwireg/epi2anat
convert_xfm -inverse -omat dwireg/anat2epi.mat dwireg/epi2anat.mat
flirt -in ${anat} -ref dwi_bzero.nii.gz -init dwireg/anat2epi.mat -applyxfm -out anat_dwispace.nii.gz

antsRegistrationSyN.sh -d 3 \
	-f anat_dwispace.nii.gz \
	-m /app/brain_templates/MNI152_T1_2mm_brain.nii.gz \
	-o dwireg/standard2dwi

antsApplyTransforms -d 3 -r anat_dwispace.nii.gz \
	-i /app/brain_templates/${partition}.nii.gz -e 0 \
	-t dwireg/standard2dwi1Warp.nii.gz \
	-t dwireg/standard2dwi0GenericAffine.mat \
	-o atlas_subSpace.nii.gz -n NearestNeighbor -v 1

#Generating ACT files
timepoint=$(date +"%H:%M")
echo "$timepoint    **Generating ACT files...**" 

5ttgen fsl anat_dwispace.nii.gz act.nii.gz -nocrop -premasked -force
5tt2gmwmi act.nii.gz GMWMI.nii.gz -force

#IFOD2 probabilistic tractography
timepoint=$(date +"%H:%M")
echo "$timepoint    **Computing probabilistic tractography (iFOD2)...**" >> /project/log/Dwipreproc_${timestamp_initial}.txt

#Generating response for spherical deconvolution
dwi2response tax dwi_clean.nii.gz dwi_response.txt -fslgrad rotated.bvec rotated.bval -mask dwi_mask.nii.gz -force

#Estimating fibre orientations
dwi2fod csd dwi_clean.nii.gz dwi_response.txt dwi_fod.nii.gz -fslgrad rotated.bvec rotated.bval -mask dwi_mask.nii.gz -force

#Generate fiber tracking 
tckgen -backtrack -seed_gmwmi GMWMI.nii.gz -angle 45 -act act.nii.gz -mask dwi_mask.nii.gz \
    -maxlength 200 -select 3000000 -algorithm iFOD2 dwi_fod.nii.gz -fslgrad rotated.bvec rotated.bval \
    streamlines_iFOD2.tck -force 
tcksift2  streamlines_iFOD2.tck dwi_fod.nii.gz sift_weights_iFOD2.txt -force 
tck2connectome -zero_diagonal -symmetric -assignment_radial_search 5 \
    -tck_weights_in sift_weights_iFOD2.txt -force streamlines_iFOD2.tck atlas_subSpace.nii.gz probabilistic_connectome.csv

#FACT deterministic tractography
timepoint=$(date +"%H:%M")
echo "$timepoint    **Computing deterministic tractography (FACT)...**" >> /project/log/Dwipreproc_${timestamp_initial}.txt

tckgen -seed_gmwmi GMWMI.nii.gz -angle 45 -act act.nii.gz -mask dwi_mask.nii.gz \
    -maxlength 200 -select 3000000 -algorithm FACT -downsample 5 -force \
    dwi_directions.nii.gz streamlines_FACT.tck
tcksift2 streamlines_FACT.tck dwi_fod.nii.gz sift_weights_FACT.txt -force
tck2connectome -zero_diagonal -symmetric -assignment_radial_search 5 \
    -tck_weights_in sift_weights_FACT.txt -force streamlines_FACT.tck atlas_subSpace.nii.gz deterministic_connectome.csv
