#!/usr/bin/env bash

# Author: Paul Stothard
# Contact: stothard@ualberta.ca

cleanup() {
  printf "\nCaught SIGINT signal. Stopping...\n"
  docker ps -q --filter ancestor=trinityctat/starfusion | xargs -r docker stop
  exit 1
}

trap cleanup SIGINT

usage() {
  printf "Usage: %s -i <input_folder> -o <output_folder> -r <reference> [-p <1|2|both>] [-f]\n" "$0"
  exit 1
}

CPU_COUNT=8
PAIR_CHOICE="both" # Default to processing both _1 and _2 reads
FORCE_REPROCESSING=0

while getopts ":i:o:r:p:f" opt; do
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
  p)
    PAIR_CHOICE="$OPTARG"
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

if [ -z "$IN" ] || [ -z "$OUT" ] || [ -z "$REF" ]; then
  usage
fi

# Validate PAIR_CHOICE
if [[ "$PAIR_CHOICE" != "1" && "$PAIR_CHOICE" != "2" && "$PAIR_CHOICE" != "both" ]]; then
  printf "Invalid value for -p: %s. Choose '1', '2', or 'both'.\n" "$PAIR_CHOICE" >&2
  usage
fi

mkdir -p "$OUT"

mapfile -t files < <(find "$IN" -name "*.fastq.gz" -type f)

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

# Process paired-end and single-end files with STAR, filter the Chimeric.out.junction file for MT, and run STAR-Fusion
for left_file in "${!paired_files[@]}"; do
  right_file=${paired_files[$left_file]}
  fnx=$(basename -- "$left_file")
  fn=$(printf "%s" "$fnx" | cut -f 1 -d '.' | cut -f 1 -d '_')

  completion_file="${OUT}/${fn}/processing_complete.txt"

  # Check if the processing should be skipped
  if [ -f "$completion_file" ] && [ "$FORCE_REPROCESSING" -eq 0 ]; then
    printf "Processing already completed for '%s'. Skipping.\n" "$fn"
    continue
  fi

  mkdir -p "${OUT}/${fn}"

  if [[ "$PAIR_CHOICE" == "1" ]]; then
    right_file=""
  elif [[ "$PAIR_CHOICE" == "2" ]]; then
    left_file="$right_file"
    right_file=""
  fi

  printf "Processing file(s) with STAR: %s %s\n" "$fnx" "${right_file:+and $(basename -- "$right_file")}"

  # STAR command for paired-end or single-end reads
  docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
    /usr/local/bin/STAR \
    --genomeDir /data/"${REF}"/ref_genome.fa.star.idx \
    --readFilesIn /data/"${left_file}" ${right_file:+/data/"${right_file}"} \
    --outFileNamePrefix /data/"${OUT}/${fn}/" \
    --outReadsUnmapped None \
    --twopassMode Basic \
    --readFilesCommand "gunzip -c" \
    --outSAMstrandField intronMotif \
    --outSAMunmapped Within \
    --chimSegmentMin 12 \
    --chimJunctionOverhangMin 8 \
    --chimOutJunctionFormat 1 \
    --alignSJDBoverhangMin 10 \
    --alignMatesGapMax 100000 \
    --alignIntronMax 100 \
    --alignSJstitchMismatchNmax 5 -1 5 5 \
    --outSAMattrRGline ID:GRPundef \
    --chimMultimapScoreRange 3 \
    --chimScoreJunctionNonGTAG -1 \
    --chimMultimapNmax 20 \
    --chimNonchimScoreDropMin 10 \
    --alignInsertionFlush Right \
    --alignSplicedMateMapLminOverLmate 0 \
    --alignSplicedMateMapLmin 30 \
    --runThreadN "$CPU_COUNT" \
    --quantMode GeneCounts | tee -a "${OUT}/${fn}/STAR_redirect_log.txt"

  # Check if STAR was successful
  if [ $? -eq 0 ]; then
    # Filter the Chimeric.out.junction file for MT junctions and keep the header and comments
    awk '/^#/ || (NR==1 || (($1 == "MT" || $1 == "mt") && ($4 == "MT" || $4 == "mt")))' "${OUT}/${fn}/Chimeric.out.junction" >"${OUT}/${fn}/filtered_Chimeric.out.junction"

    # Run STAR-Fusion using the filtered Chimeric.out.junction file in the same output folder
    docker run -v "$(pwd)":/data --rm -u "$(id -u)":"$(id -g)" trinityctat/starfusion \
      /usr/local/src/STAR-Fusion/STAR-Fusion \
      --genome_lib_dir /data/"${REF}" \
      -J /data/"${OUT}/${fn}/filtered_Chimeric.out.junction" \
      --no_remove_dups \
      --min_FFPM 0 \
      --CPU "$CPU_COUNT" \
      -O /data/"${OUT}/${fn}" | tee -a "${OUT}/${fn}/STAR-Fusion_redirect_log.txt"

    # Check if STAR-Fusion was successful
    if [ $? -eq 0 ]; then
      # Create a completion file to indicate processing is done
      touch "$completion_file"
      printf "Processing completed successfully for '%s'.\n" "$fn"
    else
      printf "STAR-Fusion failed for '%s'.\n" "$fn" >&2
    fi
  else
    printf "STAR failed for '%s'.\n" "$fn" >&2
  fi
done

printf "Processing complete.\n"
