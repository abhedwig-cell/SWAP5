from __future__ import annotations
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[2]
path = root / "tests/performance/generate_appqual01_b1.py"
spec = importlib.util.spec_from_file_location("appqual01_b1", path)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

for wid, n in [("B1-S100",100),("B1-S1000",1000),("B1-S10000",10000)]:
    doc = mod.build(wid,n,100)
    mod.validate(doc)
    assert doc["swap_columns"] == n
    assert doc["modflow_interface_cells"] == 100
    assert doc["tiles_per_cell"] == n // 100

print("APPQUAL01_B1_GENERATOR=PASS")
