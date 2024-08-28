#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

# Function to display usage
usage() {
    printf "Usage: %s -i <input_folder> -o <output_folder> [-f]\n" "$0"
    printf "\nOptions:\n"
    printf "  -i <input_folder>   : Folder containing FASTQ files.\n"
    printf "  -o <output_folder>  : Folder to save processed files and reports.\n"
    printf "  -f                  : Force reprocessing even if completion files exist.\n"
    exit 1
}

CPU_COUNT=8
FORCE_REPROCESSING=0

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
        FORCE_REPROCESSING=1
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

# Check if Fastp is installed
if ! command -v fastp &>/dev/null; then
    printf "Error: Fastp is not installed or not in PATH.\n"
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

# Process paired-end and single-end files with Fastp
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
        out_left="${OUT}/${output_prefix}_1.fastq.gz"
        out_right="${OUT}/${output_prefix}_2.fastq.gz"
        report="${OUT}/${output_prefix}_report.html"
        json_report="${OUT}/${output_prefix}_report.json"

        printf "Processing paired-end files: %s and %s\n" "$base_name" "$(basename -- "$right_file")"
        fastp -i "$left_file" -I "$right_file" -o "$out_left" -O "$out_right" -h "$report" -j "$json_report" -w "$CPU_COUNT"
    else
        # Single-end processing
        out_single="${OUT}/${output_prefix}.fastq.gz"
        report="${OUT}/${output_prefix}_report.html"
        json_report="${OUT}/${output_prefix}_report.json"

        printf "Processing single-end file: %s\n" "$base_name"
        fastp -i "$left_file" -o "$out_single" -h "$report" -j "$json_report" -w "$CPU_COUNT"
    fi

    # Check if Fastp was successful before creating the completion file
    if [ $? -eq 0 ]; then
        touch "$completion_file"
        printf "Processing completed successfully for '%s'.\n" "$base_name"
    else
        printf "Fastp failed for '%s'.\n" "$base_name" >&2
    fi
done

printf "Trimming complete.\n"
