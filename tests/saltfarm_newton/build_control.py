"""Select the preserved always-polish policy explicitly for a fresh control."""
from pathlib import Path
from dataclasses import replace
import runpy,sys
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'app/hybrid_water'))
import daily_host as h
previous=h.SALTFARM;h.SALTFARM=replace(previous,water_polish_policy=h.ALWAYS_WATER_POLISH)
h.PROJECTS=tuple(h.SALTFARM if p==previous else p for p in h.PROJECTS)
runpy.run_path(str(root/'tools/solute/run_water.py'),run_name='__main__')
