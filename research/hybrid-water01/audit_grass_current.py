"""Audit Grassgrowth current-source runs and exact fresh-process continuations."""
import argparse
import csv
from hashlib import sha256
import json
from itertools import islice
import math
from pathlib import Path

LEDGERS = ("budget.csv", "conductive_budget.csv", "crop.csv")
REVIEW_SOURCE = "a8275101d91f0ab5b413290e9b00bb5666b11917"
OUTPUTS = (*LEDGERS, "checkpoint.bin", "state.csv", "endpoint.csv")


def sha(path):
    return sha256(path.read_bytes()).hexdigest()


def read_csv(path, limit=None):
    with path.open(newline="") as stream:
        return list(islice(csv.DictReader(stream), limit))


def audit(run, first, last):
    water, heat, crop = (read_csv(run / name) for name in LEDGERS)
    for ledger in (water, heat, crop):
        assert [int(row["day"]) for row in ledger] == list(range(first, last + 1))
        assert all(math.isfinite(float(v)) for row in ledger for v in row.values())
    assert all(w["accepted_steps"] == h["accepted_steps"] and w["t1"] == h["t1"]
               for w, h in zip(water, heat))
    for w, h in zip(water, heat):
        w = {k: float(v) for k, v in w.items()}
        h = {k: float(v) for k, v in h.items()}
        assert abs(w["residual_cm"]) <= 1e-10
        assert abs(w["water_end_cm"] - w["water_start_cm"] - w["input_cm"] + w["output_cm"]) <= 1e-10
        assert abs(w["potential_cm"] - w["uptake_cm"] - w["drought_cm"] - w["oxygen_cm"]) <= 1e-10
        assert h["bottom_in_j_cm2"] == 0
        assert h["residual_j_cm2"] == h["storage_change_j_cm2"] - h["top_in_j_cm2"] - h["bottom_in_j_cm2"]
        assert abs(h["residual_j_cm2"]) < 1e-8
        assert abs(w["heat_residual_j_cm2"]) <= h["max_substep_residual_j_cm2"] < 1e-8
    stock_change = float(water[-1]["water_end_cm"]) - float(water[0]["water_start_cm"])
    net = math.fsum(float(row[k]) * sign for row in water for k, sign in (("input_cm", 1), ("output_cm", -1)))
    return {
        "days": [first, last],
        "accepted_steps": sum(int(row["accepted_steps"]) for row in water),
        "maximum_daily_water_residual_cm": max(abs(float(row["residual_cm"])) for row in water),
        "cumulative_water_residual_cm": stock_change - net,
        "maximum_daily_conductive_residual_j_cm2": max(abs(float(row["residual_j_cm2"])) for row in heat),
        "maximum_substep_conductive_residual_j_cm2": max(float(row["max_substep_residual_j_cm2"]) for row in heat),
        "output_sha256": {name: sha(run / name) for name in OUTPUTS},
    }


def restart(control, resumed, first, last, terminal=True):
    for name in LEDGERS:
        expected = [r for r in read_csv(control / name) if first <= int(r["day"]) <= last]
        assert read_csv(resumed / name) == expected, name
    if terminal:
        for name in ("checkpoint.bin", "state.csv", "endpoint.csv"):
            assert (control / name).read_bytes() == (resumed / name).read_bytes(), name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--wet", action="store_true")
    a = parser.parse_args()
    receipt = {"review_source": REVIEW_SOURCE}
    for opt in ("O0", "O2"):
        build = a.workspace / f"s5-grass-review-build-{opt}"
        control = build.with_name(build.name + "-control3")
        resume = build.with_name(build.name + "-resume3")
        result = json.loads((control / "RESULT.json").read_text())
        metadata = json.loads((build / "BUILD.json").read_text())
        assert metadata["executable_sha256"] == result["executable_sha256"] == sha(build / metadata["executable"])
        assert all(sha(Path(p)) == h for p, h in metadata["source_sha256"].items())
        assert metadata["original_inputs_sha256"] == result["input_sha256"]
        restart(control, resume, 2, 3)
        receipt[opt] = {
            "compiler": metadata["compiler"],
            "executable_sha256": result["executable_sha256"],
            "input_sha256": result["input_sha256"],
            "build_receipt_sha256": sha(build / "BUILD.json"),
            "control": audit(control, 1, 3),
            "restart": audit(resume, 2, 3),
        }
        if opt == "O2" and (a.wet or a.full):
            full = build.with_name(build.name + "-full")
            cut = build.with_name(build.name + "-cut188")
            end = build.with_name(build.name + "-resume190")
            for path in (cut, end):
                result = json.loads((path / "RESULT.json").read_text())
                assert result["executable_sha256"] == metadata["executable_sha256"]
                assert result["input_sha256"] == metadata["original_inputs_sha256"]
            for name in LEDGERS:
                continuous = read_csv(full / name, 190)
                assert [int(row["day"]) for row in continuous] == list(range(1, 191))
                assert read_csv(cut / name) == continuous[:188], name
                assert read_csv(end / name) == continuous[188:], name
            receipt[opt]["wet_event_cut"] = audit(cut, 1, 188)
            receipt[opt]["wet_event_restart"] = audit(end, 189, 190)
            receipt[opt]["wet_event_ledgers_match_continuous"] = True
            if a.full:
                receipt[opt]["full"] = audit(full, 1, 1827)
    for name in (*LEDGERS, "state.csv", "endpoint.csv"):
        assert receipt["O0"]["control"]["output_sha256"][name] == receipt["O2"]["control"]["output_sha256"][name]
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
