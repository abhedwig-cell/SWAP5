#!/usr/bin/env python3
"""F-MACRO-ALT18: GFZ Griessfirn soil-moisture and dye parser.

Research-only.
Parses the published GFZ 2024 tab-delimited soil-moisture files and trinary
Brilliant Blue matrices once the files are materialized locally.

No RFM parameters are fitted here.
"""

from __future__ import annotations

import csv
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path
from statistics import mean


TS_FMT = "%d.%m.%Y %H:%M"


def parse_float(x):
    try:
        v = float(x)
        return v if math.isfinite(v) else None
    except Exception:
        return None


def read_tab_file(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        rows = [line for line in f if line.strip() and not line.lstrip().startswith("#")]
    reader = csv.DictReader(rows, delimiter="	")
    return list(reader), reader.fieldnames or []


def infer_plot_ids(fieldnames):
    ids = set()
    for name in fieldnames:
        m = re.match(r"(?:TS|SMT10_1|SMT30|SMT50|SMT10_2|SMT10_3|SMT10_4)_(.+)$", name)
        if m:
            ids.add(m.group(1))
    return sorted(ids)


def parse_time(x):
    if not x:
        return None
    try:
        return datetime.strptime(x.strip(), TS_FMT)
    except Exception:
        return None


def soil_moisture_summary(path: Path, onset_delta=0.002):
    rows, fields = read_tab_file(path)
    plots = infer_plot_ids(fields)
    result = {"file": path.name, "plots": {}}

    for plot in plots:
        series = []
        for row in rows:
            t = parse_time(row.get(f"TS_{plot}", ""))
            if t is None:
                continue
            vals = {
                "theta10": parse_float(row.get(f"SMT10_1_{plot}")),
                "theta30": parse_float(row.get(f"SMT30_{plot}")),
                "theta50": parse_float(row.get(f"SMT50_{plot}")),
                "theta10_2": parse_float(row.get(f"SMT10_2_{plot}")),
                "theta10_3": parse_float(row.get(f"SMT10_3_{plot}")),
                "theta10_4": parse_float(row.get(f"SMT10_4_{plot}")),
            }
            series.append((t, vals))

        result["plots"][plot] = {
            "n": len(series),
            "start": series[0][0].isoformat() if series else None,
            "end": series[-1][0].isoformat() if series else None,
            "series": [
                {"time": t.isoformat(), **vals}
                for t, vals in series
            ],
        }

    return result


def read_trinary(path: Path):
    matrix = []
    with path.open("r", encoding="utf-8-sig") as f:
        for line in f:
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            vals = [int(x) for x in re.split(r"[	 ,;]+", line.strip()) if x]
            if vals:
                matrix.append(vals)
    if not matrix:
        raise ValueError(f"{path}: empty trinary matrix")

    width = max(len(r) for r in matrix)
    rows = []
    for depth_mm, r in enumerate(matrix):
        valid = [v for v in r if v in (1, 2, 3)]
        stained = sum(v == 3 for v in valid)
        soil = sum(v in (2, 3) for v in valid)
        rows.append({
            "depth_mm": depth_mm,
            "stained_fraction_of_soil": stained / soil if soil else None,
            "stained_pixels": stained,
            "soil_pixels": soil,
        })

    stained_depths = [r["depth_mm"] for r in rows if r["stained_pixels"] > 0]
    return {
        "file": path.name,
        "height_mm": len(matrix),
        "width_px_max": width,
        "max_stained_depth_mm": max(stained_depths) if stained_depths else None,
        "depth_profile": rows,
    }


def main(argv):
    if len(argv) < 2:
        raise SystemExit(
            "usage: macropore_alt18_gfz_parser.py FILE.txt [FILE.txt ...]\n"
            "Soilmoisture files and TrinaryImage files can be mixed."
        )

    soil = []
    dye = []
    for p in map(Path, argv[1:]):
        if "TrinaryImage" in p.name:
            dye.append(read_trinary(p))
        elif "Soilmoisture" in p.name:
            soil.append(soil_moisture_summary(p))
        else:
            raise ValueError(f"unrecognized GFZ file type: {p.name}")

    print(json.dumps({
        "schema": "swap5.f_macro_alt18.gfz_griessfirn.v1",
        "status": "RESEARCH_ONLY",
        "soil_moisture_files": soil,
        "trinary_files": dye,
        "qualification_boundary": (
            "Parser is schema-bound to the official GFZ data description. "
            "Event onset extraction requires irrigation timestamps/intensity mapping "
            "from the materialized files or companion experiment metadata."
        ),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv)
