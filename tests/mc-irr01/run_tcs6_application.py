"""Targeted real weekly application using the admitted controlled provider build."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tests/mc-irr01/run_managed_weather_application.py';code=path.read_text();anchor="exec(compile(s,str(path),'exec'),";idx=code.index(anchor)
insert='''
replace("'src/kernel/mod_kernel_committed_persistence.f90'],ROOT,'closure')", "'src/kernel/mod_kernel_committed_persistence.f90','src/adapter/mod_crop_soil_n_joint_restart_file.f90'],ROOT,'closure')")
from tcs6_cycle_driver import prepare_native as weekly
from tcs6_native_controls import execute as native_controls
additional="    drivers={name:weekly(ROOT,output/(name+'.f90'),dcs,trigger)for name,dcs,trigger in [('weekly_dcs1',1,True),('weekly_dcs2',2,True),('weekly_nontrigger',2,False)]}\\n"
additional+="    for p in ['tests/mc-irr01/run_tcs6_application.py','tests/mc-irr01/tcs6_cycle_driver.py','tests/mc-irr01/material_root_cycle_driver.py','tests/mc-irr01/material_root_selection_oracle.inc','tests/mc-irr01/tcs6_native_controls.py']:\\n      inputs[p]=sha(ROOT/p)\\n"
replace("    inputs.update({p:sha(ROOT/p) for p in PINS})",additional+"    inputs.update({p:sha(ROOT/p) for p in PINS})")
replace("if name in ('allocation_guards','managed_rooted7','managed_rooted8')else", "if name.startswith('weekly_')or name in ('allocation_guards','managed_rooted7','managed_rooted8')else")
marker="'managed':b'MC_IRR01_MANAGED_WEATHER_SENSOR_SSDI_ALLOCATION_MASS_RESTART=PASS'"
replace(marker,marker+''.join(","+repr(name)+":b'TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS'"for name in ['weekly_dcs1','weekly_dcs2','weekly_nontrigger']))

extra="""
                    if name.startswith('weekly_'):
                      for phase in ['neutral','hydraulic']:
                        for native_mode in ['native-write','native-resume','native-write-active','native-resume-active']:
                          native_raw,native_event=session.command([str(exe),*[str(fixture/p)for p in ['weather.999','altered.999','bad.999','backup.999']],native_mode,phase],build,f'native-{name}-{phase}-{native_mode}')
                          native_marker=b'TCS6_NATIVE_PREFIX_PROCESS_EXIT=PASS'if native_mode.startswith('native-write')else b'TCS6_NATIVE_FRESH_PROCESS_NO_DAY_REPLAY=PASS'
                          if native_marker not in native_raw:raise RuntimeError('native weekly marker missing')
                          digest=hashlib.sha256(native_raw).hexdigest()
                          output_hashes[(opt,name,phase,native_mode)]=digest
                          results.append({'opt':opt,'driver':name,'moisture':phase,'mode':native_mode,'stdout_sha256':digest,'wall_seconds':native_event['wall_seconds'],'returncode':native_event['returncode']})
                        tag='morning'if phase=='neutral'else'dayend'
                        paths=[Path(str(exe)+'.'+tag+'.'+suffix)for suffix in ['full','opaque','resumed','active.resumed']]
                        if not all(p.read_bytes()==paths[0].read_bytes()for p in paths):raise RuntimeError('continuous/opaque/fresh native weekly endpoint drift')
                        controls=native_controls(session,exe,fixture,phase,build,opt,name)
                        write(output/(f'DECODER_{opt}_{name}_{phase}.json'),controls)
"""
replace("                    write(output/'PROGRESS.json',{'results':results,'events':session.events})",extra+"                    write(output/'PROGRESS.json',{'results':results,'events':session.events})")

'''
code=code[:idx]+insert+code[idx:];code=code.replace("'co2_oracle':co2_oracle}","'co2_oracle':co2_oracle,'weekly':weekly,'native_controls':native_controls}")
exec(compile(code,str(path),'exec'),{'__file__':str(path),'__name__':'__main__'})
