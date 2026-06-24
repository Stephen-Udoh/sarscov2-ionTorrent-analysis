#!/usr/bin/env python3
"""
06_mutation_heatmap.py
Merges all 10 samples' iVar variant tables into one matrix:
  rows = samples, columns = mutations (REF+POS+ALT), values = ALT_FREQ
Filters to PASS=TRUE and a minimum frequency threshold.
Writes both the matrix CSV and a long-format CSV for R plotting.
"""

import pandas as pd
import glob
import os

VARIANTS_DIR = "results/variants"
OUTPUT_DIR = "results/variants"
MIN_FREQ = 0.5  # only show majority/consensus-level variants in the heatmap

def load_sample_variants(tsv_path):
    sample = os.path.basename(tsv_path).replace("_variants.tsv", "")
    df = pd.read_csv(tsv_path, sep="\t")
    df = df[df["PASS"] == True]
    df = df[df["ALT_FREQ"] >= MIN_FREQ]
    df["sample"] = sample
    df["mutation"] = df["REF"] + df["POS"].astype(str) + df["ALT"]
    return df[["sample", "mutation", "POS", "REF", "ALT", "ALT_FREQ"]]

def main():
    tsv_files = sorted(glob.glob(f"{VARIANTS_DIR}/*/*_variants.tsv"))
    print(f"Found {len(tsv_files)} variant files")

    all_variants = pd.concat([load_sample_variants(f) for f in tsv_files], ignore_index=True)
    print(f"Total PASS variants (freq >= {MIN_FREQ}): {len(all_variants)}")
    print(f"Unique mutations across cohort: {all_variants['mutation'].nunique()}")

    # Long format (good for ggplot2 geom_tile)
    long_path = f"{OUTPUT_DIR}/cohort_mutations_long.csv"
    all_variants.to_csv(long_path, index=False)
    print(f"Saved long format: {long_path}")

    # Wide matrix: samples x mutations, values = ALT_FREQ
    matrix = all_variants.pivot_table(
        index="sample", columns="mutation", values="ALT_FREQ", fill_value=0
    )
    # Sort columns by genomic position for readability
    pos_lookup = all_variants.drop_duplicates("mutation").set_index("mutation")["POS"]
    matrix = matrix[sorted(matrix.columns, key=lambda m: pos_lookup[m])]

    matrix_path = f"{OUTPUT_DIR}/cohort_mutations_matrix.csv"
    matrix.to_csv(matrix_path)
    print(f"Saved matrix format: {matrix_path}")

    # Quick summary: mutations shared by all samples vs unique to one
    mutation_counts = all_variants.groupby("mutation")["sample"].nunique()
    n_samples = all_variants["sample"].nunique()
    shared_all = (mutation_counts == n_samples).sum()
    unique_one = (mutation_counts == 1).sum()
    print(f"\nMutations present in ALL {n_samples} samples: {shared_all}")
    print(f"Mutations present in only 1 sample: {unique_one}")

if __name__ == "__main__":
    main()
