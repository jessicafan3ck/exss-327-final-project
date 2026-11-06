# Shared figure styling. Colors are slots 1-2 of the validated categorical palette (light mode).
suppressPackageStartupMessages(library(ggplot2))

league_colors <- c(NFL = "#2a78d6", NCAA = "#eb6834")
league_labels <- c(NFL = "NFL", NCAA = "College (FBS)")
surface <- "#fcfcfb"; ink <- "#0b0b0b"; ink_2 <- "#52514e"; grid_col <- "#e4e3df"

theme_kball <- function() {
  theme_minimal(base_size = 10) +
    theme(
      plot.background = element_rect(fill = surface, colour = NA),
      panel.background = element_rect(fill = surface, colour = NA),
      panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(colour = grid_col, linewidth = 0.4),
      axis.line.x = element_line(colour = grid_col), axis.ticks = element_blank(),
      axis.text = element_text(colour = ink_2, size = 9), axis.title = element_text(colour = ink_2, size = 9),
      plot.title = element_text(colour = ink, size = 12), plot.title.position = "plot",
      plot.caption = element_text(colour = ink_2, size = 7.5, hjust = 0), plot.caption.position = "plot",
      strip.text = element_text(colour = ink, size = 11, hjust = 0),
      legend.position = "top", legend.justification = "left", legend.title = element_blank(),
      legend.text = element_text(colour = ink, size = 9)
    )
}

# Shaded band + label marking the 2025 (post-rule) season
mark_2025 <- function() {
  list(
    annotate("rect", xmin = 2024.5, xmax = 2025.5, ymin = -Inf, ymax = Inf, fill = grid_col, alpha = 0.6),
    annotate("text", x = 2025, y = Inf, label = "K-ball rule", vjust = -0.4, size = 2.8, colour = ink_2),
    coord_cartesian(clip = "off")
  )
}

save_fig <- function(p, path, width = 7.5, height = 4.2) {
  ggsave(path, p, width = width, height = height, dpi = 200, bg = surface)
}
