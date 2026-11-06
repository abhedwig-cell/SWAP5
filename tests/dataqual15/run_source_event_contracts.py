"""Real source endpoint/amount contract plus unchanged INT13 owner at O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir()
window='src/runtime/mod_interception_source_window_runtime.f90'
cases={'endpoint':[window,'tests/dataqual15/source_event_endpoint_driver.f90'],
'int13':['src/solver/mod_soil_water_solver_contract.f90','src/solver/mod_b110_default_mvg_provider.f90',
'src/process/mod_restricted_surface_evaporation.f90','src/solver/mod_b110_dynamic_top_boundary_provider.f90',
'src/crop/mod_crop_root_uptake_input_contract.f90','src/process/mod_rutter_interception_process.f90',
'src/process/mod_rutter_event_integrator.f90',window,'src/runtime/mod_rutter_source_window_processor.f90',
'src/runtime/mod_fmr_rutter_output_application_binding.f90','src/runtime/mod_fmr_rutter_source_window_application.f90',
'tests/fpm/test_f_mig431_int13_rutter_source_window.f90']}
report={'status':'RUNNING','scope':'SOURCE_EVENT_SELECTION_AND_UNCHANGED_OWNER_NOT_WHOLE481',
'source_sha256':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest()for ns in cases.values()for n in ns},'events':[]}
for mode in ['O0','O2']:
 for name,ns in cases.items():
  case=out/(mode+'-'+name);case.mkdir();exe=case/'test.exe'
  flags=['-'+mode,'-std=f2008','-pedantic-errors','-ffree-line-length-none','-Wall','-Wextra','-Werror',
  '-Wno-error=unused-dummy-argument','-Wno-error=compare-reals','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
  commands=[('compile',[str(a.compiler.resolve()),*flags,'-J'+str(case),'-I'+str(case),*[str(ROOT/n)for n in ns],'-o',str(exe)]),('native',[str(exe)])]
  for label,command in commands:
   start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=90)
   (case/(label+'.stdout')).write_bytes(r.stdout);(case/(label+'.stderr')).write_bytes(r.stderr)
   report['events'].append({'optimization':mode,'case':name,'label':label,'command':command,'seconds':time.monotonic()-start,'returncode':r.returncode})
   (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');assert r.returncode==0,r.stderr.decode(errors='replace')
for name in cases:assert (out/('O0-'+name)/'native.stdout').read_bytes()==(out/('O2-'+name)/'native.stdout').read_bytes()
report['status']='SOURCE_EVENT_SELECTION_AND_ORIGINAL_INT13_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
