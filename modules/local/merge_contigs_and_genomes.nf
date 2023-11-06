process MERGE_LISTS {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(contigs)
    path(genomes)

    output:
    tuple val(meta), path('*.txt')    , optional:true, emit: merged_list

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    for i in \$(cat $genomes); do
        echo \$i >> merged_list.txt
    done

    for i in \$(cat $contigs); do
        echo \$i >> merged_list.txt
    done
    """
}
