from __future__ import annotations
import argparse
import json
from pathlib import Path

SOIL_CLASSES = ("sand", "loam", "clay", "peat")
FORCING_CLASSES = ("dry", "normal", "wet", "variable")
GW_CLASSES = ("shallow", "intermediate", "deep", "dynamic")

def build(workload_id: str, swap_columns: int, cells: int) -> dict:
    if swap_columns <= 0 or cells <= 0:
        raise ValueError("positive sizes required")
    if swap_columns % cells != 0:
        raise ValueError("swap_columns must be divisible by interface cells")
    tpc = swap_columns // cells
    participants = []
    pid = 1
    for cell in range(1, cells + 1):
        for local in range(1, tpc + 1):
            participants.append({
                "participant_id": pid,
                "groundwater_cell_id": cell,
                "weight": 1.0 / tpc,
                "soil_class": SOIL_CLASSES[(pid - 1) % len(SOIL_CLASSES)],
                "forcing_class": FORCING_CLASSES[((pid - 1) // len(SOIL_CLASSES)) % len(FORCING_CLASSES)],
                "groundwater_class": GW_CLASSES[(cell - 1) % len(GW_CLASSES)],
                "representative_group_seed": ((cell - 1) % 10) + 1,
            })
            pid += 1
    return {
        "schema": "swap5-appqual01-b1-topology-v1",
        "workload_id": workload_id,
        "swap_columns": swap_columns,
        "modflow_interface_cells": cells,
        "tiles_per_cell": tpc,
        "participant_weight_rule": "equal-within-cell",
        "participants": participants,
    }

def validate(doc: dict) -> None:
    n = doc["swap_columns"]
    cells = doc["modflow_interface_cells"]
    participants = doc["participants"]
    assert len(participants) == n
    assert [p["participant_id"] for p in participants] == list(range(1, n + 1))
    by_cell = {}
    for p in participants:
        by_cell.setdefault(p["groundwater_cell_id"], []).append(p)
    assert len(by_cell) == cells
    for cell, ps in by_cell.items():
        assert len(ps) == doc["tiles_per_cell"]
        assert abs(sum(p["weight"] for p in ps) - 1.0) <= 1e-14
    assert set(p["soil_class"] for p in participants) == set(SOIL_CLASSES)
    assert set(p["forcing_class"] for p in participants) == set(FORCING_CLASSES)
    assert set(p["groundwater_class"] for p in participants) == set(GW_CLASSES)

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workload", required=True, choices=["B1-S100", "B1-S1000", "B1-S10000"])
    ap.add_argument("--output", required=True)
    ns = ap.parse_args()
    sizes = {"B1-S100": 100, "B1-S1000": 1000, "B1-S10000": 10000}
    doc = build(ns.workload, sizes[ns.workload], 100)
    validate(doc)
    Path(ns.output).write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"APPQUAL01_B1_TOPOLOGY={ns.workload} PASS participants={len(doc['participants'])}")

if __name__ == "__main__":
    main()
