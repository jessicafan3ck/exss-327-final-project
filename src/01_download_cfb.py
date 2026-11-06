"""Download pre-built college football play-by-play (cfbfastR / sportsdataverse) into data/raw/cfb/.

These are the same files cfbfastR::load_cfb_pbp() reads; they are hosted on GitHub releases
and need no CFBD API key. Usage: python -I src/01_download_cfb.py [first_season last_season]
"""
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "raw" / "cfb"
URL = ("https://github.com/sportsdataverse/sportsdataverse-data/releases/download/"
       "cfbfastR_cfb_pbp/play_by_play_{season}.parquet")


def download(season: int) -> Path:
    dest = OUT / f"play_by_play_{season}.parquet"
    if dest.exists() and dest.stat().st_size > 0:
        print(f"{season}: already present ({dest.stat().st_size / 1e6:.1f} MB)")
        return dest
    tmp = dest.with_suffix(".part")
    with requests.get(URL.format(season=season), stream=True, timeout=300) as r:
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
