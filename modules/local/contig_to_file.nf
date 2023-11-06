process CONTIG_TO_FILE {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(contigs)
    tuple val(meta), path(blast_report)

    output:
    tuple val(meta), path('*.fa')    , optional:true, emit: contig_path

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def spades_contigs = "$contigs"
    """
    #!/bin/bash
    
    valid_reads=""
    exp=""

    # Parse the file with awk and check conditions
    while IFS=\$'\t' read -r line; do

        identifier=\$(echo \$line | awk -F' ' '{ print \$1 }')

        evalue=\$(echo \$line | awk -F' ' '{ print \$11 }')

        bitscore=\$(echo \$line | awk -F' ' '{ print \$12 }')
        bitscore="\${bitscore%.*}"
        
        e_thresh=6
        bit_thresh=55

        e_string=\$(echo "\$evalue" | grep 'e-')

        if [ ! -z "\$e_string" ]; then
        
            exp=\$(echo \$evalue | awk -F 'e-' '{print \$2}' )
        
        else

            exp=""

        fi

        if [ ! -z "\$exp" ]; then

            if [ "\$exp" -gt "\$e_thresh" ]; then

                valid_reads="\$valid_reads \$identifier"

            fi

        elif [[ "\$evalue" == "0.0" ]]; then

            valid_reads="\$valid_reads \$identifier"

        elif [ "\$bitscore" -lt "\$bit_thresh" ]; then

            valid_reads="\$valid_reads \$identifier"

        fi

    done < $blast_report

    bash ${projectDir}/bin/split_contigs.sh $contigs ${meta.id} "\$valid_reads"
    """
}
