#!/usr/bin/env Rscript
# ============================================================
# 07_geospatial.R — Static Nigeria map for publication (image only)
# ============================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(sf)
})

source("scripts/R/utils/theme_publication.R")

# Download Nigeria state boundaries if not present
nigeria_file <- "data/reference/nigeria_states.rds"
if (!file.exists(nigeria_file)) {
  nigeria <- rnaturalearth::ne_states(country = "Nigeria", returnclass = "sf")
  saveRDS(nigeria, nigeria_file)
} else {
  nigeria <- readRDS(nigeria_file)
}

# Sample coordinates (state capitals, with jitter for multiple samples)
set.seed(42)
sample_coords <- data.frame(
  sample_id = c("bauchi_1586","bauchi_3370","bauchi_4200",
                "bauchi_4229","bauchi_4243","bauchi_4244",
                "kaduna_0101","kano_0103","kano_0104","kano_0105"),
  state     = c(rep("Bauchi",6),"Kaduna",rep("Kano",3)),
  lineage   = c("L.3",rep("B.1.462",5),"B.1.1.10",rep("LF.7.9.1",3)),
  lon = c(9.8442,9.8442,9.8442,9.8442,9.8442,9.8442,7.4384,8.5920,8.5920,8.5920) +
        runif(10, -0.3, 0.3),
  lat = c(10.3158,10.3158,10.3158,10.3158,10.3158,10.3158,10.5264,12.0022,12.0022,12.0022) +
        runif(10, -0.3, 0.3)
)

state_colors <- c("Bauchi"="#2C3E50", "Kano"="#922B21", "Kaduna"="#1E6B52")

p <- ggplot() +
  geom_sf(data = nigeria, fill = "grey96", color = "grey70", linewidth = 0.3) +
  geom_point(data = sample_coords,
             aes(x = lon, y = lat, color = state),
             size = 3.5, alpha = 0.9) +
  scale_color_manual(values = state_colors, name = NULL) +
  coord_sf(xlim = c(2.7, 14.7), ylim = c(4.2, 13.9), expand = FALSE) +
  annotate("text", x = 9.8442, y = 10.0, label = "Bauchi",
           size = 2.8, family = "Liberation Serif", color = "#2C3E50", fontface = "bold") +
  annotate("text", x = 8.5920, y = 12.35, label = "Kano",
           size = 2.8, family = "Liberation Serif", color = "#922B21", fontface = "bold") +
  annotate("text", x = 7.1, y = 10.5264, label = "Kaduna",
           size = 2.8, family = "Liberation Serif", color = "#1E6B52", fontface = "bold") +
  theme_publication(base_size = 9, base_family = "Liberation Serif") +
  theme(
    axis.text        = element_text(size = 7),
    axis.title       = element_blank(),
    panel.border     = element_rect(color = "grey60", fill = NA, linewidth = 0.4),
    panel.background = element_rect(fill = "#EAF4FB"),
    legend.position  = "bottom",
    legend.direction = "horizontal",
    legend.key       = element_blank(),
    legend.background = element_blank()
  ) +
  labs(x = "Longitude", y = "Latitude")

save_figure(p, "results/figures/geospatial_static",
            width = 6, height = 6)

cat("\n✅ Static geospatial map saved\n")
