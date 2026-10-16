"""Focused actual managed weather and unchanged weather owners, one controlled O0/O2 build."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tests/mc-met01/run_raintb_legacy_owner_preservation.py';s=path.read_text()
def replace(a,b):
 global s
 assert s.count(a)==1,(s.count(a),a)
 s=s.replace(a,b)
replace("for name,include,call in [('daily_demand','test_daily_demand_production.inc','test_daily_demand_production'),\n                              ('raintb','test_raintb_production.inc','test_raintb_production')]:", "for name,include,call in [('managed','test_managed_weather_application.inc','test_managed_weather_application')]:")
replace("path=ROOT/'tests/mc-met01'/include", "path=ROOT/'tests/mc-irr01'/include")
replace("        source=base;first=source.index", "        source=base.replace('  implicit none\\n','  use mod_fmr_irrigation_allocation_binding\\n  use, intrinsic :: ieee_arithmetic\\n  implicit none\\n',1);first=source.index")
replace("'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'", "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'")
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})", "    inputs['tests/mc-irr01/run_managed_weather_application.py']=sha(ROOT/'tests/mc-irr01/run_managed_weather_application.py')\n    inputs.update({p:sha(ROOT/p) for p in PINS})")
exec(compile(s,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
