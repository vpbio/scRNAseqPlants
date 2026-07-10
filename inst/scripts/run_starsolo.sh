#!/bin/sh

# =============================================================================
# STARsolo alignment script
# Usage: script.sh <barcode_umi_reads> <cdna_reads> <genome_keyword> <chemistry_version> <output_prefix>
#
# Arguments:
#   $1 - barcode_umi_reads : R1 fastq (barcodes + UMI)
#   $2 - cdna_reads        : R2 fastq (cDNA insert)
#   $3 - genome_keyword    : Genome keyword (at | os | at+os | at+gfp | at+hs | at+mm)
#   $4 - chemistry_version : 10x chemistry version (v2 | v3 | ds)
#   $5 - output_prefix     : Output path prefix in the form <study>/<sample_name>
#                            e.g. my_study/sample_01
#   $6 - extra options for STAR
# =============================================================================

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================

# All env vars (GENOME_INDEX_*, CELLRANGER_LOCATION, STAR_BIN) are expected
# to be set in the caller's environment (e.g. loaded via dotenv in R before system2())

barcode_umi_reads=$1
cdna_reads=$2
genome_keyword=$3
chemistry_version=$4
output_prefix=$5       # absolute path, e.g. "/data/my_study/sample_01"
Extra_options=$6

# =============================================================================
# REFERENCE GENOME SELECTION
# =============================================================================

case "$genome_keyword" in
    at)
        genome_index="$GENOME_INDEX_AT"
        mt_name="NC_037304.1"
        ;;
    os)
        genome_index="$GENOME_INDEX_OS"
        mt_name="NC_011033.1"
        ;;
    at+os)
        genome_index="$GENOME_INDEX_AT_OS"
        mt_name="NC_037304.1 NC_011033.1"
        ;;
    at+gfp)
        genome_index="$GENOME_INDEX_AT_GFP"
        mt_name="NC_037304.1"
        ;;
    at+hs)
        genome_index="$GENOME_INDEX_AT_HS"
        mt_name="NC_037304.1"
        ;;
    at+mm)
        genome_index="$GENOME_INDEX_AT_MM"
        mt_name="NC_037304.1"
        ;;
    *)
        echo "ERROR: Unknown genome keyword '$genome_keyword'"
        echo "Available options: at | os | at+os | at+gfp | at+hs | at+mm"
        exit 1
        ;;
esac

echo "Using genome   : $genome_keyword"
echo "Genome index   : $genome_index"
echo "MT contig name : $mt_name"

# =============================================================================
# CHEMISTRY VERSION SELECTION (whitelist + UMI length)
# =============================================================================

case "$chemistry_version" in
    v2)
        whitelist="$CELLRANGER_LOCATION/lib/python/cellranger/barcodes/737K-august-2016.txt"
        CBstart=1
        CBlen=16
        UMIstart=17
        UMIlen=10
        ;;
    v3)
        whitelist="$CELLRANGER_LOCATION/lib/python/cellranger/barcodes/3M-february-2018.txt"
        CBstart=1
        CBlen=16
        UMIstart=17
        UMIlen=12
        ;;
    ds)
        whitelist="None"
        CBstart=1
        CBlen=12
        UMIstart=13
        UMIlen=8
        Extra_options="--outFilterMatchNminOverLread 0 --outFilterMatchNmin 30 --outFilterScoreMinOverLread 0"
        ;;
    *)
        echo "ERROR: Unknown chemistry version '$chemistry_version'"
        echo "Available options: v2 | v3 | ds"
        exit 1
        ;;
esac

echo "Chemistry      : $chemistry_version"
echo "Whitelist      : $whitelist"
echo "UMI length     : $UMIlen"

# =============================================================================
# VALIDATE INPUTS
# =============================================================================

for var in barcode_umi_reads cdna_reads output_prefix genome_keyword chemistry_version; do
    eval val=\$$var
    if [ -z "$val" ]; then
        echo "ERROR: Missing argument '$var'"
        echo "Usage: $0 <barcode_umi_reads> <cdna_reads> <genome_keyword> <chemistry_version> <output_prefix>"
        exit 1
    fi
done

if [ ! -d "$genome_index" ]; then
    echo "ERROR: Genome index directory not found: $genome_index"
    exit 1
fi

mkdir -p "$output_prefix"

# =============================================================================
# RUN STARsolo
# =============================================================================

echo "Starting STARsolo alignment..."
echo "Output prefix  : $output_prefix"

"$STAR_BIN" \
    --runMode alignReads \
    --runThreadN 20 \
    --genomeDir "$genome_index" \
    --genomeLoad LoadAndRemove \
    --genomeChrSetMitochondrial "$mt_name" \
    --readFilesIn "$cdna_reads" "$barcode_umi_reads" \
    --readFilesCommand zcat \
    --clipAdapterType CellRanger4 \
    --soloType CB_UMI_Simple \
    --soloCBwhitelist "$whitelist" \
    --soloCBmatchWLtype 1MM_multi_Nbase_pseudocounts \
    --soloCBstart $CBstart \
    --soloCBlen $CBlen \
    --soloUMIstart $UMIstart \
    --soloUMIlen $UMIlen \
    --soloBarcodeReadLength 0 \
    --soloUMIdedup 1MM_CR \
    --soloFeatures Gene Velocyto \
    --soloCellFilter EmptyDrops_CR \
    --outSAMtype None \
    --outFileNamePrefix "$output_prefix" $Extra_options

# =============================================================================
# EXIT STATUS CHECK
# =============================================================================

if [ $? -eq 0 ]; then
    echo "STARsolo alignment completed successfully."
    echo "Output in: $output_prefix/"
else
    echo "ERROR: STARsolo alignment failed. Check logs in $output_prefix/"
    exit 1
fi
