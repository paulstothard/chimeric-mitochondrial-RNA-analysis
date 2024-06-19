#!/bin/bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

if [ "$#" -ne 1 ]; then
    printf "Usage: %s <folder_name>\n" "$0"
    exit 1
fi

FOLDER_NAME="$1"

if [ ! -d "$FOLDER_NAME" ]; then
    printf "Error: Directory '%s' does not exist.\n" "$FOLDER_NAME"
    exit 1
fi

OUTPUT_FILE="${FOLDER_NAME}/fragment_counts.txt"

printf "file,million fragments\n" >"$OUTPUT_FILE"

declare -A file_checked

find "$FOLDER_NAME" -name "*.fastq.gz" -type f | sort | while IFS= read -r file; do
    fnx=$(basename -- "$file")
    fn="${fnx%.*.*}"

    # Check if this file is part of a pair (e.g., *_1.fastq.gz or *_2.fastq.gz)
    if [[ $fnx =~ _[12].fastq.gz ]]; then
        base_fn="${fn%_?}"
        if [ "${file_checked[$base_fn]}" == "yes" ]; then
            printf "Skipping file '%s' as its pair has been processed.\n" "$fnx"
            continue
        fi
        file_checked[$base_fn]="yes"
    fi

    printf "Processing file '%s'\n" "$fnx"

    count=$(printf "%.7f" "$(echo "$(zcat "$file" | wc -l) / 4000000" | bc -l)")

    printf "Count for file '%s' is '%s'\n" "$fnx" "$count"

    printf "%s,%s\n" "$fnx" "$count" >>"$OUTPUT_FILE"

done

printf "Processing complete. Results saved in '%s'.\n" "$OUTPUT_FILE"
