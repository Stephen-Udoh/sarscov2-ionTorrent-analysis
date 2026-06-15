cat("Installing R packages...\n")

cran_packages <- c(
  "ggsci", "ggrepel", "ggpubr", "ggforce", "ggnewscale",
  "ggtext", "ggridges", "ggbeeswarm", "patchwork", "cowplot",
  "gt", "gtsummary", "flextable", "DT",
  "leaflet", "leaflet.extras", "tmap", "sf", "spdep",
  "ape", "phangorn", "dendextend", "UpSetR",
  "corrplot", "pheatmap", "circlize", "DiagrammeR",
  "here", "fs", "glue", "janitor", "skimr",
  "plotly", "htmlwidgets", "scales", "viridis",
  "RColorBrewer", "quarto", "renv"
)

bioc_packages <- c(
  "ggtree", "treeio", "ComplexHeatmap",
  "Rsamtools", "trackViewer", "GenomicRanges", "ggmsa"
)

cat("\nInstalling CRAN packages...\n")
installed <- rownames(installed.packages())
to_install <- cran_packages[!cran_packages %in% installed]
if (length(to_install) > 0) {
  install.packages(to_install, repos="https://cloud.r-project.org",
                   dependencies=TRUE)
}

cat("\nInstalling Bioconductor packages...\n")
if (!requireNamespace("BiocManager", quietly=TRUE))
  install.packages("BiocManager", repos="https://cloud.r-project.org")
BiocManager::install(version="3.18")
installed_bioc <- rownames(installed.packages())
to_install_bioc <- bioc_packages[!bioc_packages %in% installed_bioc]
if (length(to_install_bioc) > 0)
  BiocManager::install(to_install_bioc, ask=FALSE, update=FALSE)

cat("\nVerifying...\n")
all_pkgs <- c(cran_packages, bioc_packages)
results  <- sapply(all_pkgs, requireNamespace, quietly=TRUE)
failed   <- names(results[!results])
if (length(failed) == 0) {
  cat("✅ All R packages installed successfully!\n")
} else {
  cat("⚠️  Failed packages:\n")
  cat(paste(" -", failed, collapse="\n"), "\n")
}
