from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_coordinate_envelope as core

# Follow-up to the failed A1 gate. Only density is changed. The head envelope,
# synthetic material stress set, reference integration and all acceptance
# thresholds remain exactly those defined in run_lmfp09_coordinate_envelope.py.
core.CANDIDATES = [
    (0.01, 128), (0.01, 160), (0.01, 192),
    (0.10, 128), (0.10, 160), (0.10, 192),
]

if __name__ == "__main__":
    core.main()
