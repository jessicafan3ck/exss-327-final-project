"""Download nflverse play-by-play CSVs (one file per season) into data/raw/nfl/.

Usage: python -I src/01_download_nfl.py [first_season last_season]
Files already present are skipped. Downloaded files are treated as untrusted data.
"""
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "raw" / "nfl"
URL = "https://github.com/nflverse/nflverse-data/releases/download/pbp/play_by_play_{season}.csv.gz"


def download(season: int) -> Path:
    dest = OUT / f"play_by_play_{season}.csv.gz"
    if dest.exists() and dest.stat().st_size > 0:
        print(f"{season}: already present ({dest.stat().st_size / 1e6:.1f} MB)")
        return dest
    tmp = dest.with_suffix(".part")
    with requests.get(URL.format(season=season), stream=True, timeout=120) as r:
        r.raise_for_status()
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
    tmp.rename(dest)
    print(f"{season}: downloaded ({dest.stat().st_size / 1e6:.1f} MB)")
    return dest


if __name__ == "__main__":
    first, last = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) == 3 else (2018, 2025)
    OUT.mkdir(parents=True, exist_ok=True)
    for season in range(first, last + 1):
        download(season)
