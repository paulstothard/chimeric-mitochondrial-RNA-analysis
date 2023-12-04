#!/bin/bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_folder> <output_folder>"
    exit 1
fi

input_folder="$1"
output_folder="$2"

if [ ! -d "$input_folder" ]; then
    echo "Error: Input folder '$input_folder' does not exist."
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
                echo "Warning: File '$file' not found in '$subfolder'."
            fi
        done
    fi
done

echo "Processing complete."
