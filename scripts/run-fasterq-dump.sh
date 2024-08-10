#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

if [ "$#" -ne 2 ]; then
    printf "Usage: %s <accession_list_file> <output_folder>\n" "$0"
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

mkdir -p "$OUTPUT_FOLDER"

while read -r acc_num; do
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
