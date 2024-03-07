process PORECHOP_ABI {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/porechop_abi:0.5.0--py310h590eda1_0':
        'biocontainers/porechop_abi:0.5.0--py310h590eda1_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_porechop.fastq.gz"), emit: reads
    tuple val(meta), path("*_porechop.log")     , emit: log
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [ "${reads}" = "${meta.id}.fastq.gz" ]; then
        renamed_reads="${reads}"
    else
        cp -L $reads "${meta.id}.fastq.gz" && \
        renamed_reads="${meta.id}.fastq.gz"
    fi

    porechop_abi \\
        --input \${renamed_reads} \\
        --threads $task.cpus \\
        $args \\
        --output ${prefix}_porechop.fastq.gz \\
        > ${prefix}_porechop.log
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        porechop_abi: \$( porechop_abi --version )
    END_VERSIONS
    """
}
