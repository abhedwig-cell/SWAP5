"""Check persisted native C2E result ledgers and fresh-process replay identity."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def validate(path: Path, replay: Path) -> None:
    raw = path.read_bytes()
    if raw != replay.read_bytes():
        raise AssertionError(f"fresh-process replay differs: {path} vs {replay}")
    result = json.loads(raw)
    rows = result["rows"]
    if result["state"] != "NATIVE_DUMMY_RUN_COMPLETED":
        raise AssertionError(f"run did not complete: {path}")
    expected = {"zero": 4, "pulse": 120, "c2b-match": 2}[result["mode"]]
    if len(rows) != expected or result["windows_published"] != expected:
        raise AssertionError(f"wrong published-window count in {path}")
    if not all(row["published"] and row["modflow_converged"] for row in rows):
        raise AssertionError(f"unpublished or unconverged window in {path}")
    for i, row in enumerate(rows, 1):
        if (row["revisions_min"], row["revisions_max"], row["ledgers_min"], row["ledgers_max"]) != (i, i, i, i):
            raise AssertionError(f"participant revision/ledger mismatch at window {i} in {path}")
        if abs(row["mass_residual_m3"]) > 1.0e-9:
            raise AssertionError(f"window mass residual exceeds 1e-9 m3 at {i} in {path}")
        if row["max_abs_action_reaction_rate_error_m3_per_day"] > 1.0e-9:
            raise AssertionError(f"action/reaction mismatch at window {i} in {path}")
    if result["maximum_absolute_window_residual_m3"] > 1.0e-9 or abs(result["cumulative_mass_residual_m3"]) > 1.0e-9:
        raise AssertionError(f"cumulative mass gate failed in {path}")
    if result["maximum_native_storage_vs_head_change_error_m3"] > 1.0e-9:
        raise AssertionError(f"native MODFLOW storage gate failed in {path}")
    if result["mode"] == "zero":
        if any(row["input_m3"] or row["interface_transfer_m3"] or row["drain_outflow_m3"] for row in rows):
            raise AssertionError(f"nonzero forcing/exchange/drain in zero control: {path}")
        if any(abs(h + 1.0) > 1.0e-12 for row in rows for h in row["head_m"] + row["dummy_internal_head_m"]):
            raise AssertionError(f"state drift in zero control: {path}")
        return
    if result["mode"] == "c2b-match":
        if [row["recharge_m_per_day"] for row in rows] != [0.0, 0.001]:
            raise AssertionError(f"unexpected C2B-matched forcing schedule in {path}")
        expected_input = 5.0e-5
    else:
        if any(row["recharge_m_per_day"] != (0.001 if i < 80 else 0.0) for i, row in enumerate(rows)):
            raise AssertionError(f"unexpected pulse/recession forcing schedule in {path}")
        expected_input = 1.0
    if abs(sum(row["input_m3"] for row in rows) - expected_input) > 1.0e-12:
        raise AssertionError(f"unexpected total recharge in {path}")
    if sum(row["interface_transfer_m3"] for row in rows) <= 0.0:
        raise AssertionError(f"no dummy-to-MODFLOW transfer in {path}")
    if sum(row["drain_outflow_m3"] for row in rows) <= 0.0:
        raise AssertionError(f"no left-drain response in {path}")
    if result["mode"] == "pulse":
        if rows[-1]["head_m"][-1] - rows[-1]["head_m"][0] < 0.01:
            raise AssertionError(f"no spatial mound toward no-flow boundary in {path}")
        if max(abs(q) for row in rows for q in row["lateral_face_flow_m3_per_day"]) < 1.0e-4:
            raise AssertionError(f"lateral groundwater response is too small in {path}")
    elif rows[-1]["head_m"][-1] <= rows[-1]["head_m"][0] or not any(
        q != 0.0 for row in rows for q in row["lateral_face_flow_m3_per_day"]
    ):
        raise AssertionError(f"C2B-matched response produced no spatial/lateral change in {path}")
    max_head_gap = max(abs(a - b) for row in rows for a, b in zip(row["dummy_internal_head_m"], row["head_m"]))
    conductance = result["ownership"]["conductance_m2_per_day"]
    if conductance >= 1.0e5 and max_head_gap > 1.0e-6:
        raise AssertionError(f"near-zero resistance limit failed in {path}: head gap {max_head_gap}")
    finite_gap_floor = 1.0e-4 if result["mode"] == "pulse" else 1.0e-8
    if conductance < 1.0e5 and max_head_gap < finite_gap_floor:
        raise AssertionError(f"finite resistance did not separate internal/interface heads in {path}")
    if max(row["resistance_law_max_abs_error_m3_per_day"] for row in rows) > 1.0e-9:
        raise AssertionError(f"resistance law failed in {path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", action="append", nargs=2, metavar=("RESULT_JSON", "REPLAY_JSON"), required=True)
    args = parser.parse_args()
    for result, replay in args.case:
        validate(Path(result), Path(replay))
    print(f"C2E_NATIVE_RESULT_VALIDATION_PASS cases={len(args.case)} fresh_process_byte_identity=true")


if __name__ == "__main__":
    main()
