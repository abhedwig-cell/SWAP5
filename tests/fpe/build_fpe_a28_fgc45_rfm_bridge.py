"""Copy the explicit qualification bridge. Policy is selected at runtime."""
from pathlib import Path
import sys
if len(sys.argv)!=3 or sys.argv[2] not in {'exact','a28'}:
    raise SystemExit('usage: build_fpe_a28_fgc45_rfm_bridge.py OUTPUT exact|a28')
Path(sys.argv[1]).write_text(Path('tests/fpe/support/mod_fpe_a28_fgc45_rfm_bridge.f90').read_text())
