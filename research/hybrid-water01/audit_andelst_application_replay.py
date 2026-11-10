"""Verify an Andelst full application run and its chained durable restarts."""
import argparse
from hashlib import sha256
import json
import math
from pathlib import Path
from zipfile import ZipFile

TOLERANCE_CM = 1e-6
SCHEMA = "swap5-hybrid-water-checkpoint-3"


def digest(data):
    return sha256(data).hexdigest()


def read(path):
    return json.loads(path.read_text())


def run(path, first, last):
    result = read(path / "RESULT.json")
    assert result["committed_days"] == last-first+1 and result["first_refusal"] is None
    lines = (path / "daily.jsonl").read_bytes()
    rows = [json.loads(line) for line in lines.splitlines()]
    assert [row["day"] for row in rows] == list(range(first, last+1))
    for row in rows:
        assert row["column"] == 1 and row["committed"]
        for key in ("independent_residual_cm", "kernel_residual_cm"):
            assert abs(row[key]) <= TOLERANCE_CM, (row["day"], key)
    for previous, current in zip(rows, rows[1:]):
        assert previous["stock_end_cm"] == current["stock_start_cm"], current["day"]
    return result, {row["day"]: row for row in rows}, digest(lines)


def package(path, expected):
    data = path.read_bytes()
    with ZipFile(path) as z:
        assert sorted(z.namelist()) == ["checkpoint.json", "macro.bin", "result.end"]
        m = json.loads(z.read("checkpoint.json"))
        assert m["schema"] == SCHEMA and m["receipt"] == expected
        assert m["files"] == {name: digest(z.read(name)) for name in ("macro.bin", "result.end")}
    return m["binding"], {"sha256": digest(data), "payloads": m["files"]}


def physical(row):
    return {k: v for k, v in row.items() if k != "revision"}


def csv_records(path):
    rows = path.read_bytes().splitlines()
    return [r for r in rows if r[:4].isdigit() and r[4:5] == b"-"]


def control_rows(path):
    return [json.loads(line) for line in (path / "daily.jsonl").read_bytes().splitlines()]


def isolation(path):
    alternate = control_rows(path / "alternating")
    a, b = (control_rows(path / label) for label in ("control_a", "control_b"))
    assert len(a) == len(b) > 0
    assert [row["column"] for row in alternate] == [1, 2]*len(a)
    for column, separate in ((1, a), (2, b)):
        actual = [dict(row, column=1) for row in alternate if row["column"] == column]
        assert actual == separate
    assert any(x["pressure_head_cm"] != y["pressure_head_cm"] for x, y in zip(a, b))
    return {"days_per_column": len(a), "exact": True}


def refusal(path):
    case = read(path / "RESULT.json")
    refused, other = case["refused"], case["other_column_after"]
    assert (refused["day"], refused["revision"], refused["committed"]) == (15, 14, False)
    assert not list(path.rglob("accepted-column-1-day-15.zip"))
    assert (other["column"], other["day"], other["committed"]) == (2, 2, True)
    return {"day": 15, "revision": 14, "checkpoint_published": False, "other_column_accepted_day": 2}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("full", type=Path)
    parser.add_argument("year", type=Path)
    parser.add_argument("dry", type=Path)
    parser.add_argument("--isolation", type=Path)
    parser.add_argument("--refusal", type=Path)
    args = parser.parse_args()
    report, baseline, ledger_sha = run(args.full, 1, 481)
    year_report, year, year_sha = run(args.year, 366, 457)
    dry_report, dry, dry_sha = run(args.dry, 454, 459)
    p365, e365 = package(args.full / "accepted-column-1-day-365.zip", baseline[365])
    p453, e453 = package(args.year / "accepted-column-1-day-453.zip", year[453])
    assert p365 == p453
    continuous = csv_records(args.full / "original/result_output.csv")
    assert len(continuous) == 482  # Initial-state row and one row per day.
    assert report["input_sha256"] == p365["inputs"]
    for path, other, segment in ((args.year, year_report, year), (args.dry, dry_report, dry)):
        assert other["input_sha256"] == report["input_sha256"] == p365["inputs"]
        assert other["source_sha256"] == report["source_sha256"] == {
            "SWAP.ZIP": p365["swap_source"], "TTUTIL.ZIP": p365["ttutil_source"],
        }
        assert all(physical(row) == physical(baseline[day]) for day, row in segment.items())
        assert csv_records(path / "original/result_output.csv")[1:] == [continuous[day] for day in segment], path
    controls = {}
    if args.isolation:
        controls["isolation"] = isolation(args.isolation)
    if args.refusal:
        controls["refusal"] = refusal(args.refusal)
    print(json.dumps({
        "day_range": [1, 481],
        "result": report,
        "ledger_sha256": ledger_sha,
        "signed_water_residual_cm": math.fsum(r["independent_residual_cm"] for r in baseline.values()),
        "maximum_daily_residual_cm": max(abs(r["independent_residual_cm"]) for r in baseline.values()),
        "restarts": [{"origin": 365, "end": 457, "checkpoint": e365, "ledger_sha256": year_sha},
                     {"origin": 453, "end": 459, "checkpoint": e453, "ledger_sha256": dry_sha}],
        "build_identity": p365["build"],
        "controls": controls,
    }, indent=2))


if __name__ == "__main__":
    main()
