# CNVkit to THETA2 Converter Applet

This DNAnexus applet converts CNVkit output files (.cns) to the format required by THETA2 for tumor heterogeneity analysis. It is specifically designed for tumor-only samples (no paired normal).

## Input

The applet requires the following inputs:

- **Tumor CNS file**: The segmented copy number file from CNVkit (.cns)
- **Reference CNN file**: CNVkit reference file (.cnn)
- **Tumor VCF file** (optional): VCF file containing SNPs for the tumor sample (used to extract heterozygous SNP information)
- **Sample ID** (optional): A sample identifier to be used in output filenames. If not provided, it will be extracted from the input filenames.

## Output

The applet produces:

- **THETA2 Input Files**: An array of files ready for THETA2 analysis, including:
  - A tumor input file converted from the CNVkit output (with SNP data from VCF if provided)
  - A generated dummy normal file for tumor-only analysis
  - A README file explaining how to use the outputs with THETA2
- **Log File**: A detailed log of the conversion process

## Implementation Details

This applet uses the etal/cnvkit Docker image to:

1. Convert CNVkit segmentation files to THETA2 format using `cnvkit.py export theta` 
   - With VCF data and reference if a VCF file is provided
   - With only reference data if no VCF file is provided
2. Generate a dummy normal file with neutral copy number for all segments (for tumor-only analysis)

## Requirements

The applet requires:
- Internet access to pull the Docker image
- Docker installed in the execution environment

## Usage Example

### With VCF file:
```
dx run cnvkit_to_theta2 \
  -icnvkit_cns=path/to/sample.cns \
  -ireference_cnn=path/to/reference.cnn \
  -itumor_vcf=path/to/sample.vcf \
  -isample_id=SAMPLE_ID
```

### Without VCF file:
```
dx run cnvkit_to_theta2 \
  -icnvkit_cns=path/to/sample.cns \
  -ireference_cnn=path/to/reference.cnn \
  -isample_id=SAMPLE_ID
```

For tumor-only samples, the applet creates a dummy normal file with neutral copy numbers that can be used with THETA2. 