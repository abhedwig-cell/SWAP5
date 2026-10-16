"""Extend the existing controlled managed-weather Session with actual root-policy drivers."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tests/mc-irr01/run_managed_weather_application.py'
code=path.read_text()
anchor="exec(compile(s,str(path),'exec'),"
idx=code.index(anchor)
insert='''
from material_root_cycle_driver import prepare as material_root
extra=[]
for criterion in (2,3,4):
 for dcs in (1,2):extra.append((f'material_{criterion}_{dcs}',criterion,dcs,True))
 extra.append((f'material_{criterion}_no',criterion,1,False))
replacement="    inputs.update({p:sha(ROOT/p) for p in PINS})"
additional=""
for name,criterion,dcs,trigger in extra:
 additional+=f"    drivers['{name}']=material_root(ROOT,output/'{name}.f90',{criterion},{dcs},{trigger})\\n"
additional+="    for p in ['tests/mc-irr01/run_material_root_application.py','tests/mc-irr01/material_root_cycle_driver.py','tests/mc-irr01/material_root_selection_oracle.inc']:\\n      inputs[p]=sha(ROOT/p)\\n"
replace(replacement,additional+replacement)
replace("if name in ('allocation_guards','managed_rooted7','managed_rooted8')else", "if name in ('allocation_guards','managed_rooted7','managed_rooted8')or name.startswith('material_')else")
marker="'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'"
replace(marker,marker+''.join(","+repr(name)+":b'MC_IRR01_MATERIAL_ROOT_POLICY_PHYSICAL_LITERAL_RESTART=PASS'"for name,_,_,_ in extra))
'''
code=code[:idx]+insert+code[idx:]
code=code.replace("'co2_oracle':co2_oracle}","'co2_oracle':co2_oracle,'material_root':material_root}")
exec(compile(code,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
