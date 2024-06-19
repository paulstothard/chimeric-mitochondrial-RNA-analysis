#!/bin/bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

if [ "$#" -ne 2 ]; then
    printf "Usage: %s <input_folder> <output_folder>\n" "$0"
    exit 1
fi

input_folder="$1"
output_folder="$2"

if [ ! -d "$input_folder" ]; then
    printf "Error: Input folder '%s' does not exist.\n" "$input_folder"
    exit 1
fi

mkdir -p "$output_folder"

for subfolder in "$input_folder"/*; do
    if [ -d "$subfolder" ]; then

        sample=$(basename "$subfolder")

        # Define file paths
        declare -A files
        files["star-fusion.fusion_candidates.preliminary"]="$subfolder/star-fusion.preliminary/star-fusion.fusion_candidates.preliminary"
        files["Log.final.out"]="$subfolder/Log.final.out"
        files["ReadsPerGene.out.tab"]="$subfolder/ReadsPerGene.out.tab"

        for file in "${!files[@]}"; do
            if [ -f "${files[$file]}" ]; then
                cp "${files[$file]}" "$output_folder/${sample}.${file}"
            else
                printf "Warning: File '%s' not found in '%s'.\n" "$file" "$subfolder"
            fi
        done
    fi
done

printf "Processing complete.\n"
