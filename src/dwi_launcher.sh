#!/bin/bash

###########################################################
#                                                         #
#		      dwi Preprocessing Bash launcher             #
#                                                         #
###########################################################


timestamp_initial=$(date +"%H:%M")
touch /app/log/Dwipreproc_${timestamp_initial}.txt

while read line
do
    participant=$( echo ${line} | awk '{ print $1 }')

	if [  -f "/project/Preproc/Dwiprep/${participant}_preprocessed.nii.gz" ]; then
        echo "$participant already processed" >> /app/log/Dwipreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> /app/log/Dwipreproc_${timestamp_initial}.txt
        echo "$participant" >> /app/log/Dwipreproc_${timestamp_initial}.txt
        echo "*********************" >> /app/log/Dwipreproc_${timestamp_initial}.txt
 
        source /app/src/dwi_preproc.sh $participant $timestamp_initial

   fi
	
done < /project/data/participants.tsv






