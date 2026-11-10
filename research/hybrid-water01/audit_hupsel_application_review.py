"""Verify the original-input Hupsel application and own-build restarts."""
import argparse
import csv
from hashlib import sha256
import json
import math
from pathlib import Path
import struct
import tarfile

PHYSICAL = ("budget.csv", "crop.csv", "endpoint.csv", "germination.csv", "state.csv", "temperature.csv")
ENDPOINT = ("checkpoint.bin", "restart.bin", "endpoint.csv", "state.csv", "temperature.csv")
SOURCE = "a8275101d91f0ab5b413290e9b00bb5666b11917"


def digest(data):
    return sha256(data).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def read(path):
    return json.loads(path.read_text())


def rows(path):
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def inspect(run, start, end, original=None):
    receipt = read(run / "RESULT.json")
    assert receipt["last_completed_day"] == end and (receipt["origin_day"] or 0) == start
    assert all(sha(run / n) == pin for n, pin in receipt["input_sha256"].items())
    if original:
        assert receipt["input_sha256"] == original["input_sha256"]
        assert receipt["executable_sha256"] == original["executable_sha256"]
    checkpoint = (run / "checkpoint.bin").read_bytes()
    assert checkpoint[:8] == b"S5HR0004" and struct.unpack_from("=d", checkpoint, 8)[0] == end
    assert receipt["checkpoint_sha256"] == digest(checkpoint)
    assert checkpoint == (run / "restart.bin").read_bytes()

    budget = [{k: float(v) for k, v in row.items()} for row in rows(run / "budget.csv")]
    assert budget[0]["t0_day"] == start and budget[-1]["t1_day"] == end
    assert all(r["t0_day"] < r["t1_day"] and all(math.isfinite(x) for x in r.values()) for r in budget)
    assert all(a["t1_day"] == b["t0_day"] for a, b in zip(budget, budget[1:]))
    assert sorted({math.ceil(r["t1_day"]-1e-9) for r in budget}) == list(range(start+1, end+1))
    balance = {}
    for field, unit in (("water", "cm"), ("solute", "mg_cm2")):
        opening, closing, incoming, outgoing, residual = (f"{field}_{k}_{unit}" for k in
                                                           ("start", "end", "in", "out", "residual"))
        maximum = max(abs(r[closing]-r[opening]-r[incoming]+r[outgoing]) for r in budget)
        reported = max(abs(r[residual]) for r in budget)
        cumulative = budget[-1][closing]-budget[0][opening]-math.fsum(r[incoming] for r in budget)+math.fsum(r[outgoing] for r in budget)
        assert maximum <= 1e-10 and reported <= 1e-10
        assert all(abs(a[closing]-b[opening]) <= 1e-10 for a, b in zip(budget, budget[1:]))
        assert abs(cumulative) <= 1e-8
        balance[field] = {"max_independent_interval": maximum, "max_reported_interval": reported, "cumulative": cumulative}
    balance["max_reported_heat_j_cm2"] = max(abs(r["observed_heat_residual_j_cm2"]) for r in budget)
    return receipt, budget, {"balance": balance, "outputs_sha256": {n: sha(run / n) for n in (*PHYSICAL, "checkpoint.bin", "restart.bin")}}


def suffix(control, resume, first, last):
    original = rows(control / "budget.csv")
    actual = rows(resume / "budget.csv")
    expected = [r for r in original if float(r["t0_day"]) >= first and float(r["t1_day"]) <= last]
    # Window labels are local to the execution. Match all physical and clock fields.
    physical = lambda r: {k: v for k, v in r.items() if k != "window"}
    assert list(map(physical, actual)) == list(map(physical, expected))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("sealed", type=Path)
    parser.add_argument("--year", action="store_true")
    parser.add_argument("--o0", action="store_true")
    a = parser.parse_args()
    full = a.workspace / "full"
    report, budget, output = inspect(full, 0, 1096)
    manifest = read(a.sealed.with_suffix("").with_suffix(".json"))
    assert sha(a.sealed) == manifest["archive_sha256"]
    with tarfile.open(a.sealed) as archive:
        for name in PHYSICAL:
            path = f"O2/full1096/{name}"
            content = archive.extractfile(path).read()
            assert digest(content) == manifest["files_sha256"][path]
            assert content == (full / name).read_bytes(), name
        checkpoint_path = "O2/full1096/checkpoint.bin"
        sealed_checkpoint = digest(archive.extractfile(checkpoint_path).read())
        assert sealed_checkpoint == manifest["files_sha256"][checkpoint_path]
    output["sealed_checkpoint_sha256"] = sealed_checkpoint
    output["sealed_physical_csv_exact"] = list(PHYSICAL)
    output["run"] = report
    output["source_commit"] = SOURCE
    output["sealed_archive_sha256"] = manifest["archive_sha256"]
    output["day584_oxygen_cm"] = math.fsum(r["oxygen_reduction_cm"] for r in budget if math.ceil(r["t1_day"]-1e-9) == 584)

    def short(prefix, expected=None):
        control, cut, resume = (a.workspace / (prefix + n) for n in ("control4", "control2", "resume4"))
        proof, _, _ = inspect(control, 0, 4, expected)
        _, _, cut_out = inspect(cut, 0, 2, proof)
        _, _, resumed_out = inspect(resume, 2, 4, proof)
        suffix(full, control, 0, 4)
        suffix(control, resume, 2, 4)
        for n in ENDPOINT:
            assert (control / n).read_bytes() == (resume / n).read_bytes(), n
        return {"executable_sha256": proof["executable_sha256"], "cut": cut_out, "resume": resumed_out}

    output["O2_restart_2_to_4"] = short("", report)
    if a.o0:
        output["O0_restart_2_to_4"] = short("O0-")
    if a.year:
        cut, resume = (a.workspace / name for name in ("cut365", "resume367"))
        _, _, cut_out = inspect(cut, 0, 365, report)
        _, _, resumed_out = inspect(resume, 365, 367, report)
        suffix(full, cut, 0, 365)
        suffix(full, resume, 365, 367)
        output["O2_restart_365_to_367"] = {"cut": cut_out, "resume": resumed_out}
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
