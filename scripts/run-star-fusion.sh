#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
  printf "\nCaught SIGINT signal. Stopping...\n"
  # Stop all running Docker containers related to trinityctat/starfusion
  docker ps -q --filter ancestor=trinityctat/starfusion | xargs -r docker stop
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

declare -A paired_files

# Preprocess files to identify pairs and single-end files
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

# Process paired-end and single-end files
for left_file in "${!paired_files[@]}"; do
  right_file=${paired_files[$left_file]}
  fnx=$(basename -- "$left_file")
  fn=$(printf "%s" "$fnx" | cut -f 1 -d '.' | cut -f 1 -d '_') # Extract the common part of the filename for paired-end, dot for single-end

  if [ -d "${OUT}/${fn}" ]; then
    printf "Output already exists for '%s'\n" "$fnx"
    printf "Skipping\n"
    continue
  fi

  mkdir "${OUT}/${fn}"

  if [ -n "$right_file" ]; then
    printf "Processing paired-end files: %s and %s\n" "$fnx" "$(basename -- "$right_file")"
    docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
      /usr/local/src/STAR-Fusion/STAR-Fusion \
      --left_fq /data/"${left_file}" \
      --right_fq /data/"${right_file}" \
      --genome_lib_dir /data/"${REF}" \
      --no_remove_dups \
      --min_FFPM 0 \
      --CPU "$CPU_COUNT" \
      -O /data/"${OUT}/${fn}" | tee -a "${OUT}/${fn}/redirect_log.txt"
  else
    printf "Processing single-end file: %s\n" "$fnx"
    docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
      /usr/local/src/STAR-Fusion/STAR-Fusion \
      --left_fq /data/"${left_file}" \
      --genome_lib_dir /data/"${REF}" \
      --no_remove_dups \
      --min_FFPM 0 \
      --CPU "$CPU_COUNT" \
      -O /data/"${OUT}/${fn}" | tee -a "${OUT}/${fn}/redirect_log.txt"
  fi
done
