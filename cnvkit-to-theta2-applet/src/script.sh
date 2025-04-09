#!/bin/bash
set -e -x -o pipefail

main() {
    # Log start time and script version
    echo "Starting CNVkit to THETA2 conversion at $(date)"
    echo "Applet version: 0.1.0"
    
    # Pull the CNVkit Docker image
    echo "Pulling CNVkit Docker image..."
    docker pull etal/cnvkit:latest
    
    # Download input files from DNAnexus
    echo "Downloading input files..."
    dx-download-all-inputs
    
    # Create output directories
    mkdir -p out/theta2_input out/log_file
    
    # Set variable names to match expected format
    # Handle array inputs (taking the first file in each array)
    TUMOR_CNS="${cnvkit_cns_path[0]}"
    REFERENCE_CNN="${reference_cnn_path[0]}"
    
    # Check if tumor_vcf was provided (it's optional)
    if [ -n "${tumor_vcf_path[0]}" ]; then
        TUMOR_VCF="${tumor_vcf_path[0]}"
        USE_VCF=true
        echo "Tumor VCF provided, will use for heterozygous SNP data"
    else
        USE_VCF=false
        echo "No tumor VCF provided, will proceed without heterozygous SNP data"
    fi
    
    # Determine sample ID
    SAMPLE_ID="${sample_id}"
    if [ -z "$SAMPLE_ID" ]; then
        # Extract sample ID from file name if not provided
        SAMPLE_ID=$(basename "${TUMOR_CNS%.*}" | sed 's/\.cns$//')
        echo "No sample ID provided, using extracted ID: ${SAMPLE_ID}"
    fi

    # Set up log file
    LOG_FILE="$SAMPLE_ID.cnvkit-to-theta2.log"
    echo "Log file: $LOG_FILE"
    
    # Log version and configuration details
    {
        echo "==== CNVkit to THETA2 Conversion Log ===="
        echo "Date: $(date)"
        echo "Sample ID: $SAMPLE_ID"
        echo "TUMOR_CNS: $TUMOR_CNS"
        echo "REFERENCE_CNN: $REFERENCE_CNN"
        if [ "$USE_VCF" = true ]; then
            echo "TUMOR_VCF: $TUMOR_VCF"
        else
            echo "TUMOR_VCF: Not provided"
        fi
        echo "=== Docker and CNVkit Details ==="
        docker run --rm etal/cnvkit:latest cnvkit.py version
        echo "=================================="
    } | tee "$LOG_FILE"
    
    echo "Converting CNVkit data to THETA2 format for tumor-only sample..." | tee -a "$LOG_FILE"
    
    # Prepare the command based on whether VCF is available
    if [ "$USE_VCF" = true ]; then
        echo "Converting CNS segments to THETA2 format with VCF data..." | tee -a "$LOG_FILE"
        docker run --rm -v "${PWD}:/data" etal/cnvkit:latest bash -c "cd /data && \
            cnvkit.py export theta \"$TUMOR_CNS\" --reference \"$REFERENCE_CNN\" -v \"$TUMOR_VCF\" \
            -o \"${SAMPLE_ID}.theta2.input\"" \
            2>&1 | tee -a "$LOG_FILE"
    else
        echo "Converting CNS segments to THETA2 format without VCF data..." | tee -a "$LOG_FILE"
        docker run --rm -v "${PWD}:/data" etal/cnvkit:latest bash -c "cd /data && \
            cnvkit.py export theta \"$TUMOR_CNS\" --reference \"$REFERENCE_CNN\" \
            -o \"${SAMPLE_ID}.theta2.input\"" \
            2>&1 | tee -a "$LOG_FILE"
    fi
    
    # For tumor-only mode, we need to create a dummy normal file
    # THETA2 expects a paired tumor-normal, but we can work around this
    echo "Creating dummy normal file for tumor-only analysis..." | tee -a "$LOG_FILE"
    
    # Get the number of segments for creating a matching dummy normal file
    SEGMENT_COUNT=$(wc -l < "${SAMPLE_ID}.theta2.input")
    
    # Create a "normal" counterpart with neutral copy number (2) for all segments
    awk '{print $1, $2, $3, 1, 0.5}' "${SAMPLE_ID}.theta2.input" > "${SAMPLE_ID}.normal.theta2.input"
    
    # Move output files to the correct output directories
    mv "${SAMPLE_ID}.theta2.input" "out/theta2_input/${SAMPLE_ID}.tumor.theta2.input"
    mv "${SAMPLE_ID}.normal.theta2.input" "out/theta2_input/${SAMPLE_ID}.normal.theta2.input"
    mv "$LOG_FILE" "out/log_file/$LOG_FILE"
    
    # Create a README file explaining the output
    cat > "out/theta2_input/README.txt" << EOF
THETA2 Input Files for Sample: ${SAMPLE_ID}

This directory contains input files prepared for THetA2 analysis:
- ${SAMPLE_ID}.tumor.theta2.input: Converted tumor segments from CNVkit$([ "$USE_VCF" = true ] && echo " with SNP data from VCF" || echo "")
- ${SAMPLE_ID}.normal.theta2.input: Generated dummy normal file for tumor-only analysis

For tumor-only analysis with THetA2, a dummy normal file was created with
neutral copy number (LogR=0, BAF=0.5) for all segments.

These files can be used with THetA2 as follows:
  RunTHetA [tumor_file] --TUMOR_FILE [normal_file] --NORMAL_FILE --NUM_PROCESSES [processes] --DIR [output_dir]
EOF
    
    mv "out/theta2_input/README.txt" "out/theta2_input/${SAMPLE_ID}.README.txt"
    
    # Upload outputs to DNAnexus
    dx-upload-all-outputs
    
    echo "CNVkit to THETA2 conversion completed at $(date)" | tee -a "out/log_file/$LOG_FILE"
}

# Execute the main function
main 