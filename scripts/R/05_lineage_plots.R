#!/usr/bin/env Rscript
# ============================================================
# 05_lineage_plots.R — Lineage and temporal summary (image only)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(patchwork)
})

source("scripts/R/utils/theme_publication.R")

df   <- read.csv("results/qc/cohort_qc_summary.csv", stringsAsFactors = FALSE)
meta <- read.csv("data/metadata/sample_metadata.csv", stringsAsFactors = FALSE)

clean_label <- function(x) {
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}
df$label <- clean_label(df$sample)
df <- df %>% left_join(meta[, c("sample_id","state","collection_date")], by = c("sample"="sample_id"))
df$year <- as.integer(str_sub(df$collection_date, 1, 4))

sample_order <- df %>% arrange(state, sample) %>% pull(label)
df$label <- factor(df$label, levels = rev(sample_order))

state_colors <- c("Bauchi"="#2C3E50", "Kano"="#922B21", "Kaduna"="#1E6B52")

# Panel A — Lineage per sample
p_lineage <- ggplot(df, aes(y = label, x = 1, fill = state)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = lineage), size = 3, family = "Liberation Serif",
            color = "white", fontface = "bold") +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_x_continuous(breaks = NULL, name = "Lineage") +
  scale_y_discrete(name = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.border = element_blank(),
        axis.ticks = element_blank(),
        panel.grid = element_blank())

# Panel B — Collection year vs lineage bubble plot
lineage_order <- df %>% arrange(year) %>% pull(lineage) %>% unique()
df$lineage_f <- factor(df$lineage, levels = lineage_order)

p_temporal <- ggplot(df, aes(x = year, y = lineage_f, color = state, size = total_reads)) +
  geom_point(alpha = 0.85, position = position_jitter(width = 0, height = 0.15, seed = 42)) +
  scale_color_manual(values = state_colors, name = NULL) +
  scale_size_continuous(name = "Total reads", labels = scales::comma,
                        range = c(3, 12)) +
  scale_x_continuous(breaks = c(2020, 2021, 2025), name = "Collection year") +
  scale_y_discrete(name = "Lineage (PANGO)") +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.border = element_blank(),
        panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
        legend.position = "bottom",
        legend.box = "horizontal",
        axis.ticks.y = element_blank())

p_combined <- p_lineage + p_temporal +
  plot_layout(ncol = 2, widths = c(0.6, 1.4))

save_figure(p_combined, "results/figures/lineage_temporal",
            width = 11, height = 5)

cat("\n✅ Lineage and temporal figure saved\n")
