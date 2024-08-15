#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# Set the default number of threads
THREADS=8
FORCE_REPROCESSING=0

# Function to show usage
usage() {
    printf "Usage: %s <folder_name> [threads] [-f]\n" "$0"
    printf "\nArguments:\n"
    printf "  folder_name  Name of the folder containing the FASTQ files.\n"
    printf "  threads      Number of threads to use for parallel processing (default: 8).\n"
    printf "  -f           Force reprocessing by deleting the output file and job log.\n"
    exit 1
}

# Parse command-line arguments
while getopts ":f" opt; do
    case $opt in
    f)
        FORCE_REPROCESSING=1
        ;;
    \?)
        printf "Invalid option -%s\n" "$OPTARG" >&2
        usage
        ;;
    esac
done

shift $((OPTIND - 1))

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
JOBLOG_FILE="${FOLDER_NAME}/parallel_joblog.txt"

# If force reprocessing is requested, delete the output file and job log
if [ "$FORCE_REPROCESSING" -eq 1 ]; then
    printf "Force reprocessing enabled. Deleting existing output and job log files.\n"
    rm -f "$OUTPUT_FILE" "$JOBLOG_FILE"
fi

# Initialize output file if it doesn't exist
if [ ! -f "$OUTPUT_FILE" ]; then
    printf "file,million fragments\n" >"$OUTPUT_FILE"
fi

process_file() {
    file="$1"
    fnx=$(basename -- "$file")

    printf "Processing file '%s'\n" "$fnx"

    count=$(printf "%.7f" "$(echo "$(zcat "$file" | wc -l) / 4000000" | bc -l)")

    printf "Count for file '%s' is '%s'\n" "$fnx" "$count"

    printf "%s,%s\n" "$fnx" "$count" >>"$OUTPUT_FILE"
}

export -f process_file
export OUTPUT_FILE

# Using --joblog to track processed jobs and avoid reprocessing
find "$FOLDER_NAME" -name "*.fastq.gz" -type f | sort | parallel --joblog "$JOBLOG_FILE" -j "$THREADS" process_file

printf "Processing complete. Results saved in '%s'.\n" "$OUTPUT_FILE"

# Expected FASTQ file naming conventions:
# Paired-end reads: sample_1.fastq.gz and sample_2.fastq.gz
# Single-end reads: sample.fastq.gz
