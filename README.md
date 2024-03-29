# chimeric-mitochondrial-RNA-analysis

This repository contains the code and methods used to characterize chimeric mitochondrial RNA transcripts in RNA-Seq datasets. The results of this work are included in the following publication:

> Chimeric mitochondrial RNA transcripts in mitochondrial genetic diseases and aging.
> 
> Amy R. Vandiver, Allen Herbst, Paul Stothard, Jonathan Wanagat

To download the repository:

```bash
$ git clone git@github.com:paulstothard/chimeric-mitochondrial-RNA-analysis
```

or download the [latest release](https://github.com/paulstothard/chimeric-mitochondrial-RNA-analysis/releases/).

## Overview

The scripts and procedures in this repository download RNA-Seq datasets from the NCBI SRA and use STAR-Fusion to identify candidate fusion transcripts. R code is used to parse the STAR-fusion output files for each dataset and to enumerate mitochondrial gene fusions within each sample. For each observed fusion type (based on genes involved and ignoring the precise boundaries of the fusion) the total number of supporting reads is calculated, using values extracted from the JunctionReadCount column. Next, a table termed "raw counts" is generated, consisting of samples (rows) and fusion types (columns) with cells containing the summation of the JunctionReadCount values. A second table, termed "FFPM" for "fusion fragments per million total RNA-Seq fragments" is generated from the first table by dividing each raw count by the total number of sequenced fragments (in millions) in the corresponding sample. SRA metadata is programmatically added to each table as additional columns, to facilitate further analyses. The raw counts and FFPM tables are written to a single Excel file as separate worksheets. PCA plots with and without sample labels and loadings are produced from the FFPM table and saved in PDF format.

Dataset download, STAR-Fusion analysis, and R analysis are performed using scripts provided in the `scripts` directory. Single-end and paired-end datasets are supported. The scripts are designed to be run from the top-level directory in the repository. The output of the STAR-Fusion analysis for each dataset is written to a separate directory within a `star-fusion-results` directory. Due to the large size of the STAR-Fusion output files, the `star-fusion-results` directory with pre-generated files is not included in this repository. However, the Excel files containing the raw counts and FFPM tables, and the PCA plots in PDF format are included in the `star-fusion-results-summary` folder for each of the datasets analyzed in this study.

Custom GTF files are used with STAR-Fusion in order to convey that the MT-ATP8 and MT-ATP6 genes and the MT-ND4l and Mt-ND4 genes are encoded within single transcripts that do not represent chimeric mitochondrial RNA.

The detailed analysis procedure is described below and can be used to reproduce the results.

## RNA-Seq datasets

Four datasets are analyzed in this study:

| Name                   | NCBI BioProject                                                       |
|------------------------|-----------------------------------------------------------------------|
| Rat aging muscle       | [PRJNA793055](https://www.ncbi.nlm.nih.gov/bioproject/PRJNA793055/)   |
| Human Twinkle mutation | [PRJNA532885](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA532885) |
| Human aging muscle     | [PRJNA662072](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA662072) |
| Human aging brain      | [PRJNA283498](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA283498) |

## Dependencies

`fasterq-dump` is used to download RNA-Seq data from NCBI. It can be installed using conda:

```bash
$ conda install -c bioconda sra-tools
```

STAR-Fusion version 1.10.0 is used to identify candidate fusion transcripts within RNA-Seq datasets. It can be downloaded as a Docker image:

```bash
$ docker pull trinityctat/starfusion:1.10.0
```

The h5py Python package is used to build a Dfam file for STAR-Fusion. It can be installed using conda:

```bash
$ conda install -c anaconda h5py
```

R and the following R packages are used to parse the STAR-Fusion output files and to enumerate mitochondrial gene fusions within each sample:

* data.table
* ggfortify
* ggplot2
* janitor
* openxlsx
* tidyverse
* writexl

R can be installed using conda:

```bash
$ conda install -c r r
```

The R packages can be installed using the supplied `install-packages.R` script:

```bash
$ Rscript scripts/install-packages.R
```

## Analysis procedure

### Preparing STAR-Fusion reference files

STAR-Fusion requires a CTAT genome lib, which includes various data files used in fusion-finding. Separate CTAT genome libs will be created for the rat and human datasets.

#### Downloading rat reference genome information from Ensembl

```bash
$ wget http://ftp.ensembl.org/pub/release-104/fasta/rattus_norvegicus/dna/\
Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
$ wget http://ftp.ensembl.org/pub/release-104/gtf/rattus_norvegicus/\
Rattus_norvegicus.Rnor_6.0.104.gtf.gz
```

#### Building a rat-specific Dfam file

```bash
$ wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
$ gunzip Dfam.h5.gz
$ ./scripts/famdb.py -i Dfam.h5 lineage -a Rattus
$ ./scripts/famdb.py -i Dfam.h5 families -f hmm -a Rattus > rat_dfam.hmm
```

#### Preparing the rat Dfam file for STAR-Fusion

```bash
$ docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/rat_dfam.hmm
```

#### Building the rat CTAT genome lib

The custom GTF file is available in the `custom-GTFs` directory.

Decompress the rat reference genome and GTF files:

```bash
$ gunzip Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
$ gunzip Rattus_norvegicus.Rnor_6.0.104_custom.gtf.gz
```

Run the `prep_genome_lib.pl` script, writing the output to the `rat_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
$ docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa \
--gtf /data/Rattus_norvegicus.Rnor_6.0.104_custom.gtf \
--pfam_db current \
--dfam_db /data/rat_dfam.hmm \
--output_dir /data/rat_ctat_genome_lib_build_dir_custom_MT
```

#### Downloading human reference genome information from Ensembl

```bash
$ wget http://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/\
Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
$ wget http://ftp.ensembl.org/pub/release-104/gtf/homo_sapiens/\
Homo_sapiens.GRCh38.104.gtf.gz
```

#### Building a human-specific Dfam file

```bash
$ wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
$ gunzip Dfam.h5.gz
$ ./scripts/famdb.py -i Dfam.h5 lineage -a human
$ ./scripts/famdb.py -i Dfam.h5 families -f hmm -a human > human_dfam.hmm
```

#### Preparing the human Dfam file for STAR-Fusion

```bash
$ docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/human_dfam.hmm
```

#### Building the human CTAT genome lib

The custom GTF file is available in the `custom-GTFs` directory.

Decompress the human reference genome and GTF files:

```bash
$ gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
$ gunzip Homo_sapiens.GRCh38.104_custom.gtf.gz
```

Run the `prep_genome_lib.pl` script, writing the output to the `human_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
$ docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
--gtf /data/Homo_sapiens.GRCh38.104_custom.gtf \
--pfam_db current \
--dfam_db /data/human_dfam.hmm \
--output_dir /data/human_ctat_genome_lib_build_dir_custom_MT
```

### Analyzing the rat aging muscle dataset

#### Downloading the rat aging muscle data

```bash
$ ./scripts/run-fasterq-dump.sh \
SRA-metadata/rat-aging-muscle/SRR_Acc_List.txt \
rat-aging-muscle-data
```

#### Adding fragment counts to the rat aging muscle data

```bash
$ ./scripts/count-fragments.sh rat-aging-muscle-data
```

#### Running STAR-Fusion on the rat aging muscle data

```bash
$ ./scripts/run-star-fusion.sh -i rat-aging-muscle-data \
-o rat-aging-muscle-data-results \
-r rat_ctat_genome_lib_build_dir_custom_MT
```

#### Merging the STAR-Fusion results for the rat aging muscle data

```bash
$ ./scripts/merge_star-fusion-results.sh \
rat-aging-muscle-data-results \
star-fusion-results/rat-aging-muscle
```

#### Adding fragment counts to the rat aging muscle STAR-Fusion results

```bash
$ cp rat-aging-muscle-data/fragment_counts.txt \
star-fusion-results/rat-aging-muscle
```

#### Comparing the STAR-Fusion results among samples for the rat aging muscle data

```bash
$ Rscript scripts/summarize-rat-aging-muscle.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/rat-aging-muscle` directory.

### Analyzing the human Twinkle mutation dataset

#### Downloading the human Twinkle mutation data

```bash
$ ./scripts/run-fasterq-dump.sh \
SRA-metadata/human-Twinkle-mutation/SRR_Acc_List.txt \
human-Twinkle-mutation-data
```

#### Adding fragment counts to the human Twinkle mutation data

```bash
$ ./scripts/count-fragments.sh human-Twinkle-mutation-data
```

#### Running STAR-Fusion on the human Twinkle mutation data

```bash
$ ./scripts/run-star-fusion.sh \
-i human-Twinkle-mutation-data \
-o human-Twinkle-mutation-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merging the STAR-Fusion results for the human Twinkle mutation data

```bash
$ ./scripts/merge_star-fusion-results.sh \
human-Twinkle-mutation-data-results \
star-fusion-results/human-Twinkle-mutation
```

#### Adding fragment counts to the human Twinkle mutation STAR-Fusion results

```bash
$ cp human-Twinkle-mutation-data/fragment_counts.txt \
star-fusion-results/human-Twinkle-mutation
```

#### Comparing the STAR-Fusion results among samples for the Twinkle mutation data

```bash
$ Rscript scripts/summarize-human-Twinkle-mutation.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-Twinkle-mutation` directory.

### Analyzing the human aging muscle dataset

#### Downloading the human aging muscle data

```bash
$ ./scripts/run-fasterq-dump.sh \
SRA-metadata/human-aging-muscle/SRR_Acc_List.txt \
human-aging-muscle-data
```

#### Adding fragment counts to the human aging muscle data

```bash
$ ./scripts/count-fragments.sh human-aging-muscle-data
```

#### Running STAR-Fusion on the human aging muscle data

```bash
$ ./scripts/run-star-fusion.sh \
-i human-aging-muscle-data \
-o human-aging-muscle-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merging the STAR-Fusion results for the human aging muscle data

```bash
$ ./scripts/merge_star-fusion-results.sh \
human-aging-muscle-data-results \
star-fusion-results/human-aging-muscle
```

#### Adding fragment counts to the human aging muscle STAR-Fusion results

```bash
$ cp human-aging-muscle-data/fragment_counts.txt \
star-fusion-results/human-aging-muscle
```

#### Comparing the STAR-Fusion results among samples for the human aging muscle data

```bash
$ Rscript scripts/summarize-human-aging-muscle.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-aging-muscle` directory.

### Analyzing the human aging brain dataset

#### Downloading the human aging brain data

```bash
$ ./scripts/run-fasterq-dump.sh \
SRA-metadata/human-aging-brain/SRR_Acc_List.txt \
human-aging-brain-data
```

#### Adding fragment counts to the human aging brain data

```bash
$ ./scripts/count-fragments.sh human-aging-brain-data
```

#### Running STAR-Fusion on the human aging brain data

```bash
$ ./scripts/run-star-fusion.sh \
-i human-aging-brain-data \
-o human-aging-brain-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merging the STAR-Fusion results for the human aging brain data

```bash
$ ./scripts/merge_star-fusion-results.sh \
human-aging-brain-data-results \
star-fusion-results/human-aging-brain
```

#### Adding fragment counts to the human aging brain STAR-Fusion results

```bash
$ cp human-aging-brain-data/fragment_counts.txt \
star-fusion-results/human-aging-brain
```

#### Comparing the STAR-Fusion results among samples for the human aging brain data

```bash
$ Rscript scripts/human-aging-brain.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-aging-brain` directory.
