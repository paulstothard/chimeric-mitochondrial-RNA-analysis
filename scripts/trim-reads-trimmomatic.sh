#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
    printf "\nCaught SIGINT signal. Stopping...\n"
    exit 1
}

trap cleanup SIGINT

usage() {
    printf "Usage: %s -i <input_folder> -o <output_folder> -a <adapters_file>\n" "$0"
    exit 1
}

CPU_COUNT=8

while getopts ":i:o:a:" opt; do
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
    \?)
        printf "Invalid option -%s\n" "$OPTARG" >&2
        usage
        ;;
    esac
done

if [ -z "$IN" ] || [ -z "$OUT" ] || [ -z "$ADAPTERS_FILE" ]; then
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

# Process paired-end and single-end files with Trimmomatic
for left_file in "${!paired_files[@]}"; do
    right_file=${paired_files[$left_file]}
    base_name=$(basename -- "$left_file")

    # Set output paths
    out_left="${OUT}/${base_name}"
    out_right="${OUT}/${base_name/_1.fastq.gz/_2.fastq.gz}"

    if [ -n "$right_file" ]; then
        # Paired-end processing
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
done

printf "Trimming complete.\n"
