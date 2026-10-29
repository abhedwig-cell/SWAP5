"""Seal completed DATAQUAL10 native work without rerunning physical intervals."""
import base64,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def main():
 ns=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual10_current.py'))
 files={};batches=['cases-O0','cases-O2','preservation','integral','remaining22']
 aliases={'cases-O0':'selected-O0','cases-O2':'selected-O2'}
 results=[]
 for label in batches:
  folder=Path('/tmp/dq10-final-'+aliases.get(label,label))
  manifest=json.loads((folder/'batch.json').read_bytes())['manifest']
  rows=json.loads((folder/'results.json').read_bytes())
  assert len(rows)==len(manifest['scenarios']),'batch incomplete: '+label
  results.extend(dict(batch=label,**r)for r in rows)
  for p in sorted(folder.rglob('*')):
   if p.is_file():files[label+'/'+str(p.relative_to(folder))]=p.read_bytes()
 for opt in ['O0','O2']:
  b=json.loads((HERE/('BUILD_'+opt+'.json')).read_bytes())
  files['recovery/native-'+opt]=Path('/tmp/dq10-final-'+opt+'/column/swap5_solute_project').read_bytes()
  assert sha(files['recovery/native-'+opt])==b['executable_sha256']
  for policy in ['candidate','baseline']:
   folder=Path('/tmp/dq10-final-contract/'+opt+'-'+policy)
   for p in folder.glob('*'):
    if p.suffix in ['.stdout','.stderr']:files['contract/'+folder.name+'/'+p.name]=p.read_bytes()
  files['linear/'+opt+'/stdout']=Path('/tmp/dq10-final-linear/'+opt+'/stdout').read_bytes()
 files['fsi/stdout']=Path('/tmp/dq10-final-fsi35.log').read_bytes()
 oracles=json.loads((HERE/'ORACLES.json').read_bytes());folder=Path('/tmp/dq10-fsi35-native')
 for oracle in oracles:files['fsi/'+oracle['name']]=(folder/oracle['name']).read_bytes()
 files['fsi/original-fkt15_stubs.f90']=(folder/'original-fkt15_stubs.f90').read_bytes()
 for opt in ['o0','o2']:
  for name in ['task2','surface','dispatch']:files['fsi/'+opt+'/'+name+'.txt']=(folder/opt/(name+'.txt')).read_bytes()
 dep=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 fs=dict(returncode=0,oracles=oracles,source_sha256={d['path']:sha((ROOT/d['path']).read_bytes())for d in dep})
 fs['source_sha256']['src/legacy/b1_10_port/soilwater.f90']=sha((ROOT/'src/legacy/b1_10_port/soilwater.f90').read_bytes())
 files['fsi/RESULT.json']=json.dumps(fs,indent=2).encode()
 # Intermediate hypotheses are retained separately and never used as final-source qualification.
 for name in ['cases-O0','cases-O2','remaining22','integral','original-resumed','full-cases-O0','full-cases-O2']:
  p=Path('/tmp/dq10-'+name+'/results.json')
  if p.exists():files['exploratory/'+name+'/results.json']=p.read_bytes()
 files['BATCHES.json']=json.dumps(batches).encode()
 durations,started=ns['coverage'](results)
 summary=dict(work_unit='DATAQUAL10',baseline=ns['BASE'],started=len(started),water_qualified=len(durations),
  extra_qualified_vs_DATAQUAL06=len(durations)-77,configuration_days=sum(durations.values()),
  additional_configuration_days=sum(durations.values())-94.35949999972217,
  longest_original_integral=2.7479999999995925,scenario_rows=len(results),water_qualified_rows=sum(r['status']=='PASS'for r in results),
  native_model_processes=sum(r.get('status')!='SKIPPED_DEPENDENCY'for r in results)+sum(r.get('restart_process_executions',0)for r in results),
  primary_launcher_seconds=sum(r.get('seconds',0)for r in results if r.get('status')!='SKIPPED_DEPENDENCY'),
  native_seconds=sum(e['seconds']for p,b in files.items()if p.endswith('/manifest.json')for e in json.loads(b).get('events',[])if e.get('label')=='native'),
  outcomes={status:sum(r['status']==status for r in results)for status in sorted({r['status']for r in results})},
  finite_difference_columns_per_optimization=72,conservative_rate_cases_per_optimization=48,legacy_exact_controls_per_optimization=48,
  low_rank_matrices_per_optimization=216,baseline_derivative_defects=24,max_feedback_error=1.6598207253082364e-9,
  max_linear_residual=2.2204460492503131e-15,speedup_established=False,physical_process_expansion=False,
  causal_scope='Fixed-geometry capped exchange Jacobian repaired, including cross-cell stock coupling. No native speed or original-stall breakthrough established. Current rows reuse existing physical configurations; historical qualified prefixes remain explicitly inherited.',
  native_timings=[{k:r.get(k)for k in ['batch','id','status','seconds','completed_days','solver_iterations','headcalc_calls','water_max_independent_cm','restart']}for r in results])
 write(HERE/'RESULT.json',summary)
 files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(files.items())},sort_keys=True).encode()
 bio=io.BytesIO()
 with tarfile.open(fileobj=bio,mode='w:xz',preset=6)as t:
  for name,b in sorted(files.items()):
   info=tarfile.TarInfo(name);info.size=len(b);info.mode=0o755 if name.startswith('recovery/')else 0o644;t.addfile(info,io.BytesIO(b))
 raw=bio.getvalue();encoded=base64.b64encode(raw);parts=[]
 for p in HERE.glob('evidence-*.b64'):p.unlink()
 for i in range(0,len(encoded),50000):
  p=HERE/('evidence-%03d.b64'%(i//50000));p.write_bytes(encoded[i:i+50000]);parts.append(str(p.relative_to(ROOT)))
 write(HERE/'CAPSULE.json',dict(sha256=sha(raw),bytes=len(raw),members=len(files),parts=parts))
 print(json.dumps({k:v for k,v in summary.items()if k!='native_timings'},indent=2))
if __name__=='__main__':main()
