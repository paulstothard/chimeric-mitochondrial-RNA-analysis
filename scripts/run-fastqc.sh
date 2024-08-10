#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
    printf "\nCaught SIGINT signal. Stopping...\n"
    exit 1
}

trap cleanup SIGINT

usage() {
    printf "Usage: %s -i <input_folder> -o <output_folder>\n" "$0"
    exit 1
}

CPU_COUNT=8

while getopts ":i:o:" opt; do
    case $opt in
    i)
        IN="$OPTARG"
        ;;
    o)
        OUT="$OPTARG"
        ;;
    \?)
        printf "Invalid option -%s\n" "$OPTARG" >&2
        usage
        ;;
    esac
done

if [ -z "$IN" ] || [ -z "$OUT" ]; then
    usage
fi

mkdir -p "$OUT"

mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f) # Find all FASTQ files

# Process all FASTQ files with FastQC
for file in "${files[@]}"; do
    base_name=$(basename "$file")
    printf "Processing file: %s\n" "$base_name"

    # Run FastQC
    fastqc -t "$CPU_COUNT" -o "$OUT" "$file"
done

printf "FastQC analysis complete.\n"
