"""Audit Grassgrowth current-source runs and exact fresh-process continuations."""
import argparse
import csv
from datetime import date, timedelta
from hashlib import sha256
import json
from itertools import islice
import io
import math
from pathlib import Path
import tarfile

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
    assert [float(r["t1"]) for r in water] == list(range(first, last+1))
    assert all(abs(float(a["water_end_cm"])-float(b["water_start_cm"])) <= 1e-10
               for a, b in zip(water, water[1:]))
    uptake_errors = []
    for w, h in zip(water, heat):
        w = {k: float(v) for k, v in w.items()}
        h = {k: float(v) for k, v in h.items()}
        assert abs(w["residual_cm"]) <= 1e-10
        assert abs(w["water_end_cm"] - w["water_start_cm"] - w["input_cm"] + w["output_cm"]) <= 1e-10
        uptake_error = abs(w["potential_cm"] - w["uptake_cm"] - w["drought_cm"] - w["oxygen_cm"])
        assert uptake_error <= 1e-10
        uptake_errors.append(uptake_error)
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
        "maximum_uptake_attribution_residual_cm": max(uptake_errors),
        "cumulative_conductive_residual_j_cm2": math.fsum(float(r["residual_j_cm2"]) for r in heat),
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


def verified_run(run, metadata, first, last):
    result = json.loads((run / "RESULT.json").read_text())
    assert result["model"] == "NATIVE_GRASSGROWTH_WATER"
    assert (result["first_completed_day"], result["last_completed_day"]) == (first, last)
    assert metadata["executable_sha256"] == result["executable_sha256"]
    assert metadata["original_inputs_sha256"] == result["input_sha256"]
    assert all(sha(run / name) == pin for name, pin in result["input_sha256"].items())
    assert sha(run / "application.binding") == metadata["application_binding_sha256"]
    assert sha(run / "checkpoint.bin") == result["checkpoint_sha256"]
    return audit(run, first, last)


def historical_comparison(full, sealed):
    manifest = json.loads(sealed.with_name("GRASS_UNION_FULL_MANIFEST.json").read_text())
    assert sha(sealed) == manifest["evidence_sha256"]
    member = "dq15-original-nodal-reference/original/result_output.csv"
    with tarfile.open(sealed) as archive:
        legacy = archive.extractfile(member).read().decode("ascii")
    b0 = {r["DATE"]: r for r in csv.DictReader(line for line in io.StringIO(legacy) if not line.startswith("*"))}
    native = read_csv(full / "budget.csv")
    dates = [(date(1980, 1, 1)+timedelta(days=i)).isoformat() for i in range(len(native))]
    fields = {"potential_cm": "TPOT", "uptake_cm": "TACT", "drought_cm": "TREDDRY", "oxygen_cm": "TREDWET"}
    maximum = {}
    day188 = {}
    for key, label in fields.items():
        differences = [float(r[key])-float(b0[stamp][label]) for r, stamp in zip(native, dates)]
        i = max(range(len(differences)), key=lambda idx: abs(differences[idx]))
        maximum[key] = {"day": i+1, "native_minus_B0_cm": differences[i]}
        day188[key] = {"native_cm": float(native[187][key]), "B0_cm": float(b0[dates[187]][label])}
    return {"sealed_archive_sha256": manifest["evidence_sha256"], "day188": day188, "largest_absolute_daily_differences": maximum}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--wet", action="store_true")
    parser.add_argument("--late", action="store_true")
    parser.add_argument("--sealed", type=Path)
    parser.add_argument("--archived", action="store_true",
                        help="Read raw archived results with the archived build manifest")
    a = parser.parse_args()
    assert a.full or not (a.late or a.sealed)
    receipt = {"review_source": REVIEW_SOURCE}
    for opt in ("O0", "O2"):
        build = a.workspace / f"s5-grass-review-build-{opt}"
        control = build.with_name(build.name + "-control3")
        resume = build.with_name(build.name + "-resume3")
        metadata = json.loads((build / "BUILD.json").read_text())
        if not a.archived:
            assert sha(build / metadata["executable"]) == metadata["executable_sha256"]
            assert all(sha(Path(p)) == h for p, h in metadata["source_sha256"].items())
        restart(control, resume, 2, 3)
        receipt[opt] = {
            "compiler": metadata["compiler"],
            "executable_sha256": metadata["executable_sha256"],
            "input_sha256": metadata["original_inputs_sha256"],
            "build_receipt_sha256": sha(build / "BUILD.json"),
            "control": verified_run(control, metadata, 1, 3),
            "restart": verified_run(resume, metadata, 2, 3),
        }
        if opt == "O2" and (a.wet or a.full):
            full = build.with_name(build.name + "-full")
            cut = build.with_name(build.name + "-cut188")
            end = build.with_name(build.name + "-resume190")
            for name in LEDGERS:
                continuous = read_csv(full / name, 190)
                assert [int(row["day"]) for row in continuous] == list(range(1, 191))
                assert read_csv(cut / name) == continuous[:188], name
                assert read_csv(end / name) == continuous[188:], name
            receipt[opt]["wet_event_cut"] = verified_run(cut, metadata, 1, 188)
            receipt[opt]["wet_event_restart"] = verified_run(end, metadata, 189, 190)
            receipt[opt]["wet_event_ledgers_match_continuous"] = True
            if a.full:
                receipt[opt]["full"] = verified_run(full, metadata, 1, 1827)
                if a.sealed:
                    receipt[opt]["historical_comparison"] = historical_comparison(full, a.sealed)
                if a.late:
                    origin = build.with_name(build.name + "-late-origin")
                    late = build.with_name(build.name + "-late-resume")
                    pin = json.loads((origin / "ORIGIN.json").read_text())
                    assert sha(origin / "checkpoint.bin") == pin["checkpoint_sha256"]
                    restart(full, late, pin["day"]+1, 1827)
                    receipt[opt]["late_terminal_restart"] = {
                        "origin": pin,
                        "exact_terminal": True,
                        "run": verified_run(late, metadata, pin["day"]+1, 1827),
                    }
    for name in (*LEDGERS, "state.csv", "endpoint.csv"):
        assert receipt["O0"]["control"]["output_sha256"][name] == receipt["O2"]["control"]["output_sha256"][name]
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
