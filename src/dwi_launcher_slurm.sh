#!/bin/bash

#SBATCH -J dwiprep # A single job name for the array
#SBATCH -n 4 # Number of cores
#SBATCH -p general # Partition
#SBATCH --mem 12000 # Memory request
#SBATCH -o log/dwiprep_%A_%a.out # Standard output
#SBATCH -e log/dwiprep_%A_%a.err # Standard error

module load Apptainer

timestamp_initial=$(date +"%H:%M")

# Path where the fmriprep.sif image is located
apptainer_path=$1
# Path to the data folder
data_path=$2
# Path to the repo folder
repo_path=$3
# Path to the output folder
output_path=$4
# Parcellation path
parcellation=$5
parcellation_name=$(basename $parcellation .nii.gz)

if [ -d ${output_path} ]; then
    echo "Output folder already exists"
else
    mkdir -p ${output_path}
fi

mkdir -p ${output_path}/log

participants_file=${data_path}/participants.tsv

# Locate the slurm array index in the participants file (add 1 to remove the header of the file)
list_pointer=$((SLURM_ARRAY_TASK_ID+1))
participant_name=$( sed -n "${list_pointer}p" ${participants_file} | tr -d '\n' | awk ' {print $1} ')

echo "Participant:"
echo ${participant_name}

if [  -f "${output_path}/Dwiprep/${participant}/${parcellation_name}_det.csv" ]; then
        echo "$participant already processed" >> ${output_path}/Dwipreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> ${output_path}/Dwipreproc_${timestamp_initial}.txt
        echo "$participant" >> ${output_path}/Dwipreproc_${timestamp_initial}.txt
        echo "*********************" >> ${output_path}/Dwipreproc_${timestamp_initial}.txt

        if [ -f "${output_path}/Dwiprep/${participant}/dwi_clean.nii.gz" ]; then
            echo "Dwi data already cleaned" >> ${output_path}/Dwipreproc_${timestamp_initial}.txt
        else
            source ${repo_path}/src/dwi_preproc.sh $data_path $output_path $participant $timestamp_initial
        fi
        source ${repo_path}/src/dwi_tract.sh ${repo_path} $output_path $participant $timestamp_initial $parcellation_name
fi