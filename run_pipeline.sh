#!/bin/bash

SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

nextflow run main.nf -c /scicomp/reference/nextflow/configs/cdc-dev.config -profile rosalind,singularity,test --outdir results


echo -ne "\nWould you like to clear your nextflow \"work\" and \".nextflow\" directories?\nNOTE: You only need to keep these directories around if you intend to troubleshoot the previous nextflow run!\nPlease enter Yes or No: "; read user_input; echo


user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

if [[ $user_input == "yes" || $user_input == "y" ]]; then
    rm -rf $SCRIPTDIR/work/*
    rm -rf $SCRIPTDIR/.nextflow/*
fi
