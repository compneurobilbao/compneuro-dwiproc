#!/bin/bash

###########################################################
#                                                         #
#		      dwi Preprocessing Bash launcher             #
#                                                         #
###########################################################


timestamp_initial=$(date +"%H:%M")
mkdir -p /project/log
touch /project/log/Dwipreproc_${timestamp_initial}.txt
partition=$1
partition_name=$(basename $partition .nii.gz)
while read line
do
    participant=$( echo ${line} | awk '{ print $1 }')

	if [  -f "/project/Preproc/Dwiprep/${participant}/${partition_name}_det.csv" ]; then
        echo "$participant already processed" >> /project/log/Dwipreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> /project/log/Dwipreproc_${timestamp_initial}.txt
        echo "$participant" >> /project/log/Dwipreproc_${timestamp_initial}.txt
        echo "*********************" >> /project/log/Dwipreproc_${timestamp_initial}.txt

        if [ -f "/project/Preproc/Dwiprep/${participant}/dwi_clean.nii.gz" ]; then
            echo "Dwi data already cleaned" >> /project/log/Dwipreproc_${timestamp_initial}.txt
        else
            source /app/src/dwi_preproc.sh $participant $timestamp_initial
        fi
        source /app/src/dwi_tract.sh $participant $timestamp_initial $partition_name
   fi
	
done < <(tail -n +2 /project/data/participants.tsv)






