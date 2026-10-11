#!/usr/bin/env python3
"""Compare exact PR700 source with the accepted daily Gash policy, not E2E physics."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OLD = "5fcd9769c30379f461ce047f410638b0d3311f96"
CURRENT = "e35ea0c6801ad0c225ff02e60f24996d2bc0156d"
OLD_PATHS = ["src/process/mod_vonhhbraden_interception.f90", "src/process/mod_gash_interception.f90"]
CURRENT_PATHS = ["src/process/mod_gash_interception_process.f90", "src/process/mod_gash_daily_application.f90"]
FLAGS = ["-std=f2008", "-pedantic-errors", "-ffree-line-length-none", "-Wall", "-Wextra", "-Werror", "-fcheck=all", "-ffpe-trap=invalid,zero,overflow"]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    report = json.loads((ROOT / "integration/audits/PPA_RECONCILE01_CURRENT_LINEAGE_20261011.json").read_text())
    rows = {r["path"]: r for r in report["rows"]}
    current = git("rev-parse", CURRENT).decode().strip()
    receipt = json.loads((ROOT / "integration/audits/F-MIG431-INT12-D_CLOSEOUT.json").read_text())
    assert receipt["status"] == "CANONICAL_ADMITTED_CLOSED"
    assert any("grai rather than rpd" in s for s in receipt["negative_findings"])
    dependencies = {}
    with tempfile.TemporaryDirectory(prefix="pr700-gash-disposition-") as directory:
        build = Path(directory)
        sources = []
        for path in OLD_PATHS:
            raw = git("show", OLD + ":" + path)
            blob = git("rev-parse", OLD + ":" + path).decode().strip()
            assert blob == rows[path]["historical_blob"]
            assert hashlib.sha256(raw).hexdigest() == rows[path]["historical_sha256"]
            target = build / Path(path).name
            target.write_bytes(raw)
            sources.append(str(target))
            dependencies["historical:" + path] = blob
        for path in CURRENT_PATHS:
            blob = git("rev-parse", current + ":" + path).decode().strip()
            assert git("show", current + ":" + path) == (ROOT / path).read_bytes()
            dependencies["current:" + path] = blob
            sources.append(str(ROOT / path))
        test = ROOT / "tests/fpm/test_pr700_gash_source_disposition.f90"
        outputs = []
        for optimization in (0, 2):
            work = build / ("o" + str(optimization))
            work.mkdir()
            executable = work / "diagnostic"
            subprocess.run(["gfortran", *FLAGS, "-O" + str(optimization), "-J" + str(work), "-I" + str(work), *sources, str(test), "-o", str(executable)], check=True, cwd=work)
            outputs.append(subprocess.check_output([str(executable)], cwd=work))
        assert outputs[0] == outputs[1], "O0/O2 diagnostic output differs"
        print(outputs[0].decode(), end="")
        print("PR700_GASH_SOURCE_DISPOSITION_O0_O2_IDENTITY=PASS")
        print(json.dumps({"historical_head": OLD, "canonical_base": current, "source_blobs": dependencies, "stdout_sha256": hashlib.sha256(outputs[0]).hexdigest()}, sort_keys=True))


if __name__ == "__main__":
    main()
