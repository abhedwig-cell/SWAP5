from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core

# Hierarchical qualification only: evaluate the two smallest nested runtime
# densities first. All physical equations, head/gradient envelopes, materials,
# geometry classes, probes and acceptance thresholds remain those of B1.
# If neither 17 nor 33 passes, the already-defined 65-node master remains the
# next density and no threshold is relaxed.
core.MASTER_NX = 33
core.VIEW_NX = (17, 33)

if __name__ == "__main__":
    core.main()
