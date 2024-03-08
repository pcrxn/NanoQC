/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { fromSamplesheet; paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowNanoqc.initialise(params, log)

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
include { PARSE_INPUT } from '../subworkflows/local/parse_input'
include { PORECHOP_ABI                } from '../modules/local/porechop/abi/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CHOPPER                      } from '../modules/nf-core/chopper/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS  } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { FASTQC as FASTQC_RAW         } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_TRIMMED     } from '../modules/nf-core/fastqc/main'
include { MULTIQC                      } from '../modules/nf-core/multiqc/main'
include { NANOPLOT                     } from '../modules/nf-core/nanoplot/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow NANOQC {

    ch_versions = Channel.empty()

    if (params.input) {
        // Argument is the name of the parameter which specifies the samplesheet, i.e. params.input = 'input'
        // [[id:ERR9958133], https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/fastq/sub_ERR9958133.fastq.gz]
        // [[id:ERR9958134], https://raw.githubusercontent.com/nf-core/test-datasets/scnanoseq/fastq/sub_ERR9958134.fastq.gz]
        ch_input = Channel.fromSamplesheet('input')
    } else if (params.input_folder) {
        PARSE_INPUT(params.input_folder, params.extension)
        ch_input = PARSE_INPUT.out.reads
    } else {
        error("One of `--input` or `--input_folder` must be provided!")
    }

    //
    // MODULE: Porechop_ABI
    //
    if (!params.skip_porechop) {
        PORECHOP_ABI(ch_input)
        ch_preprocessed_reads = PORECHOP_ABI.out.reads
        ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions.first())
    } else {
        ch_preprocessed_reads = ch_input
    }

    //
    // MODULE: chopper
    //
    if (!params.skip_chopper) {
        if (!params.skip_porechop) {
            CHOPPER(ch_preprocessed_reads)
            ch_processed_reads = CHOPPER.out.fastq
        } else {
            CHOPPER(ch_input)
            ch_processed_reads = CHOPPER.out.fastq
        }
        ch_versions = ch_versions.mix(CHOPPER.out.versions.first())
    } else {
        if (!params.skip_porechop) {
            ch_processed_reads = PORECHOP_ABI.out.reads
        } else {
            ch_processed_reads = ch_input
        }
    }

    //
    // MODULE: FastQC
    //
    if (!params.skip_chopper) {
        FASTQC_RAW(ch_input)
        FASTQC_TRIMMED(ch_processed_reads)
        ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first(), FASTQC_TRIMMED.out.versions.first())
    } else {
        FASTQC_RAW(ch_input)
        ch_versions = ch_versions.mix(FASTQC_RAW.out.versions.first())
    }

    //
    // MODULE: NanoPlot
    //
    if (!params.skip_chopper || !params.skip_porechop) {
        NANOPLOT(ch_processed_reads)
    } else {
        NANOPLOT(ch_input)
    }
    ch_versions = ch_versions.mix(NANOPLOT.out.versions.first())

    //
    // MODULE: CUSTOM_DUMPSOFTWAREVERSIONS
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
    ch_versions.unique().collectFile(name: 'collated_versions.yml').view()

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowNanoqc.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowNanoqc.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    // FastQC
    if (!params.skip_chopper) {
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_TRIMMED.out.zip.collect{it[1]}.ifEmpty([]))
    } else {
        ch_multiqc_files = ch_multiqc_files.mix(FASTQC_RAW.out.zip.collect{it[1]}.ifEmpty([]))
    }

    // Porechop_ABI
    if (!params.skip_porechop) {
        ch_multiqc_files = ch_multiqc_files.mix(PORECHOP_ABI.out.log.collect{it[1]}.ifEmpty([]))
    }
    // TODO: Add more process outputs for MultiQC input here

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
