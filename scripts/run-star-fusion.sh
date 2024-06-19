#!/bin/bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
  printf "Caught SIGINT signal. Stopping...\n"
  # Stop the Docker container if it's running
  docker stop "$(docker ps -q --filter ancestor=trinityctat/starfusion)" 2>/dev/null
  exit 1
}

trap cleanup SIGINT

usage() {
  printf "Usage: %s -i <input_folder> -o <output_folder> -r <reference>\n" "$0"
  exit 1
}

CPU_COUNT=8

while getopts ":i:o:r:" opt; do
  case $opt in
  i)
    IN="$OPTARG"
    ;;
  o)
    OUT="$OPTARG"
    ;;
  r)
    REF="$OPTARG"
    ;;
  \?)
    printf "Invalid option -%s\n" "$OPTARG" >&2
    usage
    ;;
  esac
done

if [ -z "$IN" ] || [ -z "$OUT" ] || [ -z "$REF" ]; then
  usage
fi

mkdir -p "$OUT"

mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f) # Find all FASTQ files

for file in "${files[@]}"; do
  paired_end=false
  right_file=""
  if [[ $file == *_1.fastq.gz ]]; then
    right_file="${file/_1.fastq.gz/_2.fastq.gz}" # Replace _1 with _2 to get the right file
    if [ -f "$right_file" ]; then
      paired_end=true
      printf "Processing paired-end pair: '%s' and '%s'\n" "$(basename -- "$file")" "$(basename -- "$right_file")"
    fi
  fi

  if [[ $paired_end = false && $file != *_2.fastq.gz ]]; then
    printf "Processing single-end file: '%s'\n" "$(basename -- "$file")"
  fi

  fnx=$(basename -- "$file")
  fn=$(printf "%s" "$fnx" | cut -f 1 -d '.') # Extract the common part of the filename

  if [ -d "${OUT}/${fn}" ]; then
    printf "Output already exists for '%s'\n" "$fnx"
    printf "Skipping\n"
    continue
  fi

  mkdir "${OUT}/${fn}"

  if [ "$paired_end" = true ]; then
    # Paired-end specific Docker command
    docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
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
    docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
      /usr/local/src/STAR-Fusion/STAR-Fusion \
      --left_fq /data/"${IN}"/"${fnx}" \
      --genome_lib_dir /data/"${REF}" \
      --no_remove_dups \
      --min_FFPM 0 \
      --CPU "$CPU_COUNT" \
      -O /data/"${OUT}"/"${fn}" | tee -a "${OUT}"/"${fn}"/redirect_log.txt
  fi

done
