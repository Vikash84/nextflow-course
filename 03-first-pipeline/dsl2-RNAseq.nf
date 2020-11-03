#!/usr/bin/env nextflow

// This is needed for activating the new DLS2
nextflow.enable.dsl=2

// Similar to DSL1, the input data is defined in the beginning.


println """\
      LIST OF PARAMETERS
================================
Reads            : $params.reads
Output-folder    : $params.outdir/
Threads          : $params.threads
...
"""

// Also channels are being created. 
read_pairs_ch = Channel
        .fromFilePairs(params.reads, checkIfExists:true)

//dirgenome = file(params.dirgenome)
genome = file(params.genome)
gtf = file(params.gtf)

// Process trimmomatic
process trimmomatic {
    publishDir "$params.outdir/trimmed-reads", mode: 'copy'

    // Same input as fastqc on raw reads, comes from the same channel. 
    input:
    tuple val(sample), file(reads) 

    output:
    tuple val(sample), file("*P.fq"), emit: paired_fq

    script:
    """
    mkdir -p $params.outdir/trimmed-reads/
    trimmomatic PE -threads $params.threads ${reads[0]} ${reads[1]} ${sample}_1P.fq ${sample}_1U.fq ${sample}_2P.fq ${sample}_2U.fq $params.slidingwindow $params.avgqual 
    """
}

include { QC as fastqc_raw; QC as fastqc_trim } from "${launchDir}/modules/fastqc" //addParams(OUTPUT: fastqcOutputFolder)
include { IDX; MAP } from "${launchDir}/modules/star"

// Running a workflow with the defined processes here.  
workflow {
	read_pairs_ch.view()
	fastqc_raw(read_pairs_ch) 
  paired_fq = trimmomatic(read_pairs_ch)
  fastqc_trim(paired_fq)
  IDX(genome, gtf)
  MAP(paired_fq, gtf)
}