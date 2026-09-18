#!/usr/bin/env python3
"""Fail-closed preregistration and source-lock validation for F-ROM01."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def git_blob(rev: str, path: str) -> str:
    return subprocess.check_output(["git", "rev-parse", f"{rev}:{path}"], text=True).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--contract", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--candidate-head", required=True)
    ap.add_argument("--test-source", required=True)
    args = ap.parse_args()

    c = json.loads(Path(args.contract).read_text(encoding="utf-8"))
    if c["phase"] != "PREREGISTERED_BEFORE_REFERENCE_HISTORY_EXECUTION":
        raise SystemExit("contract phase drift")
    if c["canonical_baseline"] != args.baseline:
        raise SystemExit("baseline drift")
    if c["production_mutation_allowed"] is not False:
        raise SystemExit("production mutation firewall relaxed")
    if c["threshold_retuning_after_execution_allowed"] is not False:
        raise SystemExit("threshold-retuning firewall relaxed")
    if c["research_fixture"]["material_id"] != "B01":
        raise SystemExit("pilot material drift")
    if c["geometry"]["active_nodes"] != 16 or c["geometry"]["root_zone_nodes"] != 4:
        raise SystemExit("pilot geometry drift")
    if c["histories"]["phase_steps"] != 48:
        raise SystemExit("history length drift")
    if c["continuation"]["steps"] != 24 or c["continuation"]["observation_steps"] != [1, 8, 24]:
        raise SystemExit("continuation design drift")

    for path, expected in c["source_locks"].items():
        base_blob = git_blob(args.baseline, path)
        candidate_blob = git_blob(args.candidate_head, path)
        if base_blob != expected or candidate_blob != expected:
            raise SystemExit(
                f"source lock drift for {path}: "
                f"base={base_blob} candidate={candidate_blob} expected={expected}"
            )

    src = Path(args.test_source).read_text(encoding="utf-8")
    fixture = c["research_fixture"]
    required = [
        f"theta_r = {fixture['theta_r']}_real64",
        f"theta_s = {fixture['theta_s']}_real64",
        f"alpha_per_cm = {fixture['alpha_per_cm']}_real64",
        f"vg_n = {fixture['n']}_real64",
        f"ksatfit_cm_per_day = {fixture['ksatfit_cm_per_day']}_real64",
        f"lambda_mvg = {fixture['lambda']}_real64",
        "phase_steps = 48",
        "continuation_steps = 24",
        "dt_day = 0.0016_real64",
        "collision_storage_tol_cm = 1.0e-8_real64",
    ]
    missing = [token for token in required if token not in src]
    if missing:
        raise SystemExit(f"test/contract drift: {missing}")

    print("F_ROM01_PREREGISTRATION_LOCK=PASS")
    print("F_ROM01_SOURCE_LOCKS=PASS")
    print(f"F_ROM01_LOCKED_CANDIDATE_HEAD={args.candidate_head}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
