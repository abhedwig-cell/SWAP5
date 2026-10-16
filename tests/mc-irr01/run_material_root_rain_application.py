"""Fresh two-program physical witness for a risk hidden by a small depth cap."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tests/mc-irr01/run_managed_weather_application.py'
code=path.read_text()
anchor="exec(compile(s,str(path),'exec'),"
idx=code.index(anchor)
insert='''
from material_root_rain_driver import prepare as rain_root
additional="    drivers={'material_rain':rain_root(ROOT,output/'material_rain.f90')}\\n"
additional+="    for p in ['tests/mc-irr01/run_material_root_rain_application.py','tests/mc-irr01/material_root_rain_driver.py','tests/mc-irr01/material_root_cycle_driver.py','tests/mc-irr01/material_root_selection_oracle.inc']:\\n      inputs[p]=sha(ROOT/p)\\n"
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})",additional+"    inputs.update({p:sha(ROOT/p) for p in PINS})")
replace("if name in ('allocation_guards','managed_rooted7','managed_rooted8')else", "if name in ('allocation_guards','managed_rooted7','managed_rooted8','material_rain')else")
marker="'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'"
replace(marker,marker+",'material_rain':b'MATERIAL_ROOT_UNCAPPED_DAILY_RAIN='")
'''
code=code[:idx]+insert+code[idx:]
code=code.replace("'co2_oracle':co2_oracle}","'co2_oracle':co2_oracle,'rain_root':rain_root}")
exec(compile(code,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
output=Path(sys.argv[sys.argv.index('--output')+1])
result=json.loads((output/'RESULTS.json').read_text())
assert len(result['results'])==2
for row in result['results']:
    assert row['driver']=='material_rain' and row['returncode']==0
print('MC_IRR01_UNCAPPED_MATERIAL_ROOT_DAILY_RAIN_PHYSICAL_O0_O2=PASS')
