#!/bin/bash

###########################################################
#                                                         #
#		      dwi Preprocessing Bash launcher             #
#                                                         #
###########################################################


timestamp_initial=$(date +"%H:%M")
mkdir -p /project/Preproc/log
touch /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt
parcellation=$1
parcellation_name=$(basename $parcellation .nii.gz)
while read line
do
    participant=$( echo ${line} | awk '{ print $1 }')

	if [  -f "/project/Preproc/Dwiprep/${participant}/${parcellation_name}_det.csv" ]; then
        echo "$participant already processed" >> /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt
        echo "$participant" >> /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt
        echo "*********************" >> /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt

        if [ -f "/project/Preproc/Dwiprep/${participant}/dwi_clean.nii.gz" ]; then
            echo "Dwi data already cleaned" >> /project/Preproc/log/Dwipreproc_${timestamp_initial}.txt
        else
            source /app/src/dwi_preproc.sh /project/data /project/Preproc $participant $timestamp_initial
        fi
        source /app/src/dwi_tract.sh /app /project/Preproc $participant $timestamp_initial $parcellation_name
   fi
	
done < <(tail -n +2 /project/data/participants.tsv)






