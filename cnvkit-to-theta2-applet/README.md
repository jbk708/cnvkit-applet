# CNVkit to THETA2 Converter Applet

This DNAnexus applet converts CNVkit output files (.cns) to the format required by THETA2 for tumor heterogeneity analysis. It is specifically designed for tumor-only samples (no paired normal).

## Input

The applet requires the following inputs:

- **Tumor CNS file**: The segmented copy number file from CNVkit (.cns)
- **Reference CNN file**: CNVkit reference file (.cnn)
- **Tumor VCF file** (optional): VCF file containing SNPs for the tumor sample (used to extract heterozygous SNP information)
- **Tumor VCF Index file** (optional): Tabix index file for the tumor VCF (.tbi)
- **Sample ID** (optional): A sample identifier to be used in output filenames. If not provided, it will be extracted from the input filenames.

## Output

The applet produces the following files:

- **Intervals File** (*.intervals): Contains the genomic intervals for THETA2 analysis
- **Tumor SNP File** (*.tumor.txt): Contains tumor SNP allele counts for BAF analysis (only produced if VCF is provided)
- **Normal SNP File** (*.normal.txt): Contains normal SNP allele counts for BAF analysis (only produced if VCF is provided)
- **Log File** (*.cnvkit-to-theta2.log): Detailed log of the conversion process

## Implementation Details

This applet uses CNVkit to:

1. Convert CNVkit segmentation files to THETA2 format using `cnvkit.py export theta` 
   - With VCF data and reference if a VCF file is provided
   - With only reference data if no VCF file is provided
2. Generate SNP allele count files if a VCF is provided
3. Create a dummy normal file with neutral copy number for all segments (for tumor-only analysis)

## Requirements

The applet requires:
- Python 3
- CNVkit 0.9.10
- Tabix for VCF indexing
- Pandas 1.5.3
- NumPy 1.24.3

## Usage Example

### With VCF file:
```
dx run cnvkit_to_theta2 \
  -icnvkit_cns=path/to/sample.cns \
  -ireference_cnn=path/to/reference.cnn \
  -itumor_vcf=path/to/sample.vcf \
  -itumor_vcf_index=path/to/sample.vcf.tbi \
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