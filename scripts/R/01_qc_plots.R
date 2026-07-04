#!/usr/bin/env Rscript
# ============================================================
# 01_qc_plots.R — Cohort QC summary figure (image only)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(patchwork)
})

source("scripts/R/utils/theme_publication.R")

df <- read.csv("results/qc/cohort_qc_summary.csv", stringsAsFactors = FALSE)
meta <- read.csv("data/metadata/sample_metadata.csv", stringsAsFactors = FALSE)

clean_label <- function(x) {
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}
df$label <- clean_label(df$sample)
df <- df %>% left_join(meta[, c("sample_id","state")], by = c("sample"="sample_id"))

# Order by state then sample
sample_order <- df %>% arrange(state, sample) %>% pull(label)
df$label <- factor(df$label, levels = rev(sample_order))

state_colors <- c("Bauchi"="#2C3E50", "Kano"="#922B21", "Kaduna"="#1E6B52")

# QC threshold lines
qc_mapped_pass <- 90
qc_n_pass      <- 5
qc_n_flag      <- 10

# Panel A — Total reads (log10 scale)
p_reads <- ggplot(df, aes(x = total_reads, y = label, fill = state)) +
  geom_col(width = 0.6) +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_x_continuous(labels = scales::comma,
                     trans = "log10",
                     name = "Total reads (log scale)") +
  scale_y_discrete(name = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.grid.major.x = element_line(color = "grey88", linewidth = 0.3),
        panel.grid.major.y = element_blank(),
        panel.border = element_blank(),
        axis.ticks.y = element_blank())

# Panel B — % reads mapped
p_mapped <- ggplot(df, aes(x = pct_mapped, y = label, fill = state)) +
  geom_col(width = 0.6) +
  geom_vline(xintercept = qc_mapped_pass, linetype = "dashed",
             color = "#922B21", linewidth = 0.5) +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_x_continuous(limits = c(0, 100), name = "Reads mapped (%)") +
  scale_y_discrete(name = NULL, labels = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.grid.major.x = element_line(color = "grey88", linewidth = 0.3),
        panel.grid.major.y = element_blank(),
        panel.border = element_blank(),
        axis.ticks.y = element_blank())

# Panel C — % ambiguous bases (N)
p_n <- ggplot(df, aes(x = pct_n, y = label, fill = state)) +
  geom_col(width = 0.6) +
  geom_vline(xintercept = qc_n_pass, linetype = "dashed",
             color = "#F39B7F", linewidth = 0.5) +
  geom_vline(xintercept = qc_n_flag, linetype = "dashed",
             color = "#922B21", linewidth = 0.5) +
  scale_fill_manual(values = state_colors, name = NULL) +
  scale_x_continuous(limits = c(0, 12), name = "Ambiguous bases (% N)") +
  scale_y_discrete(name = NULL, labels = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.grid.major.x = element_line(color = "grey88", linewidth = 0.3),
        panel.grid.major.y = element_blank(),
        panel.border = element_blank(),
        axis.ticks.y = element_blank(),
        legend.position = "bottom",
        legend.direction = "horizontal")

# Combine panels
p_combined <- p_reads + p_mapped + p_n +
  plot_layout(ncol = 3, widths = c(1.4, 1, 1))

save_figure(p_combined, "results/figures/qc_summary",
            width = 11, height = 4.5)

cat("\n✅ QC summary figure saved\n")
