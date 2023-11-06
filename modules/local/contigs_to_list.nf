process CONTIGS_TO_LIST {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(contigs)

    output:
    tuple val(meta), path('*.txt')    , optional:true, emit: contig_list

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def spades_contigs = "$contigs"
    """
    for i in \$(ls ${projectDir}/${params.outdir}/contig); do
        echo ${projectDir}/${params.outdir}/contig/\$i  >> contigs_list.txt
    done
    """
}
