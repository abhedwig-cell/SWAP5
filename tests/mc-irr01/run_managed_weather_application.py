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
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})", "    drivers['allocation_guards']=ROOT/'tests/f-app07/test_mc_irr01_allocation_guards.f90'\n    inputs['tests/f-app07/test_mc_irr01_allocation_guards.f90']=sha(ROOT/'tests/f-app07/test_mc_irr01_allocation_guards.f90')\n    inputs.update({p:sha(ROOT/p) for p in PINS})")
replace("'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'", "'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS','allocation_guards':b'MC_IRR01_ALLOCATION_GUARDS=PASS'")
replace("for mode in ['continuous','restart']:", "for mode in (['continuous']if name=='allocation_guards'else ['continuous','restart']):")
replace("if pair[0]!=pair[1]:", "if len(pair)>1 and pair[0]!=pair[1]:")
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})", """    drivers['managed_rooted']=rooted(ROOT,output/'managed_rooted.f90')
    oxygen_oracle(ROOT,fixture/'oxygen_oracle.f90');co2_oracle(ROOT,fixture/'co2_oracle.f90')
    for p in ['tests/mc-irr01/managed_root_cycle_driver.py','tests/root-growth/density_cycle_driver.py',
      'tests/root-growth/swrd2_cycle_driver.py','tests/root-growth/swrd3_cycle_driver.py',
      'tests/crop-cycle/oxygen_cycle_driver.py','tests/crop-cycle/oxygen_segment_oracle.inc',
      'tests/crop-cycle/oxygen_source_oracle.py','tests/crop-co2/co2_source_oracle.py']:
      inputs[p]=sha(ROOT/p)
    inputs.update({p:sha(ROOT/p) for p in PINS})""")
replace("'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']", "'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90','co2_oracle.f90']")
replace("'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'", "'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS','managed_rooted':b'MC_IRR01_MANAGED_ADAPTIVE_ROOTED_DAILY_SOURCE_RESTART=PASS'")
sys.path[:0]=[str(ROOT/'tests/mc-irr01'),str(ROOT/'tests/root-growth'),str(ROOT/'tests/crop-cycle'),str(ROOT/'tests/crop-co2')]
from managed_root_cycle_driver import prepare as rooted
from oxygen_source_oracle import prepare as oxygen_oracle
from co2_source_oracle import prepare as co2_oracle
exec(compile(s,str(path),'exec'),{'__file__':str(path),'__name__':'__main__','rooted':rooted,'oxygen_oracle':oxygen_oracle,'co2_oracle':co2_oracle})
