#!/usr/bin/env Rscript
# ============================================================
# 06_phylogeny.R — ML tree figure (image only, no caption text)
# Caption/methods text belongs in the manuscript, not the image.
# ============================================================

suppressPackageStartupMessages({
  library(ggtree)
  library(treeio)
  library(ggplot2)
  library(dplyr)
  library(stringr)
})

source("scripts/R/utils/theme_publication.R")

tree_file <- "results/phylogenetics/sarscov2_ml_tree.treefile"
metadata_file <- "data/metadata/sample_metadata.csv"

tree <- read.tree(tree_file)

clean_labels <- function(x) {
  x <- str_remove(x, "^Consensus_")
  x <- str_remove(x, "_threshold_.*$")
  x <- str_replace(x, "^([A-Za-z]+)_?(\\d+)$", "\\1 \\2")
  str_to_title(x)
}
tree$tip.label <- clean_labels(tree$tip.label)
tree$tip.label[str_detect(tree$tip.label, "^Nc")] <- "Reference (Wuhan-Hu-1)"

meta <- read.csv(metadata_file, stringsAsFactors = FALSE)
meta$label <- clean_labels(meta$sample_id)
ref_row <- data.frame(label = "Reference (Wuhan-Hu-1)", state = "Reference", stringsAsFactors = FALSE)
meta_plot <- bind_rows(meta[, c("label", "state")], ref_row)

state_colors <- c(
  "Bauchi"    = "#2C3E50",
  "Kano"      = "#922B21",
  "Kaduna"    = "#1E6B52",
  "Reference" = "#999999"
)

max_depth <- max(ape::node.depth.edgelength(tree))

p <- ggtree(tree, layout = "rectangular", linewidth = 0.45, color = "grey30",
            ladderize = TRUE) %<+% meta_plot +
  geom_tippoint(aes(color = state), size = 2.2) +
  geom_tiplab(aes(color = state), size = 3.2, fontface = "plain",
              offset = max_depth * 0.02, hjust = 0, family = "Liberation Serif") +
  geom_nodelab(aes(label = label), size = 2.3, color = "grey35",
               hjust = 1.2, vjust = -0.5, family = "Liberation Serif") +
  scale_color_manual(values = state_colors, name = NULL,
                     guide = guide_legend(override.aes = list(label = "", linetype = 0))) +
  geom_treescale(x = 0, y = -0.6, width = max_depth * 0.15, fontsize = 2.4,
                 linesize = 0.5, offset = 0.3) +
  theme_tree2(base_size = 10, base_family = "Liberation Serif") +
  theme(
    legend.position     = "bottom",
    legend.direction    = "horizontal",
    legend.text         = element_text(size = 9, family = "Liberation Serif"),
    legend.key          = element_blank(),
    legend.background   = element_blank(),
    plot.margin         = margin(8, 50, 8, 8),
    axis.text.x         = element_blank(),
    axis.ticks.x        = element_blank(),
    panel.border        = element_blank()
  ) +
  xlim(0, max_depth * 1.25)

save_figure(p, "results/figures/phylogenetic_tree", width = 8.5, height = 6)

cat("\n✅ Phylogenetic tree figure saved (image only, no embedded caption)\n")
