"""Diagnose the failed frozen thermal envelope with a fresh native DTMAX=.01 run.

This is a disclosed numerical counterfactual, never a new original project or
a replacement for the failed preregistered coarse-native result. Physical
inputs, model owners, acceptance tolerances and the frozen envelope stay fixed.
"""
import argparse,csv,hashlib,io,json,struct,subprocess,sys,tarfile,time
from pathlib import Path
from original_sources import build_original
from checkpoint_layout import layout
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--donor',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 donor=a.donor.resolve();donor_result=json.loads((donor/'RESULT.json').read_text());registration=json.loads((donor/'PREREGISTRATION.json').read_text())
 assert donor_result['numerical_resolution_gate_pass'] is False
 assert sha(donor/'PREREGISTRATION.json')==donor_result['preregistration_sha256']
 cap='0.000625';source=donor/('dtmax-'+cap)/'nodal_profiles.csv'
 assert sha(source)==donor_result['runs'][cap]['profiles_sha256']
 reference={}
 for row in csv.DictReader(source.open()):reference.setdefault(int(row['day']),[]).append(row)
 with tarfile.open(ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz')as tar:
  spec=json.load(tar.extractfile('SPEC.json'));coarse={}
  for name in tar.getnames():
   if name.startswith(spec['full']+'/checkpoint')and name.endswith('.bin'):
    raw=tar.extractfile(name).read();coarse[int(layout(raw)['clock'])]=raw
 days=sorted(coarse);assert days[-1]==1827
 report=dict(status='RUNNING',scope='NATIVE_NUMERICAL_COUNTERFACTUAL_NOT_NEW_ORIGINAL_PROJECT',dtmax_day=.01,physical_input_changes=False,production_owners_changed=False,original_preregistered_gate_pass=False,scientific_equivalence=False,wall_cap_seconds=7200,expected_seconds=2400,selection_reason='The independently held-out donor gate failed only temperature at the finest reference; the existing native140-day refinement reduced thermal error from.00356 to.000827C. A fresh day1 full trajectory tests the same frozen thermal envelope at the actual worst late dates without changing a physical owner.',donor_result_sha256=sha(donor/'RESULT.json'),registration_sha256=sha(donor/'PREREGISTRATION.json'),profiles_sha256=sha(source),events=[])
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(command,label,timeout):
  print('NATIVE_THERMAL_START',label,flush=True);start=time.monotonic()
  with (out/(label+'.stdout')).open('wb')as so,(out/(label+'.stderr')).open('wb')as se:
   proc=subprocess.Popen(list(map(str,command)),stdout=so,stderr=se,cwd=ROOT)
   while proc.poll()is None:
    if time.monotonic()-start>timeout:proc.kill();proc.wait();raise AssertionError(('censored',label,timeout))
    progress=out/'native/PROGRESS.json'
    if label=='trajectory'and progress.exists():print('NATIVE_THERMAL_PROGRESS',progress.read_text().replace('\n',' '),flush=True)
    time.sleep(30)
  report['events'].append(dict(label=label,returncode=proc.returncode,seconds=time.monotonic()-start));save()
  assert proc.returncode==0,(label,(out/(label+'.stderr')).read_text()[-3000:])
 original=build_original(out/'original-O2',str(a.compiler.resolve()),'O2',utilities_only=True)
 driver=out/'refined_grass.f90';text=(ROOT/'app/grass_project/initial_interval.f90').read_text();needle="call rdsdor('dtmax',1d-7,1d0,source_dtmax)";assert text.count(needle)==1
 driver.write_text(text.replace(needle,needle+';source_dtmax=min(source_dtmax,0.01d0)'),newline='\n')
 report['driver_sha256']=sha(driver);save()
 build=out/'build'
 run([sys.executable,'-B',ROOT/'tools/solute/build_grass_diagnostic.py','--compiler',a.compiler.resolve(),'--input-archive',original/'ttobj/libttutil.a','--output',build,'--optimization','O2','--profile','checked','--driver',driver,'--end','1','--policy','retained'],'build',600)
 native=out/'native'
 run([sys.executable,'-B',ROOT/'tests/dataqual15/run_original.py','--bundle',build,'--output',native,'--end','1827','--capture',*days,'--timeout','7200'],'trajectory',7240)
 terminal=json.loads((native/'RESULT.json').read_text());assert terminal['returncode']==0 and terminal['completed_days']==1827 and not terminal['censored']
 checkpoints={}
 for day in days:
  path=native/f'checkpoint-{day}.bin'
  if day==1827:path=native/'checkpoint.bin'
  assert path.exists(),('missing atomic diagnostic checkpoint',day)
  raw=path.read_bytes();assert layout(raw)['clock']==day;checkpoints[day]=raw
 def thermal(raw,day):
  s=layout(raw);n=s['nodes'];values=struct.unpack_from('='+str(n)+'d',raw,s['physical']+16*n+16)
  ref=[float(r['temperature_c'])for r in sorted(reference[day],key=lambda r:int(r['node']))];assert len(ref)==n
  errors=[abs(a-b)for a,b in zip(values,ref)];i=max(range(n),key=lambda i:errors[i])
  return dict(maximum_temperature_error_c=errors[i],node=i+1,native_c=values[i],donor_c=ref[i])
 report['profiles']={str(day):dict(coarse=thermal(coarse[day],day),refined=thermal(raw,day))for day,raw in checkpoints.items()if day in reference}
 limit=registration['bounds']['PROFILE_temperature_c']['limit'];maximum=max(v['refined']['maximum_temperature_error_c']for v in report['profiles'].values())
 report.update(status='NATIVE_THERMAL_REFINEMENT_MEASURED',completed_days=1827,frozen_temperature_limit_c=limit,maximum_refined_temperature_error_c=maximum,refined_inside_original_thermal_envelope=maximum<=limit,terminal=terminal,raw_sha256={f.name:sha(f)for f in native.iterdir()if f.is_file()})
 save();print(json.dumps({k:v for k,v in report.items()if k not in ['terminal','raw_sha256']},indent=2),flush=True)
if __name__=='__main__':main()
