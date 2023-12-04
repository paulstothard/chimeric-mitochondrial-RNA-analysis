#!/bin/bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
    echo "Caught SIGINT signal. Stopping..."
    # Stop the Docker container if it's running
    docker stop $(docker ps -q --filter ancestor=trinityctat/starfusion) 2>/dev/null
    exit 1
}

trap cleanup SIGINT

usage() {
    echo "Usage: $0 -i <input_folder> -o <output_folder> -r <reference>"
    exit 1
}

CPU_COUNT=8

while getopts ":i:o:r:" opt; do
  case $opt in
    i) IN="$OPTARG"
    ;;
    o) OUT="$OPTARG"
    ;;
    r) REF="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
       usage
    ;;
  esac
done

if [ -z "$IN" ] || [ -z "$OUT" ] || [ -z "$REF" ]; then
    usage
fi

mkdir -p "$OUT"

mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f)  # Find all FASTQ files

for file in "${files[@]}"; do
  paired_end=false
  right_file=""
  if [[ $file == *_1.fastq.gz ]]; then
    right_file="${file/_1.fastq.gz/_2.fastq.gz}"  # Replace _1 with _2 to get the right file
    if [ -f "$right_file" ]; then
      paired_end=true
      echo "Processing paired-end pair: '$(basename -- "$file")' and '$(basename -- "$right_file")'"
    fi
  fi

  if [[ $paired_end = false && $file != *_2.fastq.gz ]]; then
    echo "Processing single-end file: '$(basename -- "$file")'"
  fi

  fnx=$(basename -- "$file")
  fn=$(echo "$fnx" | cut -f 1 -d '.')  # Extract the common part of the filename

  if [ -d "${OUT}/${fn}" ]; then
     echo "Output already exists for '$fnx'"
     echo "Skipping"
     continue
  fi
  
  mkdir "${OUT}/${fn}"
  
  if [ "$paired_end" = true ]; then
    # Paired-end specific Docker command
    docker run -v "$(pwd)":/data --rm -u $(id -u):$(id -g) trinityctat/starfusion \
    /usr/local/src/STAR-Fusion/STAR-Fusion \
    --left_fq /data/"${IN}"/"${fnx}" \
    --right_fq /data/"${IN}"/"$(basename -- "$right_file")" \
    --genome_lib_dir /data/"${REF}" \
    --no_remove_dups \
    --min_FFPM 0 \
    --CPU "$CPU_COUNT" \
    -O /data/"${OUT}"/"${fn}" | tee -a "${OUT}"/"${fn}"/redirect_log.txt
  else
    # Single-end specific Docker command
    docker run -v "$(pwd)":/data --rm -u $(id -u):$(id -g) trinityctat/starfusion \
    /usr/local/src/STAR-Fusion/STAR-Fusion \
    --left_fq /data/"${IN}"/"${fnx}" \
    --genome_lib_dir /data/"${REF}" \
    --no_remove_dups \
    --min_FFPM 0 \
    --CPU "$CPU_COUNT" \
    -O /data/"${OUT}"/"${fn}" | tee -a "${OUT}"/"${fn}"/redirect_log.txt
  fi

done