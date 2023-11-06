#!/bin/bash

# Initialize an empty list to store the first columns that meet the conditions
valid_reads=""
exp=""

# Parse the file with awk and check conditions
while IFS=$'\t' read -r line; do

    identifier=$(echo $line | awk -F' ' '{ print $1 }')

    evalue=$(echo $line | awk -F' ' '{ print $11 }')

    bitscore=$(echo $line | awk -F' ' '{ print $12 }')
    bitscore="${bitscore%.*}"
    
    e_thresh=6
    bit_thresh=55

    e_string=$(echo "$evalue" | grep 'e-')

    if [ ! -z "$e_string" ]; then
    
        exp=$(echo $evalue | awk -F 'e-' '{print $2}' )
    
    fi

    if [ ! -z "$exp" ]; then

        if [ "$exp" -gt "$e_thresh" ]; then

            valid_reads="$valid_reads $identifier"

        fi

    elif [[ "$evalue" == "0.0" ]]; then

        valid_reads="$valid_reads $identifier"

    elif [ "$bitscore" -lt "$bit_thresh" ]; then

        valid_reads="$valid_reads $identifier"

    fi

done < /scicomp/home-pure/rtq0/Bio/Projects/2023_hackathon/scicomp-sample-workflow/results/blast/sample1_metagenomes_T1.txt

echo $valid_reads

exit

bash /scicomp/home-pure/rtq0/Bio/Projects/2023_hackathon/scicomp-sample-workflow/bin/split_contigs.sh /scicomp/home-pure/rtq0/Bio/Projects/2023_hackathon/scicomp-sample-workflow/results/unzip/sample4_metagenome_T1.contigs.fa "metaID" "$valid_reads"