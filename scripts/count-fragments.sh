#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <folder_name>"
    exit 1
fi

FOLDER_NAME="$1"

if [ ! -d "$FOLDER_NAME" ]; then
    echo "Error: Directory '$FOLDER_NAME' does not exist."
    exit 1
fi

OUTPUT_FILE="${FOLDER_NAME}/fragment_counts.txt"

echo "file,million fragments" > "$OUTPUT_FILE"

declare -A file_checked

find "$FOLDER_NAME" -name "*.fastq.gz" -type f | sort | while IFS= read -r file; do
    fnx=$(basename -- "$file")
    fn="${fnx%.*.*}"

    # Check if this file is part of a pair (e.g., *_1.fastq.gz or *_2.fastq.gz)
    if [[ $fnx =~ _[12].fastq.gz ]]; then
        base_fn="${fn%_?}"
        if [ "${file_checked[$base_fn]}" == "yes" ]; then
            echo "Skipping file '$fnx' as its pair has been processed."
            continue
        fi
        file_checked[$base_fn]="yes"
    fi

    echo "Processing file '$fnx'"
    
    count=$(echo $(zcat "$file" | wc -l) / 4000000 | bc -l)
    
    echo "Count for file '$fnx' is '$count'"
    
    echo "$fnx,$count" >> "$OUTPUT_FILE"

done

echo "Processing complete. Results saved in '$OUTPUT_FILE'."
