#!/bin/bash

# =============================================================================
# fasterq-dump wrapper script
# Usage: fastq_dump.sh <SRA_run_accession> <tmp_dir> <out_dir>
#
# Arguments:
#   $1 - RUN     : SRA run accession (e.g. SRR12345678)
#   $2 - tmp_dir : Temporary directory for fasterq-dump
#   $3 - out_dir : Output directory for downloaded FASTQ files
# =============================================================================

RUN=$1
TMP_DIR=$2
OUT_DIR=$3

for var in RUN TMP_DIR OUT_DIR; do
    eval val=\$$var
    if [ -z "$val" ]; then
        echo "ERROR: Missing argument '$var'"
        echo "Usage: $0 <SRA_run_accession> <tmp_dir> <out_dir>"
        exit 1
    fi
done

fasterq-dump \
    -t "$TMP_DIR" \
    --split-files \
    --include-technical \
    -e 10 \
    -O "$OUT_DIR" \
    "$RUN" \
    && pigz -p 10 "$OUT_DIR/${RUN}"*.fastq
