#!/usr/bin/env Rscript
# ============================================================
# 02_coverage_plots.R — Genome coverage depth across all samples
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(tidyr)
})

source("scripts/R/utils/theme_publication.R")

meta <- read.csv("data/metadata/sample_metadata.csv", stringsAsFactors = FALSE)

clean_label <- function(x) {
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}

state_colors <- c("Bauchi"="#2C3E50", "Kano"="#922B21", "Kaduna"="#1E6B52")

# Load all coverage files
all_cov <- lapply(meta$sample_id, function(sample) {
  bed <- sprintf("results/alignment/coverage/%s/%s.regions.bed.gz", sample, sample)
  if (!file.exists(bed)) return(NULL)
  df <- read.table(gzfile(bed), col.names = c("chrom","start","end","depth"))
  df$midpoint <- (df$start + df$end) / 2
  df$sample   <- sample
  df$label    <- clean_label(sample)
  state <- meta$state[meta$sample_id == sample]
  df$state    <- state
  df
})
cov <- bind_rows(Filter(Negate(is.null), all_cov))

# SARS-CoV-2 gene annotation for the gene track
genes <- data.frame(
  gene  = c("ORF1a","ORF1b","S","ORF3a","E","M","ORF6","ORF7a","ORF7b","ORF8","N","ORF10"),
  start = c(266,13468,21563,25393,26245,26523,27202,27394,27756,27894,28274,29558),
  end   = c(13483,21555,25384,26220,26472,27191,27387,27759,27887,28259,29533,29674),
  stringsAsFactors = FALSE
)
gene_colors <- c(
  "ORF1a"="#4878CF","ORF1b"="#6ACC65","S"="#D65F5F",
  "ORF3a"="#B47CC7","E"="#C4AD66","M"="#77BEDB",
  "ORF6"="#4878CF","ORF7a"="#6ACC65","ORF7b"="#D65F5F",
  "ORF8"="#B47CC7","N"="#C4AD66","ORF10"="#77BEDB"
)

# Order samples
sample_order <- meta %>% arrange(state, sample_id) %>% pull(sample_id)
label_order  <- clean_label(sample_order)
cov$label <- factor(cov$label, levels = label_order)

# Main coverage plot — faceted by sample
p_cov <- ggplot(cov, aes(x = midpoint, y = depth, color = state)) +
  geom_line(linewidth = 0.4, alpha = 0.9) +
  geom_hline(yintercept = 10, linetype = "dashed",
             color = "grey60", linewidth = 0.35) +
  scale_color_manual(values = state_colors, guide = "none") +
  scale_x_continuous(
    limits = c(0, 29903),
    breaks = c(0, 10000, 20000, 29903),
    labels = c("0", "10kb", "20kb", "29.9kb"),
    expand = c(0, 0),
    name = NULL
  ) +
  scale_y_continuous(name = "Mean depth (×)", labels = scales::comma) +
  facet_wrap(~ label, ncol = 2, scales = "free_y") +
  theme_publication(base_size = 8, base_family = "Liberation Serif") +
  theme(
    strip.background = element_rect(fill = "grey95", color = "grey80"),
    strip.text       = element_text(size = 7.5, face = "bold",
                                    family = "Liberation Serif"),
    panel.border     = element_rect(color = "grey80", fill = NA, linewidth = 0.3),
    panel.grid.major = element_line(color = "grey93", linewidth = 0.25),
    panel.grid.minor = element_blank(),
    axis.text.x      = element_text(size = 6.5),
    axis.text.y      = element_text(size = 6.5)
  )

# Gene track — a single strip showing gene positions
p_genes <- ggplot(genes, aes(xmin = start, xmax = end,
                              ymin = 0, ymax = 1, fill = gene)) +
  geom_rect() +
  geom_text(aes(x = (start+end)/2, y = 0.5, label = ifelse((end-start) > 1500, gene, "")),
            size = 2.0, color = "white", fontface = "bold",
            family = "Liberation Serif") +
  scale_fill_manual(values = gene_colors, guide = "none") +
  scale_x_continuous(limits = c(0, 29903), expand = c(0,0),
                     breaks = NULL, name = "Genome position (NC_045512.2)") +
  scale_y_continuous(breaks = NULL, name = NULL) +
  theme_minimal() +
  theme(
    plot.margin      = margin(0, 5.5, 5, 5.5),
    axis.title.x     = element_text(size = 8, family = "Liberation Serif",
                                    margin = margin(t=4)),
    panel.grid       = element_blank()
  )

# Stack: coverage panels on top, gene track below
library(patchwork)
p_final <- p_cov / p_genes + plot_layout(heights = c(10, 1))

save_figure(p_final, "results/figures/coverage_depth",
            width = 11, height = 9)

cat("\n✅ Coverage depth figure saved\n")
