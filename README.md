# chimeric-mitochondrial-RNA-analysis

This repository describes the methods used to characterize chimeric mitochondrial RNA transcripts in RNA-Seq data sets related to mitochondrial genetic diseases and aging.

## Overview

STAR-Fusion was used to identify candidate fusion transcripts in RNA-Seq data sets, and R scripts were used to parse the STAR-fusion output files and to enumerate mitochondrial gene fusions within each sample. Excel files and PCA plots were generated to summarize the results and for downstream analysis.

## RNA-Seq data sets

Four data sets were studied:

| Name                   | NCBI BioProject                                                       |
|------------------------|-----------------------------------------------------------------------|
| Rat aging muscle       | [PRJNA793055](https://www.ncbi.nlm.nih.gov/bioproject/PRJNA793055/)   |
| Human Twinkle mutation | [PRJNA532885](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA532885) |
| Human aging muscle     | [PRJNA662072](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA662072) |
| Human aging brain      | [PRJNA283498](https://www.ncbi.nlm.nih.gov/bioproject/?term=PRJNA283498) |

## Analysis procedure

### Preparation of STAR-Fusion input files

STAR-Fusion version 1.10.0 was used to identify candidate fusion transcripts within RNA-Seq datasets. STAR-Fusion requires a CTAT genome lib, which includes various data files used in fusion-finding. Separate CTAT genome libs were created for rat and human.

A Docker image was used to run STAR-Fusion.

Pull the Docker image:

```bash
docker pull trinityctat/starfusion:1.10.0
```

#### Rat CTAT genome lib creation

##### Download rat reference genome information from Ensembl

```bash
wget http://ftp.ensembl.org/pub/current_fasta/rattus_norvegicus/dna/Rattus_norvegicus.Rnor_6.0.dna.toplevel.fa.gz
wget http://ftp.ensembl.org/pub/current_gtf/rattus_norvegicus/Rattus_norvegicus.Rnor_6.0.104.gtf.gz
```

##### Build a rat-specific Dfam file

```bash
pip3 install --user h5py
wget https://raw.githubusercontent.com/Dfam-consortium/FamDB/master/famdb.py
chmod u+x famdb.py
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./famdb.py -i Dfam.h5 lineage -a Rattus
./famdb.py -i Dfam.h5 families -f hmm -a Rattus > rat_dfam.hmm
```

##### Prepare the rat Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/rat_dfam.hmm
```

##### Build the rat CTAT genome lib

For this step the Ensembl gene transfer format (GTF) file was manually modified prior to running the CTAT genome lib building script, in order to convey that the MT-ATP8 and MT-ATP6 genes are encoded within a single overlapping transcript that, although detected by STAR-Fusion, does not represent a chimeric mitochondrial RNA. Similarly, GTF information for the MT-ND4l and Mt-ND4 genes was updated to reflect that they are normally expressed as a single transcript.

The custom GTF file is available in the `custom-GTFs` directory.

Uncompress the rat reference genome and GTF files:

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
--output_dir /data/ctat_genome_lib_build_dir_custom_MT
```

#### Human CTAT genome lib creation

##### Download human reference genome information from Ensembl

```bash
wget http://ftp.ensembl.org/pub/current_fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
wget http://ftp.ensembl.org/pub/current_gtf/homo_sapiens/Homo_sapiens.GRCh38.104.gtf.gz
```

##### Build a human-specific Dfam file

```bash
pip3 install --user h5py
wget https://raw.githubusercontent.com/Dfam-consortium/FamDB/master/famdb.py
chmod u+x famdb.py
wget https://www.dfam.org/releases/Dfam_3.3/families/Dfam.h5.gz
gunzip Dfam.h5.gz
./famdb.py -i Dfam.h5 lineage -a human
./famdb.py -i Dfam.h5 families -f hmm -a human > human_dfam.hmm
```

##### Prepare the human Dfam file for STAR-Fusion

```bash
docker run -v "$(pwd)":/data --rm trinityctat/starfusion \
hmmpress /data/human_dfam.hmm
```

##### Build the human CTAT genome lib

For this step the Ensembl gene transfer format (GTF) file was manually modified prior to running the CTAT genome lib building script, in order to convey that the MT-ATP8 and MT-ATP6 genes are encoded within a single overlapping transcript that, although detected by STAR-Fusion, does not represent a chimeric mitochondrial RNA. Similarly, GTF information for the MT-ND4l and Mt-ND4 genes was updated to reflect that they are normally expressed as a single transcript.

The custom GTF file is available in the `custom-GTFs` directory.

Uncompress the human reference genome and GTF files:

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