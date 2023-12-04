#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <accession_list_file> <output_folder>"
    exit 1
fi

if ! command -v fasterq-dump &> /dev/null; then
    echo "Error: fasterq-dump is not installed or not in PATH."
    exit 1
fi

ACC_FILE="$1"
OUTPUT_FOLDER="$2"

mkdir -p "$OUTPUT_FOLDER"

while read -r acc_num; do
    fasterq-dump "$acc_num" -p -O "$OUTPUT_FOLDER"
    gzip "${OUTPUT_FOLDER}/${acc_num}.fastq"
done < "$ACC_FILE"

echo "Processing complete."
