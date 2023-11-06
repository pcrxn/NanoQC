// Modified from https://raw.githubusercontent.com/nf-core/ampliseq/4e48b7100302e2576ac1be2ccc7d464253e9d20e/subworkflows/local/parse_input.nf
workflow PARSE_INPUT {
    take:
    input // folder
    extension

    main:
    error_message = "\nCannot find any reads matching: \"${input}${extension}\"\n"
    error_message += "Please revise the input folder (\"--input_folder\"): \"${input}\"\n"
    error_message += "and the input file pattern (\"--extension\"): \"${extension}\"\n"
    error_message += "*Please note: Path needs to be enclosed in quotes!*\n"
    error_message += "For more info, please consult the pipeline documentation.\n"
    Channel
        .fromPath( input + extension )
        .ifEmpty { error("${error_message}") }
        .map { read ->
                def meta = [:]
                meta.id = read.baseName.toString().indexOf(".") != -1 ? read.baseName.toString().take(read.baseName.toString().indexOf(".")) : read.baseName
                [ meta, read ] }
        .set { ch_reads }

    //Check whether all sampleID = meta.id are unique
    ch_reads
        .map { meta, reads -> [ meta.id ] }
        .toList()
        .subscribe {
            if( it.size() != it.unique().size() ) {
                ids = it.take(10);
                error("Please review data input, sample IDs are not unique! First IDs are $ids")
            }
        }

    // //Check that no dots "." are in sampleID
    // ch_reads
    //     .map { meta, reads -> meta.id }
    //     .subscribe { if ( "$it".contains(".") ) error("Please review data input, sampleIDs may not contain dots, but \"$it\" does.") }

    emit:
    reads   = ch_reads
}
