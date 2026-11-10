"""Compare the original Grassgrowth prefix and two heat-only time integrations."""
import argparse
import csv
from datetime import date, timedelta
from hashlib import sha256
from io import TextIOWrapper
import json
from math import floor
from pathlib import Path
import struct
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/dataqual15"))
from checkpoint_layout import layout


def temperatures(raw):
    state = layout(raw)
    n = state["nodes"]
    return struct.unpack_from(f"<{n}d", raw, state["physical"] + 16*n + 16)


def difference(profile, reference):
    delta = [a-b for a, b in zip(profile, reference, strict=True)]
    i = max(range(len(delta)), key=lambda j: abs(delta[j]))
    return {"max_abs_c": abs(delta[i]), "node": i+1, "signed_node27_c": delta[26]}


def digest(path):
    h = sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()


def replay(exe, mode, payload, count):
    payload.seek(0)
    completed = subprocess.run([exe, *([mode] if mode else [])], stdin=payload,
                               capture_output=True, text=True, check=True, timeout=60)
    rows = [list(map(float, line.split()[1:])) for line in completed.stdout.splitlines()]
    assert len(rows) == count and all(len(row) == 9 for row in rows)
    end = rows[-1]
    return {"max_temperature_difference_any_step_c": max(row[4] for row in rows),
            "day63_max_temperature_difference_c": end[4], "day63_node_of_max": int(end[0]),
            "day63_signed_node27_c": end[8],
            "max_abs_conductive_residual_j_cm2": max(abs(row[7]) for row in rows),
            "max_capacity_difference_j_cm3_k": max(row[5] for row in rows),
            "max_conductivity_difference_j_cm_k_day": max(row[6] for row in rows)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("legacy", "native", "replay-o0", "replay-o2"):
        parser.add_argument("--"+name, required=True, type=Path)
    args = parser.parse_args()
    archive = ROOT / "integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz"
    with tarfile.open(archive) as source:
        path = "dq15-original-nodal-reference/original/nodal_profiles.csv"
        b0 = [float(row["temperature_c"]) for row in csv.DictReader(TextIOWrapper(source.extractfile(path)))
              if int(row["day"]) == 63]
        retained = temperatures(source.extractfile("dq15-union-oxygen-full-O2/checkpoint-63.bin").read())
    native = temperatures((args.native / "checkpoint-63.bin").read_bytes())
    with (args.native / "budget.csv").open() as stream:
        native63, = [row for row in csv.DictReader(stream) if int(row["day"]) == 63]
    with (args.legacy / "260.met").open() as stream:
        weather = {(int(r["YYYY"]), int(r["MM"]), int(r["DD"])): 0.5*(float(r["Tmin"])+float(r["Tmax"]))
                   for r in csv.DictReader(line for line in stream if not line.startswith("*"))}
    steps, profiles = [], []
    with tempfile.TemporaryFile(mode="w+b") as payload, (args.legacy / "stdout").open("rb") as log:
        for line in log:
            tag, _, body = line.partition(b" ")
            if tag in (b"LEGACY_HEAT_CASE", b"LEGACY_HEAT_NODE"):
                payload.write(body)
            elif tag == b"LEGACY_HEAT_STEP":
                steps.append(list(map(float, body.split())))
            elif tag == b"LEGACY_HEAT_PROFILE":
                profiles.append(list(map(float, body.split())))
        payload.flush()
        assert len(profiles) == 63 and len(b0) == 113
        origin = steps[0][0]
        dates = [date(1980, 1, 1)+timedelta(days=floor(row[0]-origin+1e-8)) for row in steps]
        forcing_error = max(abs(row[3]-weather[d.year,d.month,d.day]) for row, d in zip(steps,dates,strict=True))
        assert forcing_error < 1e-12 and all(row[4] == 0 for row in steps)
        assert difference(profiles[-1][1:], b0)["max_abs_c"] < 1e-12
        results = {}
        for opt, exe in (("O0", args.replay_o0), ("O2", args.replay_o2)):
            results[opt] = {mode or "same_step": replay(exe, mode, payload, len(steps))
                            for mode in ("", "full", "frozen", "split")}
        assert results["O0"] == results["O2"]
        assert results["O2"]["full"]["max_temperature_difference_any_step_c"] < 1e-12
    print(json.dumps({
        "archived_profile_sha256": digest(archive),
        "legacy": json.loads((args.legacy / "RESULT.json").read_text()),
        "legacy_accepted_steps": len(steps),
        "legacy_day63_accepted_steps": sum(d == date(1980,3,3) for d in dates),
        "legacy_max_boundary_error_vs_daily_met_mean_c": forcing_error,
        "legacy_day63_against_archived_b0": difference(profiles[-1][1:], b0),
        "older_retained_native_day63_against_b0": difference(retained, b0),
        "newer_retained_native_day63_against_b0": difference(native, b0),
        "newer_native_day63_adaptive_intervals": int(native63["accepted_steps"]),
        "newer_native_day63_checkpoint_sha256": digest(args.native / "checkpoint-63.bin"),
        "replay_executable_sha256": {"O0": digest(args.replay_o0), "O2": digest(args.replay_o2)},
        "replays": results,
    }, indent=2))


if __name__ == "__main__":
    main()
