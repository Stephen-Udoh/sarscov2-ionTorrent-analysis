# 🧬 SARS-CoV-2 Ion Torrent Genomic Surveillance Pipeline

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Zorin%20OS-blue)]()
[![Python](https://img.shields.io/badge/Python-3.9%2B-green)]()
[![R](https://img.shields.io/badge/R-4.3%2B-blue)]()
[![Conda](https://img.shields.io/badge/Conda-Environment-brightgreen)]()

> **A reproducible, publication-standard bioinformatics pipeline for end-to-end SARS-CoV-2 genomic analysis from Ion Torrent BAM files — encompassing QC, variant calling, lineage assignment, phylogenetics, mutation landscape analysis, and geospatial visualization.**

**Author:** Udoh Stephen Nsikak  
**Affiliation:** Molecular Genetics and Infectious Diseases Research Laboratory (MOGID_RL)  
**Platform:** Ion Torrent NGS → Zorin OS (Ubuntu-based) → Python + R + Bash  

---

## 📋 Table of Contents

- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Analysis Modules](#analysis-modules)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Running the Pipeline](#running-the-pipeline)
- [Outputs & Figures](#outputs--figures)
- [Environment Setup](#environment-setup)
- [Sample Metadata](#sample-metadata)
- [QC Gates & Thresholds](#qc-gates--thresholds)
- [Tools & Versions](#tools--versions)
- [Citation](#citation)

---

## Overview

This pipeline processes raw BAM files from Ion Torrent sequencing of SARS-CoV-2 clinical samples through a complete genomic surveillance workflow. It is designed to be:

- **Modular** — run a single sample or all samples independently
- **Reproducible** — conda environment + version locking + parameter logging
- **Scalable** — from 1 to N samples without changing architecture
- **Publication-ready** — 60+ figures meeting journal submission standards
- **Auditable** — full provenance tracking, QC gates, and audit logs

### Key capabilities
- Per-sample AND cohort-level analysis
- Variant annotation and functional impact classification
- WHO Variant of Concern (VOC) mutation screening
- Maximum likelihood phylogenetic inference (IQ-TREE2)
- Time-resolved phylogeny (BEAST2)
- Geospatial and temporal visualization
- Automated per-sample and cohort reports (Quarto/R Markdown)

---

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LEVEL 1: PER-SAMPLE                       │
│  (Independent — run one at a time or all in parallel)        │
│                                                              │
│  BAM → QC → Trim → Align → Coverage → Variants → Consensus  │
│                          ↓                                   │
│                    Lineage (Nextclade + Pangolin)            │
│                          ↓                                   │
│                   Per-sample Report                          │
└─────────────────────────┬───────────────────────────────────┘
                          │ All samples complete
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   LEVEL 2: COHORT                            │
│  (Runs after ≥2 samples processed)                          │
│                                                              │
│  All FASTAs → MAFFT alignment → IQ-TREE2 phylogeny          │
│  All variants → Mutation landscape + Heatmap                 │
│  All metadata → Geospatial + Temporal analysis               │
│                          ↓                                   │
│                  Cohort Summary Report                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   LEVEL 3: REPORTING                         │
│                                                              │
│  Quarto HTML/PDF reports  •  GitHub Pages  •  Audit Log     │
└─────────────────────────────────────────────────────────────┘
```

---

## Analysis Modules

| # | Module | Level | Key Tools | Key Outputs |
|---|--------|-------|-----------|-------------|
| 01 | QC & Preprocessing | Per-sample | FastQC, MultiQC, Trimmomatic | QC reports, trimmed reads |
| 02 | Alignment & Coverage | Per-sample | BWA, samtools, mosdepth | Sorted BAM, coverage BED |
| 03 | Variant Calling | Per-sample | iVar, samtools mpileup | Annotated variants TSV |
| 04 | Consensus Generation | Per-sample | iVar, BioPython | Consensus FASTA + QC |
| 05 | Lineage Assignment | Per-sample | Nextclade, Pangolin | Clade + lineage table |
| 06 | Mutation Analysis | Cohort | SnpEff, Python, R | Heatmap, lollipop plots |
| 07 | Phylogenetics | Cohort | MAFFT, IQ-TREE2, ggtree | ML tree figures |
| 08 | Geospatial Analysis | Cohort | R sf/leaflet, Python folium | Interactive + static maps |
| 09 | Temporal Analysis | Cohort | R ggplot2 | Epicurves, timelines |
| 10 | Reporting | Both | Quarto, R Markdown | HTML/PDF reports |

---

## Repository Structure

```
sarscov2-ionTorrent-analysis/
│
├── README.md                        # This file
├── LICENSE                          # MIT License
├── CHANGELOG.md                     # Version history
│
├── config/
│   ├── pipeline_config.yaml         # All parameters in one place
│   ├── qc_thresholds.yaml           # QC gate definitions
│   └── voc_mutations.yaml           # WHO VOC/VOI mutation list
│
├── envs/
│   ├── environment.yml              # Main conda environment
│   └── r_packages.R                 # R package installer script
│
├── data/
│   ├── raw/                         # BAM files (gitignored — large files)
│   │   └── .gitkeep
│   ├── reference/                   # NC_045512.2 reference genome
│   │   └── .gitkeep
│   └── metadata/
│       ├── sample_metadata.csv      # Sample manifest (THE source of truth)
│       └── sample_metadata_TEMPLATE.csv
│
├── scripts/
│   ├── bash/
│   │   ├── 00_setup.sh              # Environment check + MD5 validation
│   │   ├── 01_qc.sh                 # FastQC + samtools flagstat
│   │   ├── 02_align.sh              # BWA + samtools + mosdepth
│   │   ├── 03_variants.sh           # iVar variant calling
│   │   ├── 04_consensus.sh          # iVar consensus generation
│   │   ├── 05_lineage.sh            # Nextclade + Pangolin
│   │   └── run_pipeline.sh          # Master script (single or all samples)
│   │
│   ├── python/
│   │   ├── 00_validate_metadata.py  # Metadata QC checker
│   │   ├── 01_qc_summary.py         # Parse FastQC + flagstat → summary table
│   │   ├── 02_coverage_stats.py     # mosdepth → coverage statistics
│   │   ├── 03_variant_annotation.py # Merge + annotate all variant tables
│   │   ├── 04_consensus_qc.py       # Count Ns, assess completeness
│   │   ├── 05_voc_screening.py      # Screen for VOC/VOI mutations
│   │   ├── 06_mutation_heatmap.py   # Mutation presence/absence heatmap
│   │   └── utils/
│   │       ├── logger.py            # Audit logging utility
│   │       ├── checksums.py         # MD5 generation + validation
│   │       └── config_loader.py     # YAML config reader
│   │
│   └── R/
│       ├── 01_qc_plots.R            # QC visualization suite
│       ├── 02_coverage_plots.R      # Coverage depth plots
│       ├── 03_variant_plots.R       # Variant analysis plots
│       ├── 04_mutation_landscape.R  # Heatmap + lollipop plots
│       ├── 05_lineage_plots.R       # Lineage/clade visualizations
│       ├── 06_phylogeny.R           # ggtree visualization
│       ├── 07_geospatial.R          # Maps + spatial analysis
│       ├── 08_temporal.R            # Epicurves + timelines
│       └── utils/
│           ├── theme_publication.R  # Shared ggplot2 publication theme
│           ├── color_palettes.R     # Consistent color assignments
│           └── figure_export.R      # Standard figure export (300 DPI)
│
├── notebooks/
│   ├── 01_QC_and_alignment.ipynb
│   ├── 02_variant_calling.ipynb
│   ├── 03_consensus_and_qc.ipynb
│   ├── 04_lineage_analysis.ipynb
│   ├── 05_mutation_analysis.ipynb
│   ├── 06_phylogenetics.ipynb
│   ├── 07_geospatial.ipynb
│   └── 08_cohort_summary.ipynb
│
├── results/                         # All outputs (gitignored except figures)
│   ├── qc/
│   ├── alignment/
│   ├── variants/
│   ├── consensus/
│   ├── nextclade/
│   ├── phylogenetics/
│   ├── figures/                     # Publication figures (committed)
│   └── reports/
│
├── docs/
│   ├── methods.md                   # Detailed methods text
│   ├── parameter_justification.md   # Why each parameter was chosen
│   └── figures/                     # Figures for documentation
│
├── audit.log                        # Append-only pipeline audit log
└── .github/
    └── workflows/
        └── validate_env.yml         # GitHub Actions CI
```

---

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/sarscov2-ionTorrent-analysis.git
cd sarscov2-ionTorrent-analysis
```

### 2. Set up the conda environment
```bash
conda env create -f envs/environment.yml
conda activate sarscov2-pipeline
```

### 3. Install R packages
```bash
Rscript envs/r_packages.R
```

### 4. Add your BAM files
```bash
cp /path/to/your/*.bam data/raw/
```

### 5. Fill in sample metadata
```bash
cp data/metadata/sample_metadata_TEMPLATE.csv data/metadata/sample_metadata.csv
# Edit sample_metadata.csv with your sample information
```

### 6. Validate setup
```bash
bash scripts/bash/00_setup.sh
```

### 7. Run the pipeline
```bash
# Single sample
bash scripts/bash/run_pipeline.sh --sample IonCode_0108

# All samples
bash scripts/bash/run_pipeline.sh --all

# Specific modules only
bash scripts/bash/run_pipeline.sh --sample IonCode_0108 --modules qc,align,variants

# Cohort analysis (after per-sample steps complete)
bash scripts/bash/run_pipeline.sh --cohort
```

---

## QC Gates & Thresholds

Samples are evaluated at each step. Results are flagged as ✅ PASS / ⚠️ FLAG / ❌ FAIL.

| Gate | Metric | PASS | FLAG | FAIL |
|------|--------|------|------|------|
| Pre-alignment | Total reads | ≥10,000 | 5,000–10,000 | <5,000 |
| Alignment | % reads mapped | ≥90% | 70–90% | <70% |
| Coverage | % genome at ≥10x | ≥90% | 70–90% | <70% |
| Coverage | Mean depth | ≥100x | 20–100x | <20x |
| Consensus | % ambiguous (Ns) | ≤5% | 5–10% | >10% |
| Lineage | Nextclade QC | good | mediocre | bad |

Samples that FAIL are excluded from cohort analysis. FAILed samples are documented in the audit log with reason.

---

## Tools & Versions

| Tool | Version | Purpose |
|------|---------|---------|
| FastQC | 0.12.1 | Read quality assessment |
| MultiQC | 1.21 | QC aggregation |
| Trimmomatic | 0.39 | Read trimming |
| BWA | 0.7.17 | Read alignment |
| samtools | 1.19 | BAM manipulation |
| mosdepth | 0.3.6 | Coverage analysis |
| iVar | 1.4.2 | Variant calling + consensus |
| SnpEff | 5.1 | Variant annotation |
| Nextclade | 3.x | Clade assignment |
| Pangolin | 4.x | Lineage assignment |
| MAFFT | 7.520 | Multiple sequence alignment |
| IQ-TREE2 | 2.3.x | Maximum likelihood phylogeny |
| BEAST2 | 2.7.x | Bayesian phylogeny (optional) |
| Python | 3.9+ | Analysis scripts |
| R | 4.3+ | Visualization + reporting |

---

## Citation

If you use this pipeline, please cite:

```
Udoh SN. (2024). SARS-CoV-2 Ion Torrent Genomic Surveillance Pipeline.
GitHub: https://github.com/YOUR_USERNAME/sarscov2-ionTorrent-analysis
DOI: [Zenodo DOI here after release]
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.
