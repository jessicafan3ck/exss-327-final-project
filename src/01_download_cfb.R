# Download pre-built college football play-by-play (cfbfastR / sportsdataverse) into data/raw/cfb/.
# These are the same files cfbfastR::load_cfb_pbp() reads; they are hosted on GitHub releases
# and need no CFBD API key.
# Usage: Rscript --vanilla src/01_download_cfb.R [first_season last_season]

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))))
root <- dirname(script_dir)
out_dir <- file.path(root, "data", "raw", "cfb")
url_pattern <- paste0("https://github.com/sportsdataverse/sportsdataverse-data/releases/download/",
                      "cfbfastR_cfb_pbp/play_by_play_%d.parquet")

args <- as.integer(commandArgs(trailingOnly = TRUE))
seasons <- if (length(args) == 2) args[1]:args[2] else 2018:2025

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1200)
for (season in seasons) {
  dest <- file.path(out_dir, sprintf("play_by_play_%d.parquet", season))
  if (file.exists(dest) && file.size(dest) > 0) {
    message(sprintf("%d: already present (%.1f MB)", season, file.size(dest) / 1e6))
    next
  }
  tmp <- paste0(dest, ".part")
  download.file(sprintf(url_pattern, season), tmp, mode = "wb", quiet = TRUE)
  file.rename(tmp, dest)
  message(sprintf("%d: downloaded (%.1f MB)", season, file.size(dest) / 1e6))
}
