#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

usage() {
    printf "Usage: %s -i <input_folder> -o <output_folder> [-f]\n" "$0"
    printf "\nOptions:\n"
    printf "  -i <input_folder>   : Folder containing FASTQ files.\n"
    printf "  -o <output_folder>  : Folder to save FastQC results.\n"
    printf "  -f                  : Force reprocessing even if completion files exist.\n"
    exit 1
}

CPU_COUNT=8
FORCE_REPROCESSING=false

# Parse command-line arguments
while getopts ":i:o:f" opt; do
    case $opt in
    i)
        IN="$OPTARG"
        ;;
    o)
        OUT="$OPTARG"
        ;;
    f)
        FORCE_REPROCESSING=true
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

# Check if FastQC is installed
if ! command -v fastqc &>/dev/null; then
    printf "Error: FastQC is not installed or not in PATH.\n"
    exit 1
fi

mkdir -p "$OUT"

# Find all FASTQ files in the input folder
mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f)

# Process all FASTQ files with FastQC
for file in "${files[@]}"; do
    base_name=$(basename "$file")
    completion_file="${OUT}/${base_name}_fastqc_done.txt"

    # Check if the processing should be skipped
    if [ "$FORCE_REPROCESSING" = false ] && [ -f "$completion_file" ]; then
        printf "Skipping '%s' as it has already been processed.\n" "$base_name"
        continue
    fi

    printf "Processing file: %s\n" "$base_name"

    # Run FastQC
    fastqc -t "$CPU_COUNT" -o "$OUT" "$file"

    # Create a completion file to mark completion
    touch "$completion_file"
done

printf "FastQC analysis complete.\n"
