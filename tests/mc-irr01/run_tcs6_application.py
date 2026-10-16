"""Targeted real weekly application using the admitted controlled provider build."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tests/mc-irr01/run_managed_weather_application.py';code=path.read_text();anchor="exec(compile(s,str(path),'exec'),";idx=code.index(anchor)
insert='''
from tcs6_cycle_driver import prepare as weekly
additional="    drivers={name:weekly(ROOT,output/(name+'.f90'),dcs,trigger)for name,dcs,trigger in [('weekly_dcs1',1,True),('weekly_dcs2',2,True),('weekly_nontrigger',2,False)]}\\n"
additional+="    for p in ['tests/mc-irr01/run_tcs6_application.py','tests/mc-irr01/tcs6_cycle_driver.py','tests/mc-irr01/material_root_cycle_driver.py','tests/mc-irr01/material_root_selection_oracle.inc']:\\n      inputs[p]=sha(ROOT/p)\\n"
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})",additional+"    inputs.update({p:sha(ROOT/p) for p in PINS})")
replace("if name in ('allocation_guards','managed_rooted7','managed_rooted8')else", "if name.startswith('weekly_')or name in ('allocation_guards','managed_rooted7','managed_rooted8')else")
marker="'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'"
replace(marker,marker+''.join(","+repr(name)+":b'TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS'"for name in ['weekly_dcs1','weekly_dcs2','weekly_nontrigger']))
'''
code=code[:idx]+insert+code[idx:];code=code.replace("'co2_oracle':co2_oracle}","'co2_oracle':co2_oracle,'weekly':weekly}")
exec(compile(code,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
