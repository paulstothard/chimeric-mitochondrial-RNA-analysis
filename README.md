# chimeric-mitochondrial-RNA-analysis

This repository describes the methods used to characterize chimeric mitochondrial RNA transcripts in RNA-Seq datasets.

## Overview

STAR-Fusion was used to identify candidate fusion transcripts in RNA-Seq datasets, and an R script was used to parse the STAR-fusion output files and to enumerate mitochondrial gene fusions within each sample. Excel files and PCA plots were generated to summarize the results.

## RNA-Seq datasets

Four datasets were studied:

| Name                   | NCBI BioProject                                                       |
|------------------------|-----------------------------------------------------------------------|
| Rat aging muscle       | [PRJNA793055](https://www.ncbi.nlm.nih.gov/bioproject/PRJNA793055/)   |
| Human Twinkle mutation | [PRJNA532885](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA532885) |
| Human aging muscle     | [PRJNA662072](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA662072) |
| Human aging brain      | [PRJNA283498](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA283498) |

## Dependencies

`fasterq-dump` is used to download RNA-Seq data from NCBI. `fasterq-dump` is part of the SRA Toolkit, which can be installed using conda:

```bash
conda install -c bioconda sra-tools
```

STAR-Fusion version 1.10.0 is used to identify candidate fusion transcripts within RNA-Seq datasets. It can be run using a Docker image. Use the following to download the Docker image:

```bash
docker pull trinityctat/starfusion:1.10.0
```

The h5py Python package is used to build a Dfam file for STAR-Fusion. It can be installed using conda:

```bash
conda install -c anaconda h5py
```

The R script used to summarize results requires the following packages:

* argparser
* data.table
* ggfortify
* ggplot2
* janitor
* openxlsx
* tidyverse
* writexl

These can be installed using the supplied `install-packages.R` script:

```bash
Rscript scripts/install-packages.R
```

## Analysis procedure

### Prepare STAR-Fusion reference files

STAR-Fusion requires a CTAT genome lib, which includes various data files used in fusion-finding. Separate CTAT genome libs will be created for the rat and human datasets.

#### Download rat reference genome information from Ensembl

```bash
wget http://ftp.ensembl.org/pub/current_fasta/rattus_norvegicus/dna/Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
wget http://ftp.ensembl.org/pub/current_gtf/rattus_norvegicus/Rattus_norvegicus.Rnor_6.0.104.gtf.gz
```

#### Build a rat-specific Dfam file

```bash
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./scripts/famdb.py -i Dfam.h5 lineage -a Rattus
./scripts/famdb.py -i Dfam.h5 families -f hmm -a Rattus > rat_dfam.hmm
```

#### Prepare the rat Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/rat_dfam.hmm
```

#### Build the rat CTAT genome lib

For this step the Ensembl gene transfer format (GTF) file was manually modified prior to running the CTAT genome lib building script, in order to convey that the MT-ATP8 and MT-ATP6 genes are encoded within a single overlapping transcript that, although detected by STAR-Fusion, does not represent a chimeric mitochondrial RNA. Similarly, GTF information for the MT-ND4l and Mt-ND4 genes was updated to reflect that they are normally expressed as a single transcript.

The custom GTF file is available in the `custom-GTFs` directory.

Decompress the rat reference genome and GTF files:

```bash
gunzip Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
gunzip Rattus_norvegicus.Rnor_6.0.104_custom.gtf.gz
```

Run the `prep_genome_lib.pl` script, writing the output to the `rat_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa \
--gtf /data/Rattus_norvegicus.Rnor_6.0.104_custom.gtf \
--pfam_db current \
--dfam_db /data/rat_dfam.hmm \
--output_dir /data/rat_ctat_genome_lib_build_dir_custom_MT
```

#### Download human reference genome information from Ensembl

```bash
wget http://ftp.ensembl.org/pub/current_fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
wget http://ftp.ensembl.org/pub/current_gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz
```

#### Build a human-specific Dfam file

```bash
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./scripts/famdb.py -i Dfam.h5 lineage -a human
./scripts/famdb.py -i Dfam.h5 families -f hmm -a human > human_dfam.hmm
```

#### Prepare the human Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/human_dfam.hmm
```

#### Build the human CTAT genome lib

For this step the Ensembl gene transfer format (GTF) file was manually modified prior to running the CTAT genome lib building script, in order to convey that the MT-ATP8 and MT-ATP6 genes are encoded within a single overlapping transcript that, although detected by STAR-Fusion, does not represent a chimeric mitochondrial RNA. Similarly, GTF information for the MT-ND4l and Mt-ND4 genes was updated to reflect that they are normally expressed as a single transcript.

The custom GTF file is available in the `custom-GTFs` directory.

Decompress the human reference genome and GTF files:

```bash
gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
gunzip Homo_sapiens.GRCh38.104_custom.gtf.gz
```

Run the `prep_genome_lib.pl` script, writing the output to the `human_ctat_genome_lib_build_dir_custom_MT` directory:

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
/usr/local/src/STAR-Fusion/ctat-genome-lib-builder/prep_genome_lib.pl \
--genome_fa /data/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
--gtf /data/Homo_sapiens.GRCh38.104_custom.gtf \
--pfam_db current \
--dfam_db /data/human_dfam.hmm \
--output_dir /data/human_ctat_genome_lib_build_dir_custom_MT
```

### Analyze the rat aging muscle dataset

#### Download the rat aging muscle data

```bash
./scripts/run-fasterq-dump.sh SRA-metadata/rat-aging-muscle/SRR_Acc_List.txt rat-aging-muscle-data
```

#### Add fragment counts to the rat aging muscle data

```bash
./scripts/count-fragments.sh rat-aging-muscle-data
```

#### Run STAR-Fusion on the rat aging muscle data

```bash
./scripts/run-star-fusion.sh -i rat-aging-muscle-data -o rat-aging-muscle-data-results -r rat_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the rat aging muscle data

```bash
./scripts/merge_star-fusion-results.sh rat-aging-muscle-data-results star-fusion-results/rat-aging-muscle
cp rat-aging-muscle-data/fragment_counts.txt star-fusion-results/rat-aging-muscle
```

#### Compare the STAR-Fusion results among samples for the rat aging muscle data

need to fix this **pca_color_by**

```bash
Rscript scripts/compare-star-fusion-results.R --input_folder star-fusion-results/rat-aging-muscle --metadata_folder SRA-metadata/rat-aging-muscle  --output_folder star-fusion-results-summary/rat-aging-muscle --pca_color_by genotype
```

### Analyze the human Twinkle mutation dataset

#### Download the human Twinkle mutation data

```bash
./scripts/run-fasterq-dump.sh SRA-metadata/human-Twinkle-mutation/SRR_Acc_List.txt human-Twinkle-mutation-data
```

#### Add fragment counts to the human Twinkle mutation data

```bash
./scripts/count-fragments.sh human-Twinkle-mutation-data
```

#### Run STAR-Fusion on the human Twinkle mutation data

```bash
./scripts/run-star-fusion.sh -i human-Twinkle-mutation-data -o human-Twinkle-mutation-data-results -r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the human Twinkle mutation data

```bash
./scripts/merge_star-fusion-results.sh human-Twinkle-mutation-data-results star-fusion-results/human-Twinkle-mutation
cp human-Twinkle-mutation-data/fragment_counts.txt star-fusion-results/human-Twinkle-mutation
```

#### Compare the STAR-Fusion results among samples for the Twinkle mutation data

```bash
Rscript scripts/compare-star-fusion-results.R --input_folder star-fusion-results/human-Twinkle-mutation --metadata_folder SRA-metadata/human-Twinkle-mutation  --output_folder star-fusion-results-summary/human-Twinkle-mutation --pca_color_by genotype
```

### Analyze the human aging muscle dataset

#### Download the human aging muscle data

```bash
./scripts/run-fasterq-dump.sh SRA-metadata/human-aging-muscle/SRR_Acc_List.txt human-aging-muscle-data
```

#### Add fragment counts to the human aging muscle data

```bash
./scripts/count-fragments.sh human-aging-muscle-data
```

#### Run STAR-Fusion on the human aging muscle data

```bash
./scripts/run-star-fusion.sh -i human-aging-muscle-data -o human-aging-muscle-data-results -r human_ctat_genome_lib_build_dir_custom_MT
```

#### Merge the STAR-Fusion results for the human aging muscle data

```bash
./scripts/merge_star-fusion-results.sh human-aging-muscle-data-results star-fusion-results/human-aging-muscle
cp human-aging-muscle-data/fragment_counts.txt star-fusion-results/human-aging-muscle
```

#### Compare the STAR-Fusion results among samples for the human aging muscle data

```bash
Rscript scripts/compare-star-fusion-results.R --input_folder star-fusion-results/human-aging-muscle --metadata_folder SRA-metadata/human-aging-muscle  --output_folder star-fusion-results-summary/human-aging-muscle --pca_color_by genotype
```
