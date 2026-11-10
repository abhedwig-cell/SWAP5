"""Audit accepted Grassgrowth day-188 root traces against both daily controls."""
import argparse
import csv
import json
import math
from pathlib import Path
import tarfile

from replay_grass_oxygen188 import ROOT, sha

BUDGET_FIELDS = ("potential_cm", "uptake_cm", "drought_cm", "oxygen_cm")
B0_FIELDS = ("TPOT", "TACT", "TREDDRY", "TREDWET")
NODE_COUNT = 113


def records(path, model):
    tags = {}
    for line in path.read_text(errors="replace").splitlines():
        fields = line.split()
        if fields and fields[0].startswith(model.upper() + "_"):
            tags.setdefault(fields[0].split("_")[1], []).append(list(map(float, fields[1:])))
    roots, nodes = tags["ROOT"], tags["NODES"]
    assert len(roots) == len(nodes)
    if model == "legacy":
        roots = [[r[0]-29220, r[0]-29220+r[1], *r[2:]] for r in roots]
        head = [n[:NODE_COUNT] for n in nodes]
        nodes = [n[NODE_COUNT:3*NODE_COUNT] + n[4*NODE_COUNT:] for n in nodes]
    else:
        head = tags["HEAD"]
    assert len(head) == len(roots)
    assert all(len(h) == NODE_COUNT and len(n) == 3*NODE_COUNT for h, n in zip(head, nodes))
    assert roots[0][0] == 187 and abs(roots[-1][1]-188) < 1e-8
    assert all(r[1] > r[0] for r in roots)
    assert all(abs(a[1]-b[0]) < 1e-8 for a, b in zip(roots, roots[1:]))
    return roots, [h+n for h, n in zip(head, nodes)], sorted(tags)


def summarize(rows):
    stressed = [r for r in rows if r[5] > 0]
    return {
        "trace_intervals": len(rows),
        "integral_cm": dict(zip(BUDGET_FIELDS, (
            math.fsum((r[1]-r[0])*r[i] for r in rows) for i in range(2, 6)
        ))),
        "root_depth_cm": sorted({r[6] for r in rows}),
        "first_oxygen_minute": (stressed[0][0]-187)*1440,
        "last_oxygen_end_minute": (stressed[-1][1]-187)*1440,
        "peak_oxygen_rate_cm_day": max(r[5] for r in stressed),
    }


def compare(native, legacy, native_nodes, legacy_nodes):
    i = j = 0
    best = None
    demand_terms, fraction_terms = [], []
    while i < len(native) and j < len(legacy):
        n, l = native[i], legacy[j]
        start, end = max(n[0], l[0]), min(n[1], l[1])
        if start < end:
            n_fraction, l_fraction = n[5]/n[2], l[5]/l[2]
            dt = end-start
            demand_terms.append(dt*(n[2]-l[2])*(n_fraction+l_fraction)/2)
            fraction_terms.append(dt*(n_fraction-l_fraction)*(n[2]+l[2])/2)
            if best is None or abs(n[5]-l[5]) > best[0]:
                best = (abs(n[5]-l[5]), i, j, start, end)
        if n[1] <= l[1]:
            i += 1
        if l[1] <= n[1]:
            j += 1
    _, i, j, start, end = best
    labels = ("pressure_head_cm", "water_content", "temperature_c", "root_sink_cm_day")
    deltas = {}
    for k, label in enumerate(labels):
        offset = k*NODE_COUNT
        paired = list(zip(native_nodes[i][offset:offset+NODE_COUNT], legacy_nodes[j][offset:offset+NODE_COUNT]))
        idx = max(range(NODE_COUNT), key=lambda a: abs(paired[a][0]-paired[a][1]))
        deltas[label] = {"node_1_based": idx+1, "native": paired[idx][0], "legacy": paired[idx][1]}
    return {
        "oxygen_delta_native_minus_legacy_cm": {
            "potential_demand_term": math.fsum(demand_terms),
            "oxygen_fraction_term": math.fsum(fraction_terms),
        },
        "largest_overlapping_oxygen_rate_gap": {
            "overlap_minutes": [(t-187)*1440 for t in (start, end)],
            "native_start_minute": (native[i][0]-187)*1440,
            "legacy_start_minute": (legacy[j][0]-187)*1440,
            "native_oxygen_cm_day": native[i][5], "legacy_oxygen_cm_day": legacy[j][5],
            "native_deepest_oxygen_factor": native[i][7], "legacy_deepest_oxygen_factor": legacy[j][7],
            "largest_absolute_nodal_difference_at_own_step_starts": deltas,
        },
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("observation", type=Path)
    parser.add_argument("control", type=Path)
    args = parser.parse_args()
    out = args.observation
    build = json.loads((out/"RESULT.json").read_text())
    for model in ("native", "legacy"):
        assert sha(out/model/"stdout") == build[model]["stdout_sha256"]
    native, nn, nt = records(out/"native/stdout", "native")
    legacy, ln, lt = records(out/"legacy/stdout", "legacy")
    ns, ls = summarize(native), summarize(legacy)
    with (out/"native/budget.csv").open(newline="") as f:
        day, = csv.DictReader(f)
    with (args.control/"budget.csv").open(newline="") as f:
        retained = next(row for row in csv.DictReader(f) if row["day"] == "188")
    assert day == retained
    archive = ROOT/"integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz"
    refs = {}
    with tarfile.open(archive) as tar:
        for name, member in (("B0", "dq15-original-nodal-reference"), ("B1", "dq15-continuous-B1-reference")):
            with tar.extractfile(member+"/original/result_output.csv") as f:
                lines = (line.decode() for line in f if not line.startswith(b"*"))
                row = next(r for r in csv.DictReader(lines) if r["DATE"] == "1980-07-06")
                refs[name] = dict(zip(BUDGET_FIELDS, (float(row[k]) for k in B0_FIELDS)))
    for summary, control in ((ns, day), (ls, refs["B0"])):
        assert all(abs(summary["integral_cm"][k]-float(control[k])) <= 1e-10 for k in BUDGET_FIELDS)
    assert sha(out/"native/checkpoint.bin") == sha(args.control/"checkpoint-188.bin")
    evidence = {
        "day": 188, "date": "1980-07-06", "reference_archive_sha256": sha(archive),
        "build": {name: {k: v for k, v in detail.items() if k != "commands"} for name, detail in build.items()},
        "native": ns, "legacy": ls, "archived_references": refs,
        "native_trace_tags": nt, "legacy_trace_tags": lt,
        "native_reported_accepted_steps": int(day["accepted_steps"]),
        "native_water_balance_cm": float(day["residual_cm"]),
        "native_checkpoint_byte_identical": True,
        "comparison": compare(native, legacy, nn, ln),
    }
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
