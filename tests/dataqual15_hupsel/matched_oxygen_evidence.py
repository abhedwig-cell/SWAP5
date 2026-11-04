"""Actual accepted-carrier selection and unchanged original oxygen replay."""
import argparse,base64,collections,copy,gzip,hashlib,io,json,math,os,subprocess,sys,tarfile,tempfile
from pathlib import Path
from full_profile_evidence import unpack
from root_oxygen_evidence import data,table
from matched_oxygen_observer import instrument,BACKEND,MAIN
import root_oxygen_observer as owner
ROOT=owner.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';STEM='MATCHED_OXYGEN_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
def select(raw,nodes,accepted,reg):
 assert len(raw)%34==0
 frames=[raw[i:i+34] for i in range(0,len(raw),34)]
 result=[]
 for selected in reg['selected_profiles']:
  receipt=selected['receipt'];assert receipt in accepted
  start=next(n for n in nodes if n[:2]==receipt[:2]);candidates=[]
  for f in frames:
   if f[0][:2]!=receipt[:2]:continue
   assert [int(r[9]) for r in f]==list(range(1,35)) and all(r[:9]==f[0][:9] for r in f)
   if [r[11] for r in f]!=start[2:36] or [r[12] for r in f]!=start[36:70]:continue
   assert f[0][7]==receipt[7]
   candidates.append(tuple(tuple(r) for r in f))
  assert candidates and len(set(candidates))==1,'missing or ambiguous actual forcing'
  f=[list(r) for r in candidates[0]];n=int(f[0][10]);assert 1<=n<=34 and all(int(r[10])==n for r in f)
  assert all(all(map(math.isfinite,r)) for r in f)
  assert all(0<=r[18]<=1 and abs(r[17]-r[16]*(r[18] if i<n else 1))<=1e-12 for i,r in enumerate(f))
  assert f[n-1][18]==receipt[7]
  assert abs(math.fsum(r[16]-r[17] for r in f)-f[0][4])<=1e-12
  result.append(f)
 return result
def output(raw,frame):
 values=[list(map(float,l.split())) for l in raw.splitlines()];n=int(frame[0][10])
 assert len(values)==n and [int(r[0]) for r in values]==list(range(1,n+1))
 assert all(len(r)==4 and all(map(math.isfinite,r)) for r in values)
 for r,f in zip(values,frame):
  assert r[2]==f[18] and abs(r[3]-abs(r[1]-r[2]))<=1e-15
  assert abs(r[1]-r[2])<=1e-4,'unchanged assembled source factor bound'
 return max(r[3] for r in values)
def replay(frames,opt,out,fc):
 out.mkdir(exist_ok=True);m=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(m['gzip_base64']));assert sha(literal)==m['sha256']
 (out/'oxygenstress.f90').write_bytes(literal)
 inputs=[ROOT/'tests/dataqual15_hupsel/matched_oxygen_owners.f90',out/'oxygenstress.f90',ROOT/'tests/dataqual15_hupsel/matched_oxygen_driver.f90']
 exe=out/'oracle.exe';cmd=[str(fc),'-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-J'+str(out),'-I'+str(out),*map(str,inputs),'-o',str(exe)]
 p=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180);(out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 record=dict(command=cmd,compiler=subprocess.check_output([str(fc),'--version'],text=True).splitlines()[0],source_sha256=m['sha256'],executable_sha256=sha(exe.read_bytes()),runs=[])
 worst=0
 for i,f in enumerate(frames):
  payload='\n'.join(' '.join(f'{x:.17e}' for x in row) for row in f)+'\n';(out/f'{i}.input').write_text(payload,encoding='utf-8',newline='\n')
  p=subprocess.run([str(exe)],input=payload.encode(),cwd=out,capture_output=True,timeout=60)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr);assert p.returncode==0,(p.stdout,p.stderr)
  worst=max(worst,output(p.stdout,f));record['runs'].append(dict(profile=i,returncode=p.returncode,input_sha256=sha(payload.encode()),output_sha256=sha(p.stdout)))
 record['maximum_factor_difference']=worst;(out/'REPLAY.json').write_text(json.dumps(record,indent=2)+'\n');return worst
