# Publication-standard ggplot2 theme
# Source at top of every R script:
#   source("scripts/R/utils/theme_publication.R")

suppressPackageStartupMessages({
  library(ggplot2); library(viridis); library(scales)
})

theme_publication <- function(base_size=11, base_family="Liberation Serif") {
  theme_classic(base_size=base_size, base_family=base_family) %+replace%
    theme(
      panel.background  = element_rect(fill="white", color=NA),
      panel.grid.major  = element_line(color="grey92", linewidth=0.3),
      panel.grid.minor  = element_blank(),
      panel.border      = element_rect(color="grey30", fill=NA, linewidth=0.5),
      axis.line         = element_blank(),
      axis.ticks        = element_line(color="grey30", linewidth=0.3),
      axis.text         = element_text(size=base_size-1, color="grey20"),
      axis.title        = element_text(size=base_size, color="grey10", face="bold"),
      axis.title.x      = element_text(margin=margin(t=8)),
      axis.title.y      = element_text(margin=margin(r=8), angle=90),
      legend.background = element_rect(fill="white", color=NA),
      legend.title      = element_text(size=base_size-1, face="bold"),
      legend.text       = element_text(size=base_size-2),
      strip.background  = element_rect(fill="grey95", color="grey70"),
      strip.text        = element_text(size=base_size-1, face="bold"),
      plot.title        = element_text(size=base_size, face="bold", hjust=0, family=base_family),
      plot.subtitle     = element_text(size=base_size-1, color="grey30", hjust=0, family=base_family),
      plot.caption      = element_text(size=base_size-1, color="grey15", hjust=0, lineheight=1.3, family=base_family),
      plot.margin       = margin(12, 12, 8, 12),
      plot.background   = element_rect(fill="white", color=NA),
      complete=TRUE
    )
}

theme_set(theme_publication())

LINEAGE_COLORS <- c(
  "XBB.1.5"  = "#E64B35", "XBB.1.16" = "#4DBBD5",
  "BQ.1.1"   = "#00A087", "BA.5"      = "#3C5488",
  "BA.2.75"  = "#F39B7F", "BA.4"      = "#8491B4",
  "Other"    = "#B09C85", "Unknown"   = "#AAAAAA"
)

QC_COLORS <- c("PASS"="#00A087", "FLAG"="#F39B7F", "FAIL"="#E64B35")

GENE_COLORS <- c(
  "ORF1a"="#3C5488", "ORF1b"="#4DBBD5", "S"="#E64B35",
  "ORF3a"="#00A087", "E"="#F39B7F",     "M"="#8491B4",
  "ORF6"="#B09C85",  "ORF7a"="#DC0000", "ORF7b"="#7E6148",
  "ORF8"="#631879",  "N"="#008B45",     "ORF10"="#BB0021"
)

SARSCOV2_GENES <- data.frame(
  gene  = c("ORF1a","ORF1b","S","ORF3a","E","M","ORF6","ORF7a","ORF7b","ORF8","N","ORF10"),
  start = c(266,13468,21563,25393,26245,26523,27202,27394,27756,27894,28274,29558),
  end   = c(13483,21555,25384,26220,26472,27191,27387,27759,27887,28259,29533,29674),
  stringsAsFactors=FALSE
)

save_figure <- function(plot, filepath, width=10, height=7,
                        dpi=300, formats=c("pdf","png")) {
  dir.create(dirname(filepath), showWarnings=FALSE, recursive=TRUE)
  for (fmt in formats) {
    outfile <- paste0(filepath, ".", fmt)
    if (fmt == "png") {
      ragg::agg_png(filename=outfile, width=width, height=height,
                    units="in", res=dpi, background="white")
      print(plot)
      dev.off()
    } else if (fmt == "pdf") {
      cairo_pdf(filename=outfile, width=width, height=height, bg="white")
      print(plot)
      dev.off()
    } else {
      ggplot2::ggsave(filename=outfile, plot=plot,
                      width=width, height=height, dpi=dpi, bg="white")
    }
    message("  Saved: ", outfile)
  }
  invisible(plot)
}

message("✅ theme_publication.R loaded")
