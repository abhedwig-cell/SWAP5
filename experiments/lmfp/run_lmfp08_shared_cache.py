from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp08_physics_informed_correction as core

# Qualification-process analogue of the intended runtime architecture: immutable
# hydraulic correction tables are generated once per compatible material/geometry
# class and then referenced by all probes/columns. This changes only preparation
# cost, never numerical table contents or transient face results.
_SHARED_TABLES = {}


def shared_table(self, code, length):
    key = (int(code), round(float(length), 12))
    if key not in _SHARED_TABLES:
        _SHARED_TABLES[key] = core.FactoredCorrectionTable(code, length)
    if key not in self.tables:
        self.tables[key] = _SHARED_TABLES[key]
        self.build_count += 1
    return self.tables[key]


core.CorrectionCache.table = shared_table

if __name__ == "__main__":
    core.main()
