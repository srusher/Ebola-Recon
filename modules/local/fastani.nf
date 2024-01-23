process FASTANI {
    tag "$meta.id"
    label 'process_medium'

    conda 'modules/nf-core/fastani/environment.yml'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastani:1.32--he1c1bb9_0' :
        'biocontainers/fastani:1.32--he1c1bb9_0' }"

    input:
    tuple val(meta), path(query)

    output:
    tuple val(meta), path("*.ani.txt"), emit: ani
    path "versions.yml"               , emit: versions
    path("*.matrix")                  , emit: matrix

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (params.fastaniparams == "m:m") {
        """
        fastANI \\
            $args \\
            --ql $query \\
            --rl $query \\
            --matrix \\
            --visualize \\
            --fragLen 250 \\
            -k 10 \\
            -o ${prefix}.ani.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastani: \$(fastANI --version 2>&1 | sed 's/version//;')
        END_VERSIONS
        """
    } else {
        """
        fastANI \\
            $args \\
            -q $query \\
            -r $query \\
            -o ${prefix}.ani.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastani: \$(fastANI --version 2>&1 | sed 's/version//;')
        END_VERSIONS
        """
    }
}
