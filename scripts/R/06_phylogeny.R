#!/usr/bin/env Rscript
# ============================================================
# 06_phylogeny.R — Publication-standard ML tree visualization
# ============================================================

suppressPackageStartupMessages({
  library(ggtree)
  library(treeio)
  library(ggplot2)
  library(dplyr)
  library(stringr)
})

source("scripts/R/utils/theme_publication.R")

repo_root <- getwd()
tree_file <- file.path(repo_root, "results/phylogenetics/sarscov2_ml_tree.treefile")
metadata_file <- file.path(repo_root, "data/metadata/sample_metadata.csv")

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

ref_row <- data.frame(label = "Reference (Wuhan-Hu-1)", state = "Reference",
                       stringsAsFactors = FALSE)
meta_plot <- bind_rows(meta[, c("label", "state")], ref_row)

# Sanity check: every tip must have a matching label in meta_plot
missing <- setdiff(tree$tip.label, meta_plot$label)
if (length(missing) > 0) {
  warning("Unmatched tip labels: ", paste(missing, collapse = ", "))
}

state_colors <- c(
  "Bauchi"    = "#3C5488",
  "Kano"      = "#E64B35",
  "Kaduna"    = "#00A087",
  "Reference" = "#999999"
)

max_depth <- max(ape::node.depth.edgelength(tree))

p <- ggtree(tree, layout = "rectangular", linewidth = 0.6, color = "grey40",
            ladderize = TRUE) %<+% meta_plot +
  geom_tippoint(aes(color = state), size = 3) +
  geom_tiplab(aes(color = state), size = 3.6, fontface = "bold",
              offset = max_depth * 0.02, hjust = 0) +
  geom_nodelab(aes(label = label), size = 2.6, color = "grey40",
               hjust = 1.2, vjust = -0.5) +
  scale_color_manual(values = state_colors, name = NULL) +
  geom_treescale(x = 0, y = -0.6, width = max_depth * 0.15, fontsize = 2.8,
                 linesize = 0.6, offset = 0.3) +
  ggtitle("Maximum-Likelihood Phylogeny of SARS-CoV-2 Genomes",
          subtitle = "Ion Torrent surveillance cohort (n = 10) \u2014 GTR+G, 1000 ultrafast bootstrap replicates") +
  theme_tree2(base_size = 11) +
  theme(
    plot.title         = element_text(size = 14, face = "bold", family = "DejaVu Sans"),
    plot.subtitle      = element_text(size = 10, color = "grey35", family = "DejaVu Sans"),
    legend.position    = "bottom",
    legend.direction   = "horizontal",
    legend.text        = element_text(size = 9.5, family = "DejaVu Sans"),
    legend.key         = element_blank(),
    legend.background  = element_blank(),
    plot.margin        = margin(10, 60, 10, 10),
    axis.text.x        = element_blank(),
    axis.ticks.x       = element_blank(),
    panel.border       = element_blank(),
    plot.caption       = element_text(size = 7.5, color = "grey50", hjust = 0,
                                      lineheight = 1.2, family = "DejaVu Sans")
  ) +
  labs(caption = "Rooted on Wuhan-Hu-1 (NC_045512.2). Node labels: ultrafast bootstrap support (%). Branch lengths: substitutions/site.") +
  xlim(0, max_depth * 1.28)

save_figure(p, "results/figures/phylogenetic_tree", width = 9, height = 6.2)

cat("\n✅ Phylogenetic tree figure saved\n")
