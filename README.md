# chimeric-mitochondrial-RNA-analysis

- [chimeric-mitochondrial-RNA-analysis](#chimeric-mitochondrial-rna-analysis)
  - [Overview](#overview)
  - [RNA-Seq datasets](#rna-seq-datasets)
  - [Dependencies](#dependencies)
  - [Analysis procedure](#analysis-procedure)
    - [Prepare STAR-Fusion reference files](#prepare-star-fusion-reference-files)
      - [Build a Dfam file for the rat genome](#build-a-dfam-file-for-the-rat-genome)
      - [Prepare the rat Dfam file for STAR-Fusion](#prepare-the-rat-dfam-file-for-star-fusion)
      - [Build the rat CTAT genome lib](#build-the-rat-ctat-genome-lib)
      - [Build a Dfam file for the human genome](#build-a-dfam-file-for-the-human-genome)
      - [Prepare the human Dfam file for STAR-Fusion](#prepare-the-human-dfam-file-for-star-fusion)
      - [Build the human CTAT genome lib](#build-the-human-ctat-genome-lib)
    - [Rat aging muscle dataset analysis](#rat-aging-muscle-dataset-analysis)
      - [Download the rat aging muscle sequence data](#download-the-rat-aging-muscle-sequence-data)
      - [Add fragment counts to the rat aging muscle data](#add-fragment-counts-to-the-rat-aging-muscle-data)
      - [Run STAR-Fusion on the rat aging muscle data](#run-star-fusion-on-the-rat-aging-muscle-data)
      - [Merge the STAR-Fusion results for the rat aging muscle data](#merge-the-star-fusion-results-for-the-rat-aging-muscle-data)
      - [Add fragment counts to the rat aging muscle STAR-Fusion results](#add-fragment-counts-to-the-rat-aging-muscle-star-fusion-results)
      - [Compare the STAR-Fusion results among samples for the rat aging muscle data](#compare-the-star-fusion-results-among-samples-for-the-rat-aging-muscle-data)
    - [Human Twinkle mutation dataset analysis](#human-twinkle-mutation-dataset-analysis)
      - [Download the human Twinkle mutation sequence data](#download-the-human-twinkle-mutation-sequence-data)
      - [Add fragment counts to the human Twinkle mutation data](#add-fragment-counts-to-the-human-twinkle-mutation-data)
      - [Run STAR-Fusion on the human Twinkle mutation data](#run-star-fusion-on-the-human-twinkle-mutation-data)
      - [Merge the STAR-Fusion results for the human Twinkle mutation data](#merge-the-star-fusion-results-for-the-human-twinkle-mutation-data)
      - [Add fragment counts to the human Twinkle mutation STAR-Fusion results](#add-fragment-counts-to-the-human-twinkle-mutation-star-fusion-results)
      - [Compare the STAR-Fusion results among samples for the Twinkle mutation data](#compare-the-star-fusion-results-among-samples-for-the-twinkle-mutation-data)
    - [Human aging muscle dataset analysis](#human-aging-muscle-dataset-analysis)
      - [Download the human aging muscle sequence data](#download-the-human-aging-muscle-sequence-data)
      - [Add fragment counts to the human aging muscle data](#add-fragment-counts-to-the-human-aging-muscle-data)
      - [Run STAR-Fusion on the human aging muscle data](#run-star-fusion-on-the-human-aging-muscle-data)
      - [Merge the STAR-Fusion results for the human aging muscle data](#merge-the-star-fusion-results-for-the-human-aging-muscle-data)
      - [Add fragment counts to the human aging muscle STAR-Fusion results](#add-fragment-counts-to-the-human-aging-muscle-star-fusion-results)
      - [Compare the STAR-Fusion results among samples for the human aging muscle data](#compare-the-star-fusion-results-among-samples-for-the-human-aging-muscle-data)
    - [Human aging brain dataset analysis](#human-aging-brain-dataset-analysis)
      - [Download the human aging brain sequence data](#download-the-human-aging-brain-sequence-data)
      - [Add fragment counts to the human aging brain data](#add-fragment-counts-to-the-human-aging-brain-data)
      - [Run STAR-Fusion on the human aging brain data](#run-star-fusion-on-the-human-aging-brain-data)
      - [Merge the STAR-Fusion results for the human aging brain data](#merge-the-star-fusion-results-for-the-human-aging-brain-data)
      - [Add fragment counts to the human aging brain STAR-Fusion results](#add-fragment-counts-to-the-human-aging-brain-star-fusion-results)
      - [Compare the STAR-Fusion results among samples for the human aging brain data](#compare-the-star-fusion-results-among-samples-for-the-human-aging-brain-data)

## Overview

This repository contains the code and methods used to characterize chimeric mitochondrial RNA transcripts in RNA-Seq datasets. The results of this work are included in the following publication:

> Chimeric mitochondrial RNA transcripts in mitochondrial genetic diseases and aging.
>
> Amy R. Vandiver, Allen Herbst, Paul Stothard, Jonathan Wanagat

To download the repository:

```bash
git clone git@github.com:paulstothard/chimeric-mitochondrial-RNA-analysis
```

or download the [latest release](https://github.com/paulstothard/chimeric-mitochondrial-RNA-analysis/releases/).

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

Docker is used to run STAR-Fusion and to build the STAR-Fusion reference files.

To download the STAR-Fusion version 1.10.0 Docker image:

```bash
docker pull trinityctat/starfusion:1.10.0
```

For the other dependencies a Conda environment can be created using the following commands:

```bash
conda create -n chimeric-mtrna python=3.8
conda activate chimeric-mtrna
conda install -y -c bioconda fastp fastqc sra-tools trimmomatic
conda install -y -c anaconda h5py
conda install -y -c conda-forge parallel r-base r-essentials
conda install -y -c conda-forge r-data.table r-ggfortify r-ggplot2 r-janitor r-openxlsx r-tidyverse r-writexl
```

## Analysis procedure

The commands below assume that the `scripts`, `metadata`, and `custom-GTFs` directories from this repository are in the current working directory.

### Prepare STAR-Fusion reference files

STAR-Fusion requires a CTAT genome lib, which includes various data files used in fusion-finding. Separate CTAT genome libs will be created for the rat and human datasets.

#### Build a Dfam file for the rat genome

```bash
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./scripts/famdb.py -i Dfam.h5 lineage -a Rattus
./scripts/famdb.py -i Dfam.h5 families -f hmm -a Rattus > rat_dfam.hmm
```

#### Prepare the rat Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
hmmpress /data/rat_dfam.hmm
```

#### Build the rat CTAT genome lib

Download and uncompress the rat reference genome sequence:

```bash
wget http://ftp.ensembl.org/pub/release-104/fasta/rattus_norvegicus/dna/\
Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz

gunzip Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
```

Uncompress the custom GTF file:

```bash
gunzip custom-GTFs/Rattus_norvegicus.Rnor_6.0.104_custom.gtf.gz
```

Run the STAR-Fusion `prep_genome_lib.pl` script, writing the output to the `rat_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa \
--gtf /data/custom-GTFs/Rattus_norvegicus.Rnor_6.0.104_custom.gtf \
--pfam_db current \
--dfam_db /data/rat_dfam.hmm \
--output_dir /data/rat_ctat_genome_lib_build_dir_custom_MT
```

Note that the above may create output owned by root. To change the ownership to the current user:

```bash
sudo chown -R $(id -u):$(id -g) rat_ctat_genome_lib_build_dir_custom_MT
```

If `sudo` is not available, try the following:

```bash
HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run -v "$(pwd)":/data --rm trinityctat/starfusion /bin/bash -c "\
chown -R $HOST_UID:$HOST_GID /data/rat_ctat_genome_lib_build_dir_custom_MT"
```

#### Build a Dfam file for the human genome

```bash
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./scripts/famdb.py -i Dfam.h5 lineage -a human
./scripts/famdb.py -i Dfam.h5 families -f hmm -a human > human_dfam.hmm
```

#### Prepare the human Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
hmmpress /data/human_dfam.hmm
```

#### Build the human CTAT genome lib

Download and uncompress the human reference genome sequence:

```bash
wget http://ftp.ensembl.org/pub/release-104/fasta/homo_sapiens/dna/\
Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz

gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
```

Uncompress the custom GTF file:

```bash
gunzip custom-GTFs/Homo_sapiens.GRCh38.104_custom.gtf.gz
```

Run the STAR-Fusion `prep_genome_lib.pl` script, writing the output to the `human_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
--gtf /data/custom-GTFs/Homo_sapiens.GRCh38.104_custom.gtf \
--pfam_db current \
--dfam_db /data/human_dfam.hmm \
--output_dir /data/human_ctat_genome_lib_build_dir_custom_MT
```

Note that the above may create output owned by root. To change the ownership to the current user:

```bash
sudo chown -R $(id -u):$(id -g) human_ctat_genome_lib_build_dir_custom_MT
```

If `sudo` is not available, try the following:

```bash
HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run -v "$(pwd)":/data --rm trinityctat/starfusion /bin/bash -c "\
chown -R $HOST_UID:$HOST_GID /data/human_ctat_genome_lib_build_dir_custom_MT"
```

### Rat aging muscle dataset analysis

#### Download the rat aging muscle sequence data

```bash
./scripts/run-fasterq-dump.sh \
metadata/rat-aging-muscle/SRR_Acc_List.txt \
rat-aging-muscle-data
```

#### Add fragment counts to the rat aging muscle data

```bash
./scripts/count-fragments.sh rat-aging-muscle-data
```

#### Run STAR-Fusion on the rat aging muscle data

```bash
./scripts/run-star-fusion.sh \
-i rat-aging-muscle-data \
-o rat-aging-muscle-data-results \
-r rat_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the rat aging muscle data

```bash
./scripts/merge-star-fusion-results.sh \
rat-aging-muscle-data-results \
star-fusion-results/rat-aging-muscle
```

#### Add fragment counts to the rat aging muscle STAR-Fusion results

```bash
cp rat-aging-muscle-data/fragment_counts.txt \
star-fusion-results/rat-aging-muscle
```

#### Compare the STAR-Fusion results among samples for the rat aging muscle data

```bash
Rscript scripts/summarize-rat-aging-muscle.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/rat-aging-muscle` directory.

### Human Twinkle mutation dataset analysis

#### Download the human Twinkle mutation sequence data

```bash
./scripts/run-fasterq-dump.sh \
metadata/human-Twinkle-mutation/SRR_Acc_List.txt \
human-Twinkle-mutation-data
```

#### Add fragment counts to the human Twinkle mutation data

```bash
./scripts/count-fragments.sh human-Twinkle-mutation-data
```

#### Run STAR-Fusion on the human Twinkle mutation data

```bash
./scripts/run-star-fusion.sh \
-i human-Twinkle-mutation-data \
-o human-Twinkle-mutation-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the human Twinkle mutation data

```bash
./scripts/merge-star-fusion-results.sh \
human-Twinkle-mutation-data-results \
star-fusion-results/human-Twinkle-mutation
```

#### Add fragment counts to the human Twinkle mutation STAR-Fusion results

```bash
cp human-Twinkle-mutation-data/fragment_counts.txt \
star-fusion-results/human-Twinkle-mutation
```

#### Compare the STAR-Fusion results among samples for the Twinkle mutation data

```bash
Rscript scripts/summarize-human-Twinkle-mutation.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-Twinkle-mutation` directory.

### Human aging muscle dataset analysis

#### Download the human aging muscle sequence data

```bash
./scripts/run-fasterq-dump.sh \
metadata/human-aging-muscle/SRR_Acc_List.txt \
human-aging-muscle-data
```

#### Add fragment counts to the human aging muscle data

```bash
./scripts/count-fragments.sh human-aging-muscle-data
```

#### Run STAR-Fusion on the human aging muscle data

```bash
./scripts/run-star-fusion.sh \
-i human-aging-muscle-data \
-o human-aging-muscle-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the human aging muscle data

```bash
./scripts/merge-star-fusion-results.sh \
human-aging-muscle-data-results \
star-fusion-results/human-aging-muscle
```

#### Add fragment counts to the human aging muscle STAR-Fusion results

```bash
cp human-aging-muscle-data/fragment_counts.txt \
star-fusion-results/human-aging-muscle
```

#### Compare the STAR-Fusion results among samples for the human aging muscle data

```bash
Rscript scripts/summarize-human-aging-muscle.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-aging-muscle` directory.

### Human aging brain dataset analysis

#### Download the human aging brain sequence data

```bash
./scripts/run-fasterq-dump.sh \
metadata/human-aging-brain/SRR_Acc_List.txt \
human-aging-brain-data
```

#### Add fragment counts to the human aging brain data

```bash
./scripts/count-fragments.sh human-aging-brain-data
```

#### Run STAR-Fusion on the human aging brain data

```bash
./scripts/run-star-fusion.sh \
-i human-aging-brain-data \
-o human-aging-brain-data-results \
-r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the human aging brain data

```bash
./scripts/merge-star-fusion-results.sh \
human-aging-brain-data-results \
star-fusion-results/human-aging-brain
```

#### Add fragment counts to the human aging brain STAR-Fusion results

```bash
cp human-aging-brain-data/fragment_counts.txt \
star-fusion-results/human-aging-brain
```

#### Compare the STAR-Fusion results among samples for the human aging brain data

```bash
Rscript scripts/human-aging-brain.R
```

The resulting Excel file and PDF plots are available in the `star-fusion-results-summary/human-aging-brain` directory.
