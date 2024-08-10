#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    printf "Usage: %s <accession_list_file> <output_folder> [--force]\n" "$0"
    exit 1
fi

if ! command -v fasterq-dump &>/dev/null; then
    printf "Error: fasterq-dump is not installed or not in PATH.\n"
    exit 1
fi

# Check if pigz is available
if command -v pigz &>/dev/null; then
    COMPRESSOR="pigz"
else
    COMPRESSOR="gzip"
fi

ACC_FILE="$1"
OUTPUT_FOLDER="$2"
FORCE=false

# Check for --force option
if [ "$#" -eq 3 ] && [ "$3" == "--force" ]; then
    FORCE=true
fi

mkdir -p "$OUTPUT_FOLDER"

while read -r acc_num; do
    paired_compressed_1="${OUTPUT_FOLDER}/${acc_num}_1.fastq.gz"
    paired_compressed_2="${OUTPUT_FOLDER}/${acc_num}_2.fastq.gz"
    single_compressed="${OUTPUT_FOLDER}/${acc_num}.fastq.gz"

    if [ "$FORCE" = false ]; then
        # Skip if both paired-end files are compressed or if the single-end file is compressed
        if { [ -f "$paired_compressed_1" ] && [ -f "$paired_compressed_2" ]; } || [ -f "$single_compressed" ]; then
            printf "Skipping %s as compressed output already exists.\n" "$acc_num"
            continue
        fi
    fi

    fasterq-dump "$acc_num" -p -O "$OUTPUT_FOLDER"

    # Check if paired-end files exist
    if [ -f "${OUTPUT_FOLDER}/${acc_num}_1.fastq" ] && [ -f "${OUTPUT_FOLDER}/${acc_num}_2.fastq" ]; then
        $COMPRESSOR "${OUTPUT_FOLDER}/${acc_num}_1.fastq"
        $COMPRESSOR "${OUTPUT_FOLDER}/${acc_num}_2.fastq"
    elif [ -f "${OUTPUT_FOLDER}/${acc_num}.fastq" ]; then
        # Compress single-end file
        $COMPRESSOR "${OUTPUT_FOLDER}/${acc_num}.fastq"
    else
        printf "Warning: No FASTQ files found for accession %s\n" "$acc_num"
    fi
done <"$ACC_FILE"

printf "Processing complete.\n"
