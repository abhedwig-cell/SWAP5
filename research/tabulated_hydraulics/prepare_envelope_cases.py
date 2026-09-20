#!/usr/bin/env python3
"""Prepare a bounded hydraulic-envelope matrix for TAB-HYD.

Research harness only.  All scenarios reuse the pinned Hupsel application
structure and meteorological forcing, but replace the two constitutive
parameter rows with contrasting Staring-series MvG parameterizations and
vary initial/bottom/irrigation conditions.  Each analytical case has a
paired 250-row uniform-x tabulated case generated from the exact same
implemented constitutive policy.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import shutil
from pathlib import Path

HCRIT = -1.0e-2
RELSAT_KSAT = 1.0 - 1.0e-6
NROWS = 250

SCENARIOS = {
    "coarse_dry_free": {
        "top": "b4", "sub": "o5", "gwli": -180.0, "swbotb": 6,
        "gwlevel": None, "irdepth": 5.0,
        "purpose": "coarse high-K, dry initial state, free lower boundary",
    },
    "loam_mid_free": {
        "top": "b9", "sub": "o9", "gwli": -75.0, "swbotb": 6,
        "gwlevel": None, "irdepth": 5.0,
        "purpose": "loam, intermediate initial state, free lower boundary",
    },
    "clay_wet_free": {
        "top": "b12", "sub": "o13", "gwli": -40.0, "swbotb": 6,
        "gwlevel": None, "irdepth": 5.0,
        "purpose": "heavy clay, wet initial state, free lower boundary",
    },
    "coarse_dry_pulse": {
        "top": "b4", "sub": "o5", "gwli": -180.0, "swbotb": 6,
        "gwlevel": None, "irdepth": 50.0,
        "purpose": "coarse dry soil with strong infiltration pulse",
    },
    "loam_capillary": {
        "top": "b9", "sub": "o9", "gwli": -120.0, "swbotb": 1,
        "gwlevel": -120.0, "irdepth": 5.0,
        "purpose": "loam with prescribed shallow groundwater for capillary support",
    },
}


def read_staring(path: Path):
    rows = {}
    with path.open(newline="") as fh:
        reader = csv.DictReader(fh)
        for raw in reader:
            row = {k.strip(): v.strip() for k, v in raw.items()}
            spu = row["SPU"].lower()
            rows[spu] = {
                "ores": float(row["ORES"]),
                "osat": float(row["OSAT"]),
                "alpha": float(row["ALFAD"]),
                "n": float(row["NPAR"]),
                "ksat": float(row["KSAT"]),
                "lexp": float(row["LEXP"]),
                "alfaw": float(row["ALFAW"]),
                "h_enpr": float(row["H_ENPR"]),
                "comment": row["comment"],
            }
    return rows


def theta_policy(h: float, p: dict) -> float:
    if p["h_enpr"] != 0.0:
        raise ValueError("envelope harness currently admits only H_ENPR=0")
    ores, osat, alpha, n = p["ores"], p["osat"], p["alpha"], p["n"]
    m = 1.0 - 1.0 / n
    if h >= 0.0:
        return osat
    if h > HCRIT:
        help0 = abs(alpha * HCRIT) ** n
        theta_crit = ores + (osat - ores) / ((1.0 + help0) ** m)
        return min(theta_crit + (osat - theta_crit) / (-HCRIT) * (h - HCRIT), osat)
    return ores + (osat - ores) / ((1.0 + abs(alpha * h) ** n) ** m)


def k_policy(h: float, p: dict) -> float:
    ores, osat, n, ksat, lexp = p["ores"], p["osat"], p["n"], p["ksat"], p["lexp"]
    m = 1.0 - 1.0 / n
    th = theta_policy(h, p)
    se = max(0.0, min(1.0, (th - ores) / (osat - ores)))
    if h < -1.0e14:
        return 1.0e-10
    if se > RELSAT_KSAT:
        return ksat
    if se <= 0.0:
        return 1.0e-300
    t = math.exp(math.log(se) / m)
    # Stable form of 1-(1-t)^m.
    bracket = -math.expm1(m * math.log1p(-min(t, 1.0 - 1.0e-16)))
    logk = math.log(ksat) + lexp * math.log(se) + 2.0 * math.log(max(bracket, 1.0e-300))
    return min(ksat, math.exp(max(logk, math.log(1.0e-300))))


def threshold_head(p: dict, margin: float = 1.0e-8) -> float:
    lo, hi = -1.0e7, -1.0e-12
    target = p["ksat"] * (1.0 - margin)
    klo, khi = k_policy(lo, p), k_policy(hi, p)
    if not (klo < target < khi):
        raise RuntimeError((p["comment"], "strict-K wet endpoint not bracketed", klo, target, khi))
    for _ in range(140):
        mid = 0.5 * (lo + hi)
        if k_policy(mid, p) <= target:
            lo = mid
        else:
            hi = mid
    return lo


def uniform_rows(p: dict, n: int = NROWS):
    h0 = -1.0e7
    h1 = threshold_head(p)
    x0 = -math.log(1.0 - h0)
    x1 = -math.log(1.0 - h1)
    rows = []
    for i in range(n - 1):
        frac = i / (n - 2)
        x = x0 + frac * (x1 - x0)
        h = h1 if i == n - 2 else 1.0 - math.exp(-x)
        rows.append((h, theta_policy(h, p), k_policy(h, p)))
    rows.append((0.0, p["osat"], p["ksat"]))
    for a, b in zip(rows, rows[1:]):
        if not (b[0] > a[0] and b[1] > a[1] and b[2] > a[2]):
            raise RuntimeError((p["comment"], "nonmonotone table", a, b))
    return rows


def write_table(path: Path, p: dict):
    rows = uniform_rows(p)
    with path.open("w", newline="\n") as fh:
        fh.write("* TAB-HYD envelope uniform transformed-x table\n")
        fh.write("headtab,thetatab,conductab\n")
        for h, theta, k in rows:
            fh.write(f"{h:.16e},{theta:.16e},{k:.16e}\n")
    return rows


def replace_scalar(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"(?m)^(\s*{re.escape(key)}\s*=\s*)[^!\r\n]+")
    text, n = pat.subn(rf"\g<1>{value} ", text, count=1)
    if n != 1:
        raise RuntimeError(f"could not replace {key}")
    return text


def replace_mvg_rows(text: str, params: list[dict]) -> str:
    lines = text.splitlines()
    header = next(
        i for i, line in enumerate(lines)
        if re.search(r"^\s*ORES\b.*\bOSAT\b.*\bALFA\b.*\bNPAR\b.*\bKSATFIT\b.*\bLEXP\b", line, re.I)
    )
    data_idx = []
    for i in range(header + 1, len(lines)):
        s = lines[i].strip()
        if s.startswith("*") and data_idx:
            break
        if not s or s.startswith("*"):
            continue
        parts = s.split()
        try:
            nums = [float(x) for x in parts]
        except ValueError:
            if data_idx:
                break
            continue
        if len(nums) >= 6:
            data_idx.append(i)
    if len(data_idx) != 2:
        raise RuntimeError(f"expected exactly two Hupsel MvG rows, found {len(data_idx)}")
    for idx, p in zip(data_idx, params):
        lines[idx] = (
            f" {p['ores']:.8g} {p['osat']:.8g} {p['alpha']:.8g} {p['n']:.8g} "
            f"{p['ksat']:.8g} {p['lexp']:.8g} {p['alfaw']:.8g} {p['h_enpr']:.8g} "
            f"{p['ksat']:.8g} 1315.0"
        )
    return "\n".join(lines) + "\n"


def replace_groundwater_table(text: str, level: float) -> str:
    lines = text.splitlines()
    header = next(i for i, line in enumerate(lines) if re.search(r"\bDATE1\b.*\bGWLEVEL\b", line))
    rows = []
    for i in range(header + 1, len(lines)):
        s = lines[i].strip()
        if s.startswith("*") and rows:
            break
        if not s or s.startswith("*"):
            continue
        if re.match(r"\d{4}-\d{2}-\d{2}\s+", s):
            rows.append(i)
        if len(rows) == 2:
            break
    if len(rows) != 2:
        raise RuntimeError("expected two DATE1/GWLEVEL rows")
    dates = [lines[i].strip().split()[0] for i in rows]
    for i, date in zip(rows, dates):
        lines[i] = f" {date} {level:.8g}"
    return "\n".join(lines) + "\n"


def replace_irrigation_depth(text: str, depth: float) -> str:
    # Hupsel has one fixed irrigation event table with IRDEPTH as second numeric field.
    lines = text.splitlines()
    header = next(i for i, line in enumerate(lines) if re.search(r"\bIRDATE\b.*\bIRDEPTH\b", line))
    for i in range(header + 1, len(lines)):
        s = lines[i].strip()
        if not s or s.startswith("*"):
            continue
        parts = s.split()
        if re.match(r"\d{4}-\d{2}-\d{2}$", parts[0]) and len(parts) >= 4:
            parts[1] = f"{depth:.8g}"
            lines[i] = " " + " ".join(parts)
            return "\n".join(lines) + "\n"
    raise RuntimeError("fixed irrigation event not found")


def prepare_case(src: Path, dst: Path, params: list[dict], spec: dict, table: bool, kimpl: int):
    shutil.copytree(src, dst)
    template = dst / "swap_linux.swp.template"
    text = template.read_text()
    text = replace_scalar(text, "SWSOPHY", "1" if table else "0")
    text = replace_scalar(text, "SWKIMPL", str(kimpl))
    text = replace_scalar(text, "SWMONTH", "0")
    text = replace_scalar(text, "GWLI", f"{spec['gwli']:.8g}")
    text = replace_scalar(text, "SWBOTB", str(spec["swbotb"]))
    text = replace_mvg_rows(text, params)
    text = replace_irrigation_depth(text, spec["irdepth"])

    table_names = ["tabhyd_top.csv", "tabhyd_sub.csv"]
    pat = re.compile(r"(?m)^(\s*FILENAMESOPHY\s*=\s*).*$")
    text, n = pat.subn(
        r"\g<1>" + " ".join(f"'{name}'" for name in table_names),
        text,
        count=1,
    )
    if n != 1:
        raise RuntimeError("FILENAMESOPHY line not found")

    if spec["swbotb"] == 1:
        text = replace_groundwater_table(text, spec["gwlevel"])

    (dst / "swap.swp").write_text(text)
    if table:
        for name, p in zip(table_names, params):
            write_table(dst / name, p)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hupsel_case", type=Path)
    ap.add_argument("staring_csv", type=Path)
    ap.add_argument("output_root", type=Path)
    ns = ap.parse_args()

    if ns.output_root.exists():
        shutil.rmtree(ns.output_root)
    ns.output_root.mkdir(parents=True)

    series = read_staring(ns.staring_csv)
    manifest = {}
    for scenario, spec in SCENARIOS.items():
        params = [series[spec["top"]], series[spec["sub"]]]
        manifest[scenario] = {
            **spec,
            "top_comment": params[0]["comment"],
            "sub_comment": params[1]["comment"],
            "table_rows": NROWS,
        }
        for kimpl in (0, 1):
            for route, table in (("analytic", False), ("table", True)):
                dst = ns.output_root / f"{scenario}__{route}_k{kimpl}"
                prepare_case(ns.hupsel_case, dst, params, spec, table=table, kimpl=kimpl)
                print(f"CASE {dst.name} table={int(table)} swkimpl={kimpl}")

    (ns.output_root / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"SCENARIOS={len(SCENARIOS)}")
    print("ENVELOPE_PREP_COMPLETED")


if __name__ == "__main__":
    main()
