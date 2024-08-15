#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# Function to display usage
usage() {
    printf "Usage: %s -i <input_folder> -o <output_folder> -a <adapters_file> [-f]\n" "$0"
    printf "\nOptions:\n"
    printf "  -i <input_folder>   : Folder containing FASTQ files.\n"
    printf "  -o <output_folder>  : Folder to save processed files.\n"
    printf "  -a <adapters_file>  : File containing adapter sequences for Trimmomatic.\n"
    printf "  -f                  : Force reprocessing even if completion files exist.\n"
    exit 1
}

CPU_COUNT=8
FORCE_REPROCESSING=0

# Parse command-line arguments
while getopts ":i:o:a:f" opt; do
    case $opt in
    i)
        IN="$OPTARG"
        ;;
    o)
        OUT="$OPTARG"
        ;;
    a)
        ADAPTERS_FILE="$OPTARG"
        ;;
    f)
        FORCE_REPROCESSING=1
        ;;
    \?)
        printf "Invalid option -%s\n" "$OPTARG" >&2
        usage
        ;;
    esac
done

if [ -z "$IN" ] || [ -z "$OUT" ] || [ -z "$ADAPTERS_FILE" ]; then
    usage
fi

# Check if Trimmomatic is installed
if ! command -v trimmomatic &>/dev/null; then
    printf "Error: Trimmomatic is not installed or not in PATH.\n"
    exit 1
fi

mkdir -p "$OUT"

# Find all FASTQ files in the input folder
mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f)

declare -A paired_files

# Identify paired-end and single-end files
for file in "${files[@]}"; do
    printf "Checking file: %s\n" "$file"
    base_name=$(basename "$file")
    dir_name=$(dirname "$file")

    # Expected file name formats:
    # Paired-end: sample_1.fastq.gz and sample_2.fastq.gz
    # Single-end: sample.fastq.gz
    if [[ $base_name == *_1.fastq.gz ]]; then
        right_file="${dir_name}/${base_name/_1.fastq.gz/_2.fastq.gz}"
        if [ -f "$right_file" ]; then
            printf "Identified paired-end files: '%s' and '%s'\n" "$(basename -- "$file")" "$(basename -- "$right_file")"
            paired_files["$file"]="$right_file"
        else
            printf "Right file not found for '%s'. Marking as single-end.\n" "$(basename -- "$file")"
            paired_files["$file"]=""
        fi
    elif [[ $base_name == *_2.fastq.gz ]]; then
        left_file="${dir_name}/${base_name/_2.fastq.gz/_1.fastq.gz}"
        if [ ! -f "$left_file" ]; then
            printf "Orphaned _2.fastq.gz file: '%s'. Skipping.\n" "$base_name"
        fi
    else
        printf "Identified single-end file: '%s'\n" "$base_name"
        paired_files["$file"]=""
    fi
done

# Process paired-end and single-end files with Trimmomatic
for left_file in "${!paired_files[@]}"; do
    right_file=${paired_files[$left_file]}
    base_name=$(basename -- "$left_file")
    output_prefix=$(echo "$base_name" | sed 's/_1.fastq.gz//')
    completion_file="${OUT}/${output_prefix}_processed.txt"

    # Check if the processing should be skipped
    if [ -f "$completion_file" ] && [ "$FORCE_REPROCESSING" -eq 0 ]; then
        printf "Skipping '%s' as it has already been processed. Use -f to force reprocessing.\n" "$base_name"
        continue
    fi

    # Set output paths
    if [ -n "$right_file" ]; then
        # Paired-end processing
        out_left="${OUT}/${base_name}"
        out_right="${OUT}/${base_name/_1.fastq.gz/_2.fastq.gz}"

        printf "Processing paired-end files: %s and %s\n" "$base_name" "$(basename -- "$right_file")"
        trimmomatic PE -threads "$CPU_COUNT" \
            "$left_file" "$right_file" \
            "$out_left" /dev/null \
            "$out_right" /dev/null \
            ILLUMINACLIP:"$ADAPTERS_FILE":2:20:5:1:true \
            LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36
    else
        # Single-end processing
        out_single="${OUT}/${base_name}"

        printf "Processing single-end file: %s\n" "$base_name"
        trimmomatic SE -threads "$CPU_COUNT" \
            "$left_file" "$out_single" \
            ILLUMINACLIP:"$ADAPTERS_FILE":2:20:5:1:true \
            LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36
    fi

    # Create a completion file to mark completion
    touch "$completion_file"
done

printf "Trimming complete.\n"
