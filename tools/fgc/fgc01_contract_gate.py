#!/usr/bin/env python3
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract_dir = root / "integration" / "f-gc"
required = [
    "F-GC01_DEPENDENCIES.json", "F-GC01_INTERFACE_CONTRACT.json",
    "F-GC01_COUPLING_WINDOW_CONTRACT.json", "F-GC01_MASS_CONTRACT.json",
    "F-GC01_TILE_AGGREGATION_CONTRACT.json", "F-GC01_DEEP_VADOSE_CONTRACT.json",
    "F-GC01_STATUS.json", "F-GC01_QUALIFICATION_EVIDENCE.json",
]
documents = {name: json.loads((contract_dir / name).read_text()) for name in required}
assert documents["F-GC01_DEPENDENCIES.json"]["start_commit"] == "c28e7a2810b4a3678c577335a6a3086b173eb976"
assert documents["F-GC01_INTERFACE_CONTRACT.json"]["equilibrium"]["flux"] == "q_SWAP = -q_GW"
assert documents["F-GC01_MASS_CONTRACT.json"]["requirements"]["mass_loss_tolerance"] == "NONE"
assert documents["F-GC01_TILE_AGGREGATION_CONTRACT.json"]["swap_knows_cell_fraction"] is False
assert documents["F-GC01_DEEP_VADOSE_CONTRACT.json"]["implemented_in_fgc01"] is False
assert documents["F-GC01_QUALIFICATION_EVIDENCE.json"]["decision"] == "QUALIFIED_GROUNDWATER_COUPLING_CONTRACT_AND_DETERMINISTIC_HARNESS"
assert documents["F-GC01_STATUS.json"]["QUALIFIED"] is True
print("F-GC01_CONTRACT_GATE PASS")
