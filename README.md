# NanoQC

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

**NanoQC** is a bioinformatics pipeline that performs quality control of basecalled Nanopore sequence data in `.fastq.gz` format.

## Overview

1. Perform read QC with [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).
2. Perform read QC with [`NanoPlot`](https://github.com/wdecoster/NanoPlot).
3. Collect QC reports with [`MultiQC`](http://multiqc.info/).

## Usage

If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
with `-profile test` before running the workflow on actual data.

Please provide pipeline parameters via the CLI or Nextflow `-params-file` option.
Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

NanoQC can be run using two different input types:

- A **samplesheet**, including sample names and paths to Nanopore-basecalled gzipped FASTQ files, or
- A **folder** containing Nanopore-basecalled gzipped FASTQ files.

### Input type: Samplesheet

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq
CONTROL_1,data/AEG588A1.fastq.gz
CONTROL_2,data/AEG588A2.fastq.gz
TREATMENT_1,data/AEG575A5.fastq.gz
```

Each row represents a gzipped FASTQ file.

Now, you can run the pipeline using:

```bash
nextflow run pcrxn/nanoqc \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

### Input type: Folder

Instead of a samplesheet, the user can instead provide a path to a directory containing gzipped FASTQ files.
In this case, the sample name will be the name of the file up until the first period (`.`).

For example, for a folder `data/` that looks as follows:

```bash
data
├── ERR9958133.fastq.gz
└── ERR9958134.fastq.gz
```

The pipeline can be run using:

```bash
nextflow run pcrxn/nanoqc \
   -profile <docker/singularity/.../institute> \
   --input_folder data/ \
   --outdir <OUTDIR>
```

If the names of the gzipped FASTQ files do not end with `.fastq.gz`, an alternate extension can be specified using `--extension`.

## Contributions and support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) initative, and reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> Ewels PA, Peltzer A, Fillinger S, Patel H, Alneberg J, Wilm A, Garcia MU, Di Tommaso P, Nahnsen S. The nf-core framework for community-curated bioinformatics pipelines. Nat Biotechnol. 2020 Mar;38(3):276-278. doi: 10.1038/s41587-020-0439-x. PubMed PMID: 32055031.

In addition, references of tools and data used in this pipeline are as follows:

- [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)

  > Andrews S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data [Online].

- [MultiQC](https://pubmed.ncbi.nlm.nih.gov/27312411/)

  > Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics. 2016 Oct 1;32(19):3047-8. doi: 10.1093/bioinformatics/btw354. Epub 2016 Jun 16. PubMed PMID: 27312411; PubMed Central PMCID: PMC5039924.

- [NanoPlot](https://academic.oup.com/bioinformatics/article/39/5/btad311/7160911/)

  > De Coster W, Rademakers R. NanoPack2: population-scale evaluation of long-read sequencing data, Bioinformatics. 2023 May 12;39(5):btad311. doi: 10.1093/bioinformatics/btad311.
