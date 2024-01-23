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

    # Parse the file with awk and check conditions
    while IFS=\$'\t' read -r line; do

        identifier=\$(echo \$line | awk -F' ' '{ print \$1 }')
        
        if [[ \$valid_reads == "" ]]; then

            valid_reads="\$identifier"

        else

            valid_reads="\$valid_reads \$identifier"
        
        fi


    done < $blast_report

    bash ${projectDir}/bin/split_contigs.sh $contigs ${meta.id} "\$valid_reads"
    """
}