def native(files,old,reg):
 report={};selections={}
 for opt in ('O0','O2'):
  f={n[len(opt)+1:]:b for n,b in files.items() if n.startswith(opt+'/')};build=json.loads(f['build/BUILD.json'])
  assert build['baseline']==json.loads(old[opt+'/build/BUILD.json'])['baseline']
  expected={MAIN:owner.instrument((ROOT/MAIN).read_text()),BACKEND:instrument((ROOT/BACKEND).read_text(),reg)}
  assert set(build['patches'])==set(expected)
  for name,text in expected.items():
   p=build['patches'][name];assert f['build/'+p['source']].decode()==text and sha(f['build/'+p['source']])==p['source_sha256'] and sha(f['build/'+p['object']])==p['object_sha256']
  assert sha(f['build/observed.exe'])==build['executable_sha256'] and sha(f['build/link.args'])==build['link_response_sha256']
  assert all(r['returncode']==0 for r in build['events'])
  for phase in ('whole','strict-own-537'):
   run=json.loads(f[phase+'/RESULT.json']);assert run['returncode']==0 and not run['from_start'] and run['executable_sha256']==build['executable_sha256']
   seed_sha=sha(f['whole/checkpoint-537.bin']) if phase!='whole' else json.loads(old[opt+'/whole/RESULT.json'])['restart_sha256']
   assert run['restart_sha256']==seed_sha
   assert run['inputs']==json.loads(old[opt+'/whole/RESULT.json'])['inputs']
   for n,h in run['inputs'].items():assert sha(f[phase+'/'+n])==h and f[phase+'/'+n]==old[opt+'/whole/'+n]
   assert run['scope']==('STRICT_SAME_BUILD_RESTART_MEASUREMENT' if phase!='whole' else 'INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION')
  assert f['whole/checkpoint.bin']==f['strict-own-537/checkpoint.bin']==old[opt+'/whole/checkpoint.bin']
  for n in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):assert f['whole/'+n]==old[opt+'/whole/'+n]
  for n,clock in [('budget.csv','t1_day'),('crop.csv','day')]:assert table(f['strict-own-537/'+n])==[r for r in table(f['whole/'+n]) if float(r[clock])>537]
  for n in ('root_accepted.dat','root_nodes.dat','oxygen_trials.dat'):assert f['strict-own-537/'+n].splitlines()==[r for r in f['whole/'+n].splitlines() if float(r.split()[0])>=537]
  raw=data(f['whole/oxygen_trials.dat'],41);nodes=data(f['whole/root_nodes.dat'],104);accepted=data(f['whole/root_accepted.dat'],9)
  selected=select(raw,nodes,accepted,reg);controls=[]
  for label in ('missing_frame','ambiguous_frame','wrong_head','wrong_receipt','nonfinite'):
   r,n,a=copy.deepcopy((raw,nodes,accepted))
   if label=='missing_frame':r=[v for v in r if v[:2]!=selected[0][0][:2]]
   elif label=='ambiguous_frame':
    extra=copy.deepcopy(selected[0]);extra[0][13]+=1;r.extend(extra)
   elif label=='wrong_head':
    for v in r:
     if v[:2]==selected[0][0][:2]:v[11]+=1e-3
   elif label=='wrong_receipt':a.remove(reg['selected_profiles'][0]['receipt'])
   else:
    for v in r:
     if v[:2]==selected[0][0][:2]:v[13]=float('nan')
   try:select(r,n,a,reg)
   except AssertionError:controls.append(label)
   else:raise AssertionError('accepted defect '+label)
  selections[opt]=selected;report[opt]=dict(selected_profiles=len(selected),rooted_node_comparisons=sum(int(f[0][10]) for f in selected),actual_rows=len(raw),rejected_controls=controls,frames=[dict(time=f[0][:2],rooted_nodes=int(f[0][10]),intermediate_loss=f[0][4],accepted_loss=next(a[4] for a in accepted if a[:2]==f[0][:2])) for f in selected])
 return report,selections
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/root_oxygen_evidence.py')],cwd=ROOT,check=True)
 r=json.loads((BASE/'ROOT_OXYGEN_EVIDENCE_20261104.json').read_text());old=unpack(BASE/'ROOT_OXYGEN_EVIDENCE_20261104.tar.xz',r['files_sha256'])
 reg=json.loads((BASE/'MATCHED_OXYGEN_PREREGISTRATION_20261104.json').read_text())
 if a.capture:files={f.relative_to(a.capture.resolve()).as_posix():f.read_bytes() for f in a.capture.resolve().rglob('*') if f.is_file() and f.suffix!='.mod'}
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text())
  assert record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==record['archive_sha256'];files=unpack(path,record['files_sha256'])
 result,selected=native(files,old,reg)
 if not a.capture:assert result==json.loads(files['AUDIT.json'])['native']
 with tempfile.TemporaryDirectory(prefix='swap5-matched-oxygen-') as temp:
  root=a.capture.resolve() if a.capture else Path(temp)
  maxima={opt:replay(selected[opt],opt,root/('literal-'+opt),a.compiler) for opt in ('O0','O2')}
  if a.capture:
   for f in root.glob('literal-*/*'):
    if f.is_file() and f.suffix!='.mod':files[f.relative_to(root).as_posix()]=f.read_bytes()
  else:
   for opt in ('O0','O2'):
    replay_record=json.loads(files['literal-'+opt+'/REPLAY.json']);assert sha(files['literal-'+opt+'/oracle.exe'])==replay_record['executable_sha256']
    carrier=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text())
    assert replay_record['source_sha256']==carrier['sha256']
    assert sha(files['literal-'+opt+'/oxygenstress.f90'])==replay_record['source_sha256']
    for i,f in enumerate(selected[opt]):
     output(files[f'literal-{opt}/{i}.stdout'],f)
     expected='\n'.join(' '.join(f'{x:.17e}' for x in row) for row in f)+'\n'
     assert files[f'literal-{opt}/{i}.input'].decode()==expected
     assert sha(files[f'literal-{opt}/{i}.input'])==replay_record['runs'][i]['input_sha256']
 # Refuse a falsified literal result independently of the Fortran process exit.
 f=selected['O0'][0];fake='\n'.join(f'{i+1} {row[18]+.001} {row[18]} .001' for i,row in enumerate(f[:int(f[0][10])])).encode()
 try:output(fake,f)
 except AssertionError:pass
 else:raise AssertionError('accepted falsified literal factor')
 if a.capture:
  files['AUDIT.json']=(json.dumps(dict(native=result,windows_maximum_factor_differences=maxima,whole_scientific_admission=False),indent=2)+'\n').encode();path=BASE/(STEM+'.tar.xz')
  with tarfile.open(path,'w:xz') as t:
   for n,b in sorted(files.items()):entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  deps=dict(r['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/matched_oxygen_observer.py','tests/dataqual15_hupsel/matched_oxygen_evidence.py','tests/dataqual15_hupsel/matched_oxygen_owners.f90','tests/dataqual15_hupsel/matched_oxygen_driver.f90','.github/workflows/hupsel-matched-oxygen.yml','integration/dataqual15_hupsel/MATCHED_OXYGEN_PREREGISTRATION_20261104.json','integration/dataqual15_hupsel/MATCHED_OXYGEN_STAGE_FINDING_20261104.json','integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json','tests/physics/test_bartholomeus_b111_assembled.f90','tests/physics/support/c3a_b111_oxygen_owners.f90'):deps[n]=norm(ROOT/n)
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(status='MATCHED_ACTUAL_ORIGINAL_OXYGEN_FACTOR_REPLAY_PASS',archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256=deps,whole_scientific_admission=False),indent=2)+'\n')
 print('MATCHED_ACTUAL_ORIGINAL_OXYGEN_FACTOR_REPLAY_PASS');print(json.dumps(dict(native=result,actual_current_factor_differences=maxima)))
if __name__=='__main__':main()
