#!/bin/bash

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

ACC_FILE="$1"
OUTPUT_FOLDER="$2"

mkdir -p "$OUTPUT_FOLDER"

while read -r acc_num; do
    fasterq-dump "$acc_num" -p -O "$OUTPUT_FOLDER"
    gzip "${OUTPUT_FOLDER}/${acc_num}.fastq"
done <"$ACC_FILE"

printf "Processing complete.\n"
