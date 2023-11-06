/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowEbola.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

// Short read QC
include { FASTQC as FASTQC_RAW } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_TRIM } from '../modules/nf-core/fastqc/main'
include { FASTP } from '../modules/nf-core/fastp/main'

// Long read QC
include { NANOPLOT as NANOPLOT_RAW } from '../modules/nf-core/nanoplot/main'
include { NANOPLOT as NANOPLOT_FILTERED } from '../modules/nf-core/nanoplot/main'
include { PORECHOP_PORECHOP } from '../modules/nf-core/porechop/porechop/main'

include { KRAKEN2_KRAKEN2 as KRAKEN2_HUMAN } from '../modules/nf-core/kraken2/kraken2/main'
include { KRAKEN2_KRAKEN2 as KRAKEN2_STD } from '../modules/nf-core/kraken2/kraken2/main'
include { SPADES } from '../modules/nf-core/spades/main'
include { BLAST_MAKEBLASTDB } from '../modules/nf-core/blast/makeblastdb/main'
include { BLAST_BLASTN } from '../modules/nf-core/blast/blastn'
include { PROKKA } from '../modules/nf-core/prokka/main'
include { QUAST } from '../modules/nf-core/quast/main'
include { MINIMAP2_ALIGN } from '../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_STATS } from '../modules/nf-core/samtools/stats/main'
include { SAMTOOLS_FASTA } from '../modules/nf-core/samtools/fasta/main'
include { IVAR_VARIANTS } from '../modules/nf-core/ivar/variants/main'

include { FASTTREE } from '../modules/nf-core/fasttree/main'

include { MULTIQC } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

//
// MODULE: custom, local modules
//
include { UNZIP } from '../modules/local/unzip'
include { CONTIG_TO_FILE } from '../modules/local/contig_to_file'
include { CONTIGS_TO_LIST } from '../modules/local/contigs_to_list'
include { MERGE_LISTS } from '../modules/local/merge_contigs_and_genomes'
include { FASTANI } from '../modules/local/fastani'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

// defining kraken_map with placeholder value - will be defined later and used in spades process
def kraken_map = [[],[],[],[]]

def spades_executed = false

workflow EBOLA {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input)
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    // TODO: OPTIONAL, you can use nf-validation plugin to create an input channel from the samplesheet with Channel.fromSamplesheet("input")
    // See the documentation https://nextflow-io.github.io/nf-validation/samplesheets/fromSamplesheet/
    // ! There is currently no tooling to help you write a sample sheet schema

    //
    // MODULE: Run FastQC
    //

        
    FASTQC_RAW (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first())

    FASTP (
        INPUT_CHECK.out.reads,
        params.adapters,
        false,
        false
    )

    FASTQC_TRIM (
        FASTP.out.reads
    )
    
    if (params.read_type == 'nanopore') { 

        NANOPLOT_RAW (
            INPUT_CHECK.out.reads
        )

        NANOPLOT_FILTERED (
            FASTP.out.reads
        )

    }

    // filter out human reads with kraken2
    KRAKEN2_HUMAN (
        FASTP.out.reads,
        params.kraken_db_human,
        true,
        true
    )

    // classify remaining reads
    KRAKEN2_STD (
        KRAKEN2_HUMAN.out.unclassified_reads_fastq,
        params.kraken_db_std,
        true,
        true
    )

    // align reads to reference viral genome
    MINIMAP2_ALIGN ( 
        KRAKEN2_STD.out.classified_reads_fastq,
        params.fasta,
        true,
        false,
        false
    )

    // generating summary of bam file
    SAMTOOLS_STATS (
        MINIMAP2_ALIGN.out.bam.map { meta, bam -> [ meta, bam, [] ] },
        [[id:'ebola_ref_genome'],[params.fasta]]
    )

    SAMTOOLS_FASTA (
        MINIMAP2_ALIGN.out.bam,
        false
    )

    // variant calling using ivar
    IVAR_VARIANTS (
        MINIMAP2_ALIGN.out.bam,
        params.fasta,
        [],
        [],
        false
    )

    // set spades parameters by reading-in the "read-type" param from nextflow.config
    if (params.read_type == 'illumina') {
        kraken_map = KRAKEN2_STD.out.classified_reads_fastq.map { meta, fastq -> [ meta, fastq, [], [] ] }
    } else if (params.read_type == 'pacbio') {
        kraken_map = KRAKEN2_STD.out.classified_reads_fastq.map { meta, fastq -> [ meta, [], fastq, [] ] }
    } else if (params.read_type == 'nanopore') {
        kraken_map = KRAKEN2_STD.out.classified_reads_fastq.map { meta, fastq -> [ meta, [], [], fastq ] }
    }

    // assemble reads with spades - set params.meta_sample to true in nextflow.config for meta spades
    // we always want to assemble short reads / illumina reads
    if (params.read_type == 'illumina' ) {
    
        SPADES (
            kraken_map,
            [],
            []
        )

        spades_executed = true

    // we may not always want to assemble long-read data, but if we do, it'll be a hybrid assembly
    } else if (params.hybrid_assembly) {

        SPADES (
            kraken_map,
            [],
            []
        )

        spades_executed = true         
    }

    if (spades_executed) {
        
        //assembly qc with quast
        QUAST (
            SPADES.out.scaffolds, // consensus (one or more assemblies)
            [[id:"ref_fasta"],[params.fasta]], // fasta (reference, optional)
            [[],[]] // gff (optional)
        )

        // for some reason prokka needs an unzipped version of the spades contigs
        UNZIP (
            SPADES.out.contigs
        )


        if (params.build_blast_db) {

            BLAST_MAKEBLASTDB (
                params.blastdb_fasta
            )

            BLAST_BLASTN (
                UNZIP.out.unzip_contigs,
                BLAST_MAKEBLASTDB.out.db
            )

            blat_ch = BLAST_BLASTN.out.txt

        } else {

            BLAST_BLASTN (
                UNZIP.out.unzip_contigs,
                params.blastdb_dir
            )

            blat_ch = BLAST_BLASTN.out.txt
        }
        
        // breaking each contig produced from spades into a separate file
        CONTIG_TO_FILE (
            UNZIP.out.unzip_contigs,
            BLAST_BLASTN.out.txt
        )

        // Creating a file that contains the list of all the file paths to each contigs file
        CONTIGS_TO_LIST (
            CONTIG_TO_FILE.out.contig_path
        )

        // Concatentating the contigs list and genomes list for sourmash input
        MERGE_LISTS (
            CONTIGS_TO_LIST.out.contig_list,
            params.genomes_for_msa
        )

        // Insert FastANI module here




        // assembly annotation with prokka
        PROKKA (
            UNZIP.out.unzip_contigs,
            [],
            []
        )

    }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowEbola.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowEbola.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    if (params.read_type == 'illumina') {

        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))
    
    }

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
