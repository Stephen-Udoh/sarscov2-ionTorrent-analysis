#!/usr/bin/env Rscript
# ============================================================
# 03_variant_plots.R — Variant summary figure (image only)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(patchwork)
  library(tidyr)
})

source("scripts/R/utils/theme_publication.R")

meta <- read.csv("data/metadata/sample_metadata.csv", stringsAsFactors = FALSE)

clean_label <- function(x) {
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}

state_colors <- c("Bauchi"="#2C3E50", "Kano"="#922B21", "Kaduna"="#1E6B52")

# Load and classify all variants
all_vars <- lapply(meta$sample_id, function(sample) {
  tsv <- sprintf("results/variants/%s/%s_variants.tsv", sample, sample)
  if (!file.exists(tsv)) return(NULL)
  df <- read.delim(tsv, stringsAsFactors = FALSE)
  df <- df[df$PASS == TRUE & df$ALT_FREQ >= 0.5, ]
  if (nrow(df) == 0) return(NULL)

  df$sample <- sample
  df$label  <- clean_label(sample)
  df$state  <- meta$state[meta$sample_id == sample]

  # Classify variant type
  df$var_type <- dplyr::case_when(
    nchar(df$REF) != nchar(df$ALT) ~ "Indel",
    df$REF_AA == df$ALT_AA         ~ "Synonymous SNP",
    df$REF_AA == "" | df$ALT_AA == "" ~ "Non-coding SNP",
    TRUE                            ~ "Non-synonymous SNP"
  )
  df
})
vars <- bind_rows(Filter(Negate(is.null), all_vars))

# Sample order
sample_order <- meta %>% arrange(state, sample_id) %>% pull(sample_id)
label_order  <- clean_label(sample_order)
vars$label <- factor(vars$label, levels = label_order)

# Panel A — Total variants per sample
var_counts <- vars %>% group_by(label, state) %>% summarise(n = n(), .groups = "drop")
var_counts$label <- factor(var_counts$label, levels = label_order)

p_counts <- ggplot(var_counts, aes(x = n, y = label, fill = state)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = n), hjust = -0.2, size = 2.8,
            family = "Liberation Serif") +
  scale_fill_manual(values = state_colors, guide = "none") +
  scale_x_continuous(name = "Variants (n)", expand = expansion(mult = c(0, 0.15))) +
  scale_y_discrete(name = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.border  = element_blank(),
        panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3),
        panel.grid.major.y = element_blank(),
        axis.ticks.y  = element_blank())

# Panel B — Variant type breakdown (stacked bar)
type_counts <- vars %>%
  group_by(label, state, var_type) %>%
  summarise(n = n(), .groups = "drop")
type_counts$label <- factor(type_counts$label, levels = label_order)

type_colors <- c(
  "Non-synonymous SNP" = "#922B21",
  "Synonymous SNP"     = "#4878CF",
  "Non-coding SNP"     = "#6ACC65",
  "Indel"              = "#B47CC7"
)

p_types <- ggplot(type_counts, aes(x = n, y = label, fill = var_type)) +
  geom_col(width = 0.65, position = "stack") +
  scale_fill_manual(values = type_colors, name = NULL) +
  scale_x_continuous(name = "Variants by type (n)",
                     expand = expansion(mult = c(0, 0.05))) +
  scale_y_discrete(name = NULL, labels = NULL) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(panel.border  = element_blank(),
        panel.grid.major.x = element_line(color = "grey90", linewidth = 0.3),
        panel.grid.major.y = element_blank(),
        axis.ticks.y  = element_blank(),
        legend.position = "bottom",
        legend.direction = "horizontal",
        legend.text = element_text(size = 8, family = "Liberation Serif"),
        legend.key = element_blank(),
        legend.background = element_blank())

p_combined <- p_counts + p_types +
  plot_layout(ncol = 2, widths = c(1, 1.3))

save_figure(p_combined, "results/figures/variant_summary",
            width = 10, height = 4.5)

cat("\n✅ Variant summary figure saved\n")
