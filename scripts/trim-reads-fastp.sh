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

declare -A paired_files

# Identify paired and single-end files
for file in "${files[@]}"; do
    printf "Checking file: %s\n" "$file"
    base_name=$(basename "$file")
    dir_name=$(dirname "$file")
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
done

printf "Trimming complete.\n"
