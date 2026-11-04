"""Independent actual final MICRO carrier, exact table and original-source audit."""
import argparse,copy,hashlib,io,json,os,subprocess,sys,tarfile,tempfile
from pathlib import Path
from full_profile_evidence import unpack
from root_oxygen_evidence import data,table
import root_oxygen_observer as owner
from matched_micro_observer import instrument,table_instrument,MAIN,BACKEND,TABLE
from matched_micro_replay import select,replay,source,analyze
ROOT=owner.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';STEM='MATCHED_MICRO_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
def native(files,old,reg):
 reports={};selected={}
 for opt in ('O0','O2'):
  f={n[len(opt)+1:]:b for n,b in files.items() if n.startswith(opt+'/')};build=json.loads(f['build/BUILD.json'])
  assert build['baseline']==json.loads(old[opt+'/build/BUILD.json'])['baseline']
  assert build['complete_module_closure_rebuilt'] and len(build['compiled_objects_sha256'])==len(build['baseline']['source_sha256'])==236
  assert len(build['events'])==237 and all(e['returncode']==0 for e in build['events'])
  assert set(build['compiled_objects_sha256'])=={str(i)+'.o' for i in range(236)}
  for n,h in build['compiled_objects_sha256'].items():assert sha(f['build/'+n])==h,n
  expected={MAIN:owner.instrument((ROOT/MAIN).read_text()),BACKEND:instrument((ROOT/BACKEND).read_text(),reg),TABLE:table_instrument((ROOT/TABLE).read_text())}
  assert set(build['patches'])==set(expected)
  for name,text in expected.items():
   p=build['patches'][name];assert f['build/'+p['source']].decode()==text and sha(f['build/'+p['source']])==p['source_sha256'] and sha(f['build/'+p['object']])==p['object_sha256']
  assert sha(f['build/observed.exe'])==build['executable_sha256'] and sha(f['build/link.args'])==build['link_response_sha256']
  for phase in ('whole','strict-own-537'):
   r=json.loads(f[phase+'/RESULT.json']);assert r['returncode']==0 and not r['from_start'] and r['executable_sha256']==build['executable_sha256']
   seed=sha(f['whole/checkpoint-537.bin']) if phase!='whole' else json.loads(old[opt+'/whole/RESULT.json'])['restart_sha256'];assert r['restart_sha256']==seed
   assert r['scope']==('STRICT_SAME_BUILD_RESTART_MEASUREMENT' if phase!='whole' else 'INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION')
   assert r['inputs']==json.loads(old[opt+'/whole/RESULT.json'])['inputs']
   for n,h in r['inputs'].items():assert sha(f[phase+'/'+n])==h and f[phase+'/'+n]==old[opt+'/whole/'+n]
  assert f['whole/checkpoint.bin']==f['strict-own-537/checkpoint.bin']==old[opt+'/whole/checkpoint.bin']
  for n in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):assert f['whole/'+n]==old[opt+'/whole/'+n]
  for n,clock in [('budget.csv','t1_day'),('crop.csv','day')]:assert table(f['strict-own-537/'+n])==[r for r in table(f['whole/'+n]) if float(r[clock])>537]
  for n in ('root_accepted.dat','root_nodes.dat','micro_trials.dat','micro_tables.dat'):assert f['strict-own-537/'+n].splitlines()==[r for r in f['whole/'+n].splitlines() if float(r.split()[0])>=537]
  raw=data(f['whole/micro_trials.dat'],40);tables=data(f['whole/micro_tables.dat'],6);nodes=data(f['whole/root_nodes.dat'],104);accepted=data(f['whole/root_accepted.dat'],9)
  frames=select(raw,tables,nodes,accepted,reg);controls=[]
  for label in ('missing_frame','ambiguous_forcing','wrong_final_sink','missing_table','ambiguous_table','nonfinite_carry','wrong_accepted_receipt'):
   rr,tt,aa=copy.deepcopy((raw,tables,accepted))
   if label=='missing_frame':rr=[r for r in rr if r[:2]!=frames[0][0][0][:2]]
   elif label=='ambiguous_forcing':
    extra=copy.deepcopy(frames[0][0]);extra[0][34]+=1e-3;rr.extend(extra)
   elif label=='wrong_final_sink':rr[0][39]+=1e-6
   elif label=='missing_table':tt.pop(0)
   elif label=='ambiguous_table':
    extra=tt[0].copy();extra[4]+=1e-6;tt.append(extra)
   elif label=='nonfinite_carry':rr[0][26]=float('nan')
   else:aa.remove(reg['selected_profiles'][0]['receipt'])
   try:select(rr,tt,nodes,aa,reg)
   except AssertionError:controls.append(label)
   else:raise AssertionError('accepted MICRO defect '+label)
  selected[opt]=frames;reports[opt]=dict(selected_profiles=len(frames),rooted_nodes=sum(int(f[0][10]) for f,t in frames),observed_rows=len(raw),actual_table_rows=len(tables),all236_objects_verified=True,negative_controls=controls)
 return reports,selected
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/matched_oxygen_evidence.py'),'--compiler',a.compiler],cwd=ROOT,check=True)
 m=json.loads((BASE/'ROOT_OXYGEN_EVIDENCE_20261104.json').read_text());old=unpack(BASE/'ROOT_OXYGEN_EVIDENCE_20261104.tar.xz',m['files_sha256'])
 reg=json.loads((BASE/'MATCHED_MICRO_PREREGISTRATION_20261104.json').read_text())
 if a.capture:files={f.relative_to(a.capture.resolve()).as_posix():f.read_bytes() for f in a.capture.resolve().rglob('*') if f.is_file() and f.suffix!='.mod'}
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==record['archive_sha256'];files=unpack(path,record['files_sha256'])
 report,frames=native(files,old,reg);replays={}
 if not a.capture:assert report==json.loads(files['AUDIT.json'])['native']
 with tempfile.TemporaryDirectory(prefix='swap5-actual-micro-') as temp:
  root=a.capture.resolve() if a.capture else Path(temp)
  for opt in ('O0','O2'):replays[opt]=replay(frames[opt],opt,root/('literal-'+opt),a.compiler)
  if a.capture:
   for f in root.glob('literal-*/*'):
    if f.is_file() and f.suffix!='.mod':files[f.relative_to(root).as_posix()]=f.read_bytes()
  else:
   literal,_=source()
   for opt in ('O0','O2'):
    r=json.loads(files[f'literal-{opt}/REPLAY.json']);assert files[f'literal-{opt}/literal.f90'].decode()==literal
    assert sha(files[f'literal-{opt}/oracle.exe'])==r['executable_sha256'] and sha(literal.encode())==r['source_sha256']
    for i,(f,t) in enumerate(frames[opt]):
     payload='\n'.join(' '.join(f'{v:.17e}' for v in row) for row in f+t)+'\n'
     assert files[f'literal-{opt}/{i}.input']==payload.encode() and sha(payload.encode())==r['profiles'][i]['input_sha256']
     assert analyze(files[f'literal-{opt}/{i}.stdout'],f)=={k:v for k,v in r['profiles'][i].items() if k not in ('profile','input_sha256','output_sha256','returncode')}
  # Corrupt an actual original-output attribution; never waive its1e-14 bound.
  raw=(root/'literal-O0/0.stdout').read_bytes();lines=raw.decode().splitlines()
  i=next(i for i,l in enumerate(lines) if l.startswith('ATTR '));values=list(map(float,lines[i].split()[1:]));values[0]+=1e-6
  lines[i]='ATTR '+' '.join(map(str,values))
  try:analyze(('\n'.join(lines)+'\n').encode(),frames['O0'][0][0])
  except AssertionError:pass
  else:raise AssertionError('accepted falsified literal attribution')
 result=dict(native=report,windows_replay=replays,whole_scientific_admission=False)
 if a.capture:
  files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode();path=BASE/(STEM+'.tar.xz')
  with tarfile.open(path,'w:xz') as t:
   for n,b in sorted(files.items()):entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  deps=dict(json.loads((BASE/'MATCHED_OXYGEN_EVIDENCE_20261104.json').read_text())['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/matched_micro_observer.py','tests/dataqual15_hupsel/matched_micro_driver.f90','tests/dataqual15_hupsel/matched_micro_replay.py','tests/dataqual15_hupsel/matched_micro_evidence.py','.github/workflows/hupsel-matched-micro.yml','tests/physics/run_ppa_micro02_source_oracle.py','tests/physics/test_ppa_micro02_source_oracle.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90','reference/swap-4.3.1/b1_11_frost_source/SWAP/rootextraction.f90','integration/dataqual15_hupsel/MATCHED_MICRO_PREREGISTRATION_20261104.json'):deps[n]=norm(ROOT/n)
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(status='ACTUAL_MICRO_ATTRIBUTION_AND_BOUNDED_ORIGINAL_UPTAKE_AUDIT_COMPLETE',archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256=deps,whole_scientific_admission=False),indent=2)+'\n')
 summary={o:dict(maximum_node_error=max(p['maximum_node_uptake_error'] for p in r['profiles']),maximum_attribution_error=max(p['attribution_maximum_error'] for p in r['profiles']),all_source_checks_and_node_bounds=all(p['inside_unchanged_node_bound'] for p in r['profiles']),maximum_native_leaf_demand_defect=max(abs(p['native_leaf_demand_defect'] or 0) for p in r['profiles']),maximum_original_leaf_demand_defect=max(abs(p['original_leaf_demand_defect'] or 0) for p in r['profiles'])) for o,r in replays.items()}
 print('ACTUAL_MICRO_ATTRIBUTION_AND_BOUNDED_ORIGINAL_UPTAKE_AUDIT_COMPLETE');print(json.dumps(summary))
if __name__=='__main__':main()
