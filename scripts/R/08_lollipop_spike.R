#!/usr/bin/env Rscript
# ============================================================
# 08_lollipop_spike.R — Spike protein mutation lollipop plot
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(stringr)
  library(ggrepel)
})

source("scripts/R/utils/theme_publication.R")

spike <- read.csv("results/variants/spike_mutations.csv",
                  stringsAsFactors = FALSE)

domains <- data.frame(
  domain = c("NTD","RBD","FP","HR1","HR2","TM"),
  start  = c(1,   319, 788, 912, 1163, 1214),
  end    = c(305, 541, 806, 984, 1202, 1237),
  fill   = c("#AED6F1","#A9DFBF","#F9E79F","#F1948A","#C39BD3","#AEB6BF")
)

state_colors <- c("Bauchi"="#2C3E50","Kano"="#922B21","Kaduna"="#1E6B52")

voc_muts <- c("D614G","N501Y","E484K","K417N","L452R","P681H",
              "P681R","N679K","H655Y","S477N","T478K","Q498R",
              "G339D","S371F","S373P","S375F","K356T","R346T",
              "L455S","F456L","N460K","A475V","F486P","Y505H")

spike_summary <- spike %>%
  filter(!is.na(POS_AA), !is.na(aa_change), aa_change != "NANA") %>%
  group_by(POS_AA, aa_change) %>%
  summarise(
    n_samples      = n_distinct(sample),
    dominant_state = names(sort(table(state), decreasing=TRUE))[1],
    mean_freq      = mean(ALT_FREQ),
    .groups        = "drop"
  ) %>%
  mutate(
    is_voc = aa_change %in% voc_muts,
    label  = ifelse(n_samples >= 2 | is_voc, aa_change, "")
  )

p <- ggplot() +
  geom_rect(data = domains,
            aes(xmin=start, xmax=end, ymin=-0.4, ymax=0, fill=domain),
            alpha = 0.7, show.legend = FALSE) +
  geom_text(data = domains,
            aes(x=(start+end)/2, y=-0.2, label=domain),
            size = 2.4, family="Liberation Serif", fontface="bold") +
  geom_segment(data = spike_summary,
               aes(x=POS_AA, xend=POS_AA, y=0, yend=n_samples,
                   color=dominant_state),
               linewidth = 0.5, alpha = 0.7) +
  geom_point(data = spike_summary,
             aes(x=POS_AA, y=n_samples, color=dominant_state,
                 size=mean_freq, shape=is_voc),
             alpha = 0.85) +
  ggrepel::geom_text_repel(
    data = spike_summary %>% filter(label != ""),
    aes(x=POS_AA, y=n_samples, label=label, color=dominant_state),
    size = 2.4, family="Liberation Serif",
    max.overlaps = 20, segment.size = 0.3,
    box.padding = 0.3, min.segment.length = 0.1
  ) +
  scale_color_manual(values = state_colors, name = NULL) +
  scale_fill_manual(values = setNames(domains$fill, domains$domain)) +
  scale_size_continuous(name = "Mean allele\nfrequency",
                        range = c(1.5, 5), labels = scales::percent) +
  scale_shape_manual(values = c("FALSE"=16, "TRUE"=18),
                     labels = c("Other","VOC-associated"), name = NULL) +
  scale_x_continuous(name = "Spike protein position (amino acid)",
                     limits = c(0, 1274),
                     breaks = c(1,100,200,300,400,500,600,700,
                                800,900,1000,1100,1200,1274)) +
  scale_y_continuous(name = "Number of samples",
                     breaks = 0:10, limits = c(-0.5, 10.5),
                     expand = c(0,0)) +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(
    panel.border       = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color="grey90", linewidth=0.3),
    legend.position    = "bottom",
    legend.direction   = "horizontal",
    legend.box         = "horizontal",
    legend.key         = element_blank(),
    legend.background  = element_blank(),
    axis.ticks.x       = element_blank()
  )

save_figure(p, "results/figures/lollipop_spike",
            width = 13, height = 5.5)

cat("\n✅ Spike lollipop plot saved\n")
