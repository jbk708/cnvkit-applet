#!/bin/bash
set -e -x -o pipefail

main() {
    echo "Starting CNVkit to THETA2 conversion at $(date)"
    echo "Applet version: 0.1.0"
    
    NUM_CORES=$(nproc)
    AVAILABLE_MEM=$(free -g | awk '/^Mem:/{print $2}')
    echo "Available resources: $NUM_CORES cores, ${AVAILABLE_MEM}GB memory"
    
    echo "Downloading input files..."
    dx-download-all-inputs
    
    # Handle array inputs (taking the first file in each array)
    TUMOR_CNS="${cnvkit_cns_path[0]}"
    REFERENCE_CNN="${reference_cnn_path[0]}"
    
    # Set up sample ID and log file
    SAMPLE_ID="${sample_id}"
    if [ -z "$SAMPLE_ID" ]; then
        # Extract sample ID from file name if not provided
        SAMPLE_ID=$(basename "${TUMOR_CNS%.*}" | sed 's/\.cns$//')
        echo "No sample ID provided, using extracted ID: ${SAMPLE_ID}"
    fi

    LOG_FILE="${SAMPLE_ID}.cnvkit-to-theta2.log"
    echo "Log file: $LOG_FILE"
    
    if [ -n "${tumor_vcf_path[0]}" ]; then
        TUMOR_VCF="${tumor_vcf_path[0]}"
        TUMOR_VCF_INDEX="${tumor_vcf_index_path[0]}"
        USE_VCF=true
        echo "Tumor VCF provided, will use for heterozygous SNP data"
        
        if [ ! -f "${TUMOR_VCF}.tbi" ]; then
            echo "Warning: VCF index file not found at ${TUMOR_VCF}.tbi" | tee -a "$LOG_FILE"
            echo "Creating index file..." | tee -a "$LOG_FILE"
            tabix -p vcf "$TUMOR_VCF" || {
                echo "Error: Failed to create index file for VCF" | tee -a "$LOG_FILE"
                exit 1
            }
        fi
    else
        USE_VCF=false
        echo "No tumor VCF provided, will proceed without heterozygous SNP data"
    fi
    
    {
        echo "==== CNVkit to THETA2 Conversion Log ===="
        echo "Date: $(date)"
        echo "Sample ID: $SAMPLE_ID"
        echo "TUMOR_CNS: $TUMOR_CNS"
        echo "REFERENCE_CNN: $REFERENCE_CNN"
        echo "Using $NUM_CORES CPU cores"
        if [ "$USE_VCF" = true ]; then
            echo "TUMOR_VCF: $TUMOR_VCF"
            echo "TUMOR_VCF_INDEX: ${TUMOR_VCF}.tbi"
            echo "VCF file size: $(du -h "$TUMOR_VCF" | cut -f1)"
        else
            echo "TUMOR_VCF: Not provided"
        fi
        echo "=== CNVkit Details ==="
        cnvkit.py version
        echo "=================================="
    } | tee "$LOG_FILE"
    
    echo "Converting CNVkit data to THETA2 format for tumor-only sample..." | tee -a "$LOG_FILE"
    
    # Build base command with output filename
    OUTPUT_FILE="${SAMPLE_ID}.interval_count"
    CNVKIT_CMD="cnvkit.py export theta '$TUMOR_CNS' --reference '$REFERENCE_CNN' -o '$OUTPUT_FILE'"
    
    if [ "$USE_VCF" = true ]; then
        echo "Converting CNS segments to THETA2 format with VCF data..." | tee -a "$LOG_FILE"
        echo "This step may take a while for whole-genome VCF files..." | tee -a "$LOG_FILE"
        CNVKIT_CMD="$CNVKIT_CMD -v '$TUMOR_VCF'"
    else
        echo "Converting CNS segments to THETA2 format without VCF data..." | tee -a "$LOG_FILE"
    fi
    
    eval "$CNVKIT_CMD" 2>&1 | tee -a "$LOG_FILE"
    
    # Handle the expected output files
    if [ -f "$OUTPUT_FILE" ]; then
        mv "$OUTPUT_FILE" "${SAMPLE_ID}.intervals"
    fi
    
    # Rename SNP-formatted files if they exist
    for file in tumor normal; do
        if [ -f "${SAMPLE_ID}.${file}.snp_formatted.txt" ]; then
            mv "${SAMPLE_ID}.${file}.snp_formatted.txt" "${SAMPLE_ID}.${file}.txt"
        fi
    done
    
    if [ ! -f "${SAMPLE_ID}.normal.txt" ]; then
        echo "Creating dummy normal file for tumor-only analysis..." | tee -a "$LOG_FILE"
        # Create a "normal" counterpart with neutral copy number (2) for all segments
        awk '{print $1, $2, $3, 1, 0.5}' "${SAMPLE_ID}.tumor.txt" > "${SAMPLE_ID}.normal.txt"
    else
        echo "Normal file already exists, skipping dummy file creation..." | tee -a "$LOG_FILE"
    fi
    
    echo "CNVkit to THETA2 conversion completed at $(date)" | tee -a "$LOG_FILE"
    
    echo "Uploading output files to DNAnexus..."
    
    for file in tumor normal; do
        if [ -f "${SAMPLE_ID}.${file}.txt" ]; then
            file_id=$(dx upload "${SAMPLE_ID}.${file}.txt" --brief)
            dx-jobutil-add-output "${file}_snp" "$file_id" --class=file
        fi
    done
    
    if [ -f "${SAMPLE_ID}.intervals" ]; then
        intervals_id=$(dx upload "${SAMPLE_ID}.intervals" --brief)
        dx-jobutil-add-output intervals "$intervals_id" --class=file
    fi
    
    log_id=$(dx upload "$LOG_FILE" --brief)
    dx-jobutil-add-output log_file "$log_id" --class=file
    
    echo "All files uploaded successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi 