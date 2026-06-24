#!/usr/bin/env Rscript
# ============================================================
# 04_mutation_landscape.R — Mutation frequency heatmap (image only)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
})

source("scripts/R/utils/theme_publication.R")

df   <- read.csv("results/variants/cohort_mutations_long.csv", stringsAsFactors = FALSE)
meta <- read.csv("data/metadata/sample_metadata.csv", stringsAsFactors = FALSE)

clean_label <- function(x) {
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}
meta$label <- clean_label(meta$sample_id)
df <- df %>% left_join(meta[, c("sample_id","label","state")], by = c("sample" = "sample_id"))

sample_order <- meta %>% arrange(state, sample_id) %>% pull(label)
df$label <- factor(df$label, levels = sample_order)

mut_order <- df %>% distinct(mutation, POS) %>% arrange(POS) %>% pull(mutation)
df$mutation <- factor(df$mutation, levels = mut_order)

p <- ggplot(df, aes(x = mutation, y = label, fill = ALT_FREQ)) +
  geom_tile(color = "grey90", linewidth = 0.12) +
  scale_fill_viridis_c(
    option = "viridis", name = "Allele\nfrequency",
    limits = c(0.5, 1), labels = scales::percent
  ) +
  scale_x_discrete(expand = c(0, 0)) +
  scale_y_discrete(limits = rev(sample_order)) +
  theme_publication(base_size = 10, base_family = "Liberation Serif") +
  theme(
    axis.text.x   = element_blank(),
    axis.ticks.x  = element_blank(),
    axis.title    = element_blank(),
    panel.grid    = element_blank(),
    panel.border  = element_blank(),
    axis.ticks.y  = element_blank(),
    plot.margin   = margin(8, 8, 8, 60),
    legend.position = "right"
  )

save_figure(p, "results/figures/mutation_heatmap", width = 11, height = 4.5)

cat("\n✅ Mutation heatmap saved (image only, no embedded caption)\n")
