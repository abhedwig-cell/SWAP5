#!/usr/bin/env python3
"""F-MACRO-ALT49: GFZ/Hartmann dye shape operator test for RFM connectivity p.

Research-only. Standard library only.

Frozen morphological observation hypothesis tested here:
  stained_fraction(z) ~= A * [1 - x(z)^p]
with x = z / z_max_stained for each photographed profile.

A is a nuisance amplitude and is fitted separately per profile.
p is structural and should transfer across treatment within one plot if this
simple dye-to-active-connectivity observation operator is valid.

Failure of this operator does not by itself falsify RFM C(z)=1-x^p, because
dye staining may not be proportional to active pathway occupancy.
"""

from __future__ import annotations
import json, math, os, re, statistics, sys, zipfile
from collections import defaultdict

TRI_RE = re.compile(
    r"TrinaryImage_([CS])_(\d+)_(left|middle|right)_(\d+)mm(h)?_(\d+)\.txt$"
)
P_GRID = [10 ** (-1.3 + i * (3.0 / 160.0)) for i in range(161)]


def parse_profile(text):
    rows = []
    max_depth = -1
    for depth, line in enumerate(text.splitlines()):
        vals = []
        for token in re.split(r"[\t ,;]+", line.strip()):
            if not token:
                continue
            try:
                v = int(token)
            except ValueError:
                continue
            if v in (1, 2, 3):
                vals.append(v)
        soil = sum(v in (2, 3) for v in vals)
        stained = sum(v == 3 for v in vals)
        if soil:
            frac = stained / soil
            rows.append((depth, frac, stained, soil))
            if stained:
                max_depth = depth
    return rows, max_depth


def fit_profile(rows, max_depth, p):
    obs = [(d, s) for d, s, _, _ in rows if d <= max_depth]
    shape = [1.0 - ((d + 0.5) / (max_depth + 1.0)) ** p for d, _ in obs]
    den = sum(q * q for q in shape)
    amp = max(0.0, sum(q * s for q, (_, s) in zip(shape, obs)) / den) if den else 0.0
    sse = sum((s - amp * q) ** 2 for q, (_, s) in zip(shape, obs))
    return sse, amp


def best_fit(rows, max_depth):
    mean_s = statistics.mean(s for d, s, _, _ in rows if d <= max_depth)
    sst = sum((s - mean_s) ** 2 for d, s, _, _ in rows if d <= max_depth)
    best = None
    for p in P_GRID:
        sse, amp = fit_profile(rows, max_depth, p)
        if best is None or sse < best[0]:
            best = (sse, p, amp)
    sse, p, amp = best
    r2 = 1.0 - sse / sst if sst > 0.0 else None
    return p, amp, r2, sse, sst


def fit_shared(profiles):
    best = None
    sst = sum(p["sst"] for p in profiles)
    for pval in P_GRID:
        sse = 0.0
        for p in profiles:
            q, _ = fit_profile(p["rows"], p["max_depth"], pval)
            sse += q
        if best is None or sse < best[0]:
            best = (sse, pval)
    sse, pval = best
    r2 = 1.0 - sse / sst if sst > 0 else None
    return pval, sse, r2


def main(path):
    profiles = []
    with zipfile.ZipFile(path) as z:
        names = [
            n for n in z.namelist()
            if "/2024-001_Hartmann-et-al_Trinary_Images/" in n
            and "TrinaryImage" in n and n.endswith(".txt") and "/._" not in n
        ]
        for name in names:
            m = TRI_RE.search(os.path.basename(name))
            if not m:
                continue
            parent, age, plot, treatment, is_intensity, profile_no = m.groups()
            rows, max_depth = parse_profile(z.read(name).decode("utf-8-sig", errors="replace"))
            if max_depth < 20:
                continue
            pfit, amp, r2, sse, sst = best_fit(rows, max_depth)
            profiles.append({
                "parent": parent,
                "age_year": int(age),
                "plot": plot,
                "treatment": int(treatment),
                "treatment_kind": "intensity_mm_h" if is_intensity else "amount_mm",
                "profile_no": int(profile_no),
                "max_depth_mm": max_depth,
                "p_individual": pfit,
                "amplitude": amp,
                "r2_individual": r2,
                "rows": rows,
                "sse": sse,
                "sst": sst,
            })

    by_plot = defaultdict(list)
    for p in profiles:
        by_plot[(p["parent"], p["age_year"], p["plot"])].append(p)

    plot_results = []
    for key, vals in sorted(by_plot.items()):
        p_shared, sse_shared, r2_shared = fit_shared(vals)
        by_treatment = defaultdict(list)
        for p in vals:
            by_treatment[p["treatment"]].append(p)
        treatment_fits = {}
        treatment_sse = 0.0
        for treatment, subset in sorted(by_treatment.items()):
            p_t, sse_t, r2_t = fit_shared(subset)
            treatment_fits[str(treatment)] = {"p": p_t, "r2": r2_t}
            treatment_sse += sse_t
        improvement = (
            (sse_shared - treatment_sse) / sse_shared if sse_shared > 0.0 else 0.0
        )
        plot_results.append({
            "parent": key[0],
            "age_year": key[1],
            "plot": key[2],
            "p_shared": p_shared,
            "r2_shared": r2_shared,
            "treatment_fits": treatment_fits,
            "relative_sse_improvement_with_treatment_specific_p": improvement,
        })

    r2s = [r["r2_shared"] for r in plot_results if r["r2_shared"] is not None]
    result = {
        "schema": "swap5.f_macro_alt49.gfz_dye_shape_operator.v1",
        "status": "RESEARCH_ONLY",
        "n_trinary_profiles": len(profiles),
        "n_structural_plots": len(plot_results),
        "operator": "stained_fraction(z) = A_profile * (1 - (z/zmax)^p)",
        "median_shared_plot_r2": statistics.median(r2s),
        "plots_shared_r2_ge_0_5": sum(r["r2_shared"] is not None and r["r2_shared"] >= 0.5 for r in plot_results),
        "plots_treatment_specific_p_improves_sse_gt_10pct": sum(
            r["relative_sse_improvement_with_treatment_specific_p"] > 0.10
            for r in plot_results
        ),
        "plot_results": plot_results,
        "decision": (
            "The direct proportional-staining-to-RFM-survival observation operator "
            "is not a generally valid quantitative p estimator. Retain dye metrics "
            "for qualitative/depth-shape falsification, but do not calibrate p from "
            "this operator without an independently justified staining model."
        ),
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: macropore_alt49_gfz_dye_shape.py GFZ_DATA.zip")
    main(sys.argv[1])
