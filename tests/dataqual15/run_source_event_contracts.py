"""Real source endpoint/amount contract plus unchanged INT13 owner at O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
p.add_argument('--legacy-phase-source',type=Path,help='Immutable original module/main preimages; reproduce actual early-index defect only.')
a=p.parse_args();out=a.output.resolve();out.mkdir()
window='src/runtime/mod_interception_source_window_runtime.f90'
cases={'endpoint':[window,'tests/dataqual15/source_event_endpoint_driver.f90'],
'phase':[window,'tests/dataqual15/source_event_phase_driver.F90'],
'int13':['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_b110_default_mvg_provider.f90',
'src/process/mod_restricted_surface_evaporation.f90','src/solver/mod_b110_dynamic_top_boundary_provider.f90',
'src/crop/mod_crop_root_uptake_input_contract.f90','src/process/mod_rutter_interception_process.f90',
'src/process/mod_rutter_event_integrator.f90',window,'src/runtime/mod_rutter_source_window_processor.f90',
'src/runtime/mod_fmr_rutter_output_application_binding.f90','src/runtime/mod_fmr_rutter_source_window_application.f90',
'tests/fpm/test_f_mig431_int13_rutter_source_window.f90']}
legacy_body=None
if a.legacy_phase_source:
 original=a.legacy_phase_source.resolve()
 pins=json.loads((original/'SOURCE_PINS.json').read_text())
 assert all(hashlib.sha256((original/Path(n).name).read_bytes()).hexdigest()==h for n,h in pins.items())
 lines=(original/'main_water.f90').read_text().splitlines()
 selected=[line for line in lines if 'do while(rain_index<rain_count.and.rain_ends(rain_index)<=cursor+1d-12)'in line]
 assert len(selected)==1
 legacy_body=selected[0]+'\n'
 cases={'phase':[str(original/'mod_interception_source_window_runtime.f90'),'tests/dataqual15/source_event_phase_driver.F90']}
report={'status':'RUNNING','scope':'SOURCE_EVENT_SELECTION_AND_UNCHANGED_OWNER_NOT_WHOLE481',
'source_sha256':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest()for ns in cases.values()for n in ns},'events':[]}
if legacy_body:
 report['legacy_caller_source_sha256']=pins
 report['literal_legacy_body_sha256']=hashlib.sha256(legacy_body.encode()).hexdigest()
for mode in ['O0','O2']:
 for name,ns in cases.items():
  case=out/(mode+'-'+name);case.mkdir();exe=case/'test.exe'
  flags=['-'+mode,'-std=f2008','-pedantic-errors','-ffree-line-length-none','-Wall','-Wextra','-Werror',
  '-Wno-error=unused-dummy-argument','-Wno-error=compare-reals','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
  if legacy_body:
   (case/'legacy_phase_body.inc').write_text(legacy_body)
   flags.append('-DLEGACY_PHASE')
  commands=[('compile',[str(a.compiler.resolve()),*flags,'-J'+str(case),'-I'+str(case),*[str(ROOT/n)for n in ns],'-o',str(exe)]),('native',[str(exe)])]
  for label,command in commands:
   start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=90)
   (case/(label+'.stdout')).write_bytes(r.stdout);(case/(label+'.stderr')).write_bytes(r.stderr)
   report['events'].append({'optimization':mode,'case':name,'label':label,'command':command,'seconds':time.monotonic()-start,'returncode':r.returncode})
   expected_defect=bool(legacy_body)and label=='native'
   if r.returncode!=0 and not expected_defect:report['status']='FAILED_'+mode+'_'+name+'_'+label
   (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
   if expected_defect:
    assert r.returncode!=0 and b'UNCOMMITTED_RAIN_EVENT_SKIPPED_IN_3_ACTUAL_CASES'in r.stderr,r.stderr.decode(errors='replace')
   else:assert r.returncode==0,r.stderr.decode(errors='replace')
for name in cases:assert (out/('O0-'+name)/'native.stdout').read_bytes()==(out/('O2-'+name)/'native.stdout').read_bytes()
report['status']='ORIGINAL_CALLER_EARLY_PHASE_ADVANCE_REPRODUCED_3_O0_O2'if legacy_body else'SOURCE_PHASE_EVENT_AND_ORIGINAL_INT13_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
