#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# Set the default number of threads
THREADS=8

# Function to show usage
usage() {
    printf "Usage: %s <folder_name> [threads]\n" "$0"
    printf "\n"
    printf "Arguments:\n"
    printf "  folder_name  Name of the folder containing the FASTQ files.\n"
    printf "  threads      Number of threads to use for parallel processing (default: 8).\n"
    exit 1
}

# Check the number of arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

FOLDER_NAME="$1"

# Check if a custom number of threads was provided
if [ "$#" -eq 2 ]; then
    THREADS="$2"
fi

if [ ! -d "$FOLDER_NAME" ]; then
    printf "Error: Directory '%s' does not exist.\n" "$FOLDER_NAME"
    exit 1
fi

OUTPUT_FILE="${FOLDER_NAME}/fragment_counts.txt"

printf "file,million fragments\n" >"$OUTPUT_FILE"

declare -A file_checked

process_file() {
    file="$1"
    fnx=$(basename -- "$file")
    fn="${fnx%.*.*}"

    # Check if this file is part of a pair (e.g., *_1.fastq.gz or *_2.fastq.gz)
    if [[ $fnx =~ _[12].fastq.gz ]]; then
        base_fn="${fn%_?}"
        if [ "${file_checked[$base_fn]}" == "yes" ]; then
            printf "Skipping file '%s' as its pair has been processed.\n" "$fnx"
            return
        fi
        file_checked[$base_fn]="yes"
    fi

    printf "Processing file '%s'\n" "$fnx"

    count=$(printf "%.7f" "$(echo "$(zcat "$file" | wc -l) / 4000000" | bc -l)")

    printf "Count for file '%s' is '%s'\n" "$fnx" "$count"

    printf "%s,%s\n" "$fnx" "$count" >>"$OUTPUT_FILE"
}

export -f process_file
export OUTPUT_FILE
export -A file_checked

find "$FOLDER_NAME" -name "*.fastq.gz" -type f | sort | parallel -j "$THREADS" process_file

printf "Processing complete. Results saved in '%s'.\n" "$OUTPUT_FILE"
