# Download nflverse play-by-play CSVs (one file per season) into data/raw/nfl/.
# These are the same files nflreadr::load_pbp() reads.
# Usage: Rscript --vanilla src/01_download_nfl.R [first_season last_season]
# Files already present are skipped. Downloaded files are treated as untrusted data.

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
out_dir <- file.path(root, "data", "raw", "nfl")
url_pattern <- "https://github.com/nflverse/nflverse-data/releases/download/pbp/play_by_play_%d.csv.gz"

args <- as.integer(commandArgs(trailingOnly = TRUE))
seasons <- if (length(args) == 2) args[1]:args[2] else 2018:2025

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 600)
for (season in seasons) {
  dest <- file.path(out_dir, sprintf("play_by_play_%d.csv.gz", season))
  if (file.exists(dest) && file.size(dest) > 0) {
    message(sprintf("%d: already present (%.1f MB)", season, file.size(dest) / 1e6))
    next
  }
  tmp <- paste0(dest, ".part")
  download.file(sprintf(url_pattern, season), tmp, mode = "wb", quiet = TRUE)
  file.rename(tmp, dest)
  message(sprintf("%d: downloaded (%.1f MB)", season, file.size(dest) / 1e6))
}
