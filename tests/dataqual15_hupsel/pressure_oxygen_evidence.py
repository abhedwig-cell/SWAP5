"""Actual accepted pressure-variant oxygen carriers and original process replays."""
import argparse,copy,hashlib,io,json,math,os,subprocess,sys,tarfile,tempfile
from pathlib import Path
from full_profile_evidence import unpack
from root_oxygen_evidence import data,table,audit as root_audit
from matched_oxygen_evidence import select as factor_select,replay as factor_replay,output as factor_output
from matched_micro_replay import source as literal_source
import pressure_oxygen_observer as owner
ROOT=owner.ROOT;BASE=owner.BASE;STEM='PRESSURE_OXYGEN_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))

def final_select(raw,nodes,accepted,reg):
 assert len(raw)%34==0
 frames=[raw[i:i+34] for i in range(0,len(raw),34)];result=[]
 for entry in reg['selected_profiles']:
  receipt=entry['receipt'];assert receipt in accepted
  node=next(n for n in nodes if n[:2]==receipt[:2]);matches=[]
  for f in frames:
   if f[0][:9]!=receipt:continue
   assert all(r[:9]==receipt and len(r)==40 and all(map(math.isfinite,r)) for r in f)
   assert [int(r[9]) for r in f]==list(range(1,35))
   assert [r[31] for r in f]==node[2:36] and [r[32] for r in f]==node[36:70]
   assert [r[39] for r in f]==node[70:104]
   assert all(r[10:31]==f[0][10:31] for r in f)
   n=int(f[0][10]);assert 1<=n<=34
   assert abs(math.fsum(r[39] for r in f)-receipt[6])<=1e-12
   assert all(0<=r[35]<=1 and 0<=r[36]<=1 and 0<=r[37]<=1 for r in f)
   matches.append(tuple(tuple(r) for r in f))
  assert matches and len(set(matches))==1,'missing/ambiguous final MICRO carrier'
  result.append([list(r) for r in matches[0]])
 return result

def partition_output(raw,frame):
 lines=raw.decode().splitlines();assert len(lines)==1 and lines[0].startswith('ATTR ')
 values=list(map(float,lines[0].split()[1:]));assert len(values)==4 and all(map(math.isfinite,values))
 expected=[frame[0][3],frame[0][4],frame[0][5],frame[0][27]]
 error=max(abs(x-y) for x,y in zip(values,expected));assert error<=1e-14
 return error

def partition_replay(frames,opt,out,fc):
 out.mkdir();source,metadata=literal_source();(out/'literal.f90').write_text(source,encoding='utf-8',newline='\n')
 exe=out/'partition.exe';cmd=[str(fc),'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(out),'-I'+str(out),str(out/'literal.f90'),str(ROOT/'tests/dataqual15_hupsel/pressure_oxygen_partition_driver.f90'),'-o',str(exe)]
 p=subprocess.run(cmd,capture_output=True,cwd=out,timeout=180);(out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 runs=[]
 for i,f in enumerate(frames):
  payload=('\n'.join(' '.join(f'{x:.17e}' for x in r) for r in f)+'\n').encode();(out/f'{i}.input').write_bytes(payload)
  p=subprocess.run([str(exe)],input=payload,capture_output=True,cwd=out,timeout=60)
  (out/f'{i}.stdout').write_bytes(p.stdout);(out/f'{i}.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
  runs.append(dict(input_sha256=sha(payload),output_sha256=sha(p.stdout),error=partition_output(p.stdout,f)))
 record=dict(command=cmd,metadata=metadata,source_sha256=sha(source.encode()),executable_sha256=sha(exe.read_bytes()),runs=runs)
 (out/'REPLAY.json').write_text(json.dumps(record,indent=2)+'\n');return max(r['error'] for r in runs)

def native(files,parent,manifest):
 reports={};selected={}
 for opt in ('O0','O2'):
  f={n[len(opt)+1:]:b for n,b in files.items() if n.startswith(opt+'/')};reg=json.loads(f['SELECTED.json'])
  complete=json.loads(f['COMPLETE.json']);assert complete['actual_observation'] and complete['exact_unobserved'] and complete['own_strict_537']
  trace=data(f['whole/root_accepted.dat'],9);nodes=data(f['whole/root_nodes.dat'],104)
  assert reg==owner.selected(trace)
  original_build=json.loads(parent['build-'+opt+'/BUILD.json'])
  for name in ('root-build','forcing-build'):
   b=json.loads(f[name+'/BUILD.json']);assert b['baseline']==original_build
   expected={owner.MAIN:owner.root.instrument((ROOT/owner.MAIN).read_text())}
   if name=='forcing-build':expected[owner.BACKEND]=owner.backend((ROOT/owner.BACKEND).read_text(),reg)
   assert set(b['patches'])==set(expected)
   for path,text in expected.items():
    patch=b['patches'][path];raw=f[name+'/'+patch['source']]
    assert raw.decode()==text and sha(raw)==patch['source_sha256']
    assert sha(f[name+'/'+patch['object']])==patch['object_sha256']
   assert len(b['events'])==len(expected)+1 and all(e['returncode']==0 for e in b['events'])
   assert sha(f[name+'/observed.exe'])==b['executable_sha256']
   assert sha(f[name+'/link.args'])==b['link_response_sha256']
   assert len(b['link_arguments'])==242
   assert f[name+'/link.args'].decode()=='\n'.join('"'+s.replace('\\','/')+'"' for s in b['link_arguments'])+'\n'
   for patch in b['patches'].values():
    command=next(e['command'] for e in b['events'] if '-c' in e['command'] and e['command'][e['command'].index('-c')+1].replace('\\','/').endswith('/'+patch['source']))
    flags=command[1:command.index('-c')]
    assert [x for x in flags if not x.startswith(('-I','-J'))]==[x for x in original_build['baseline']['flags'] if not x.startswith(('-I','-J'))]
   for i,arg in enumerate(b['link_arguments'][2:238]):
    if str(i)+'.o' not in {p['object'] for p in b['patches'].values()}:
     assert arg.replace('\\','/').endswith('/build-'+opt+'/'+str(i)+'.o')
     assert sha(parent['build-'+opt+'/'+str(i)+'.o'])==original_build['compiled_objects_sha256'][str(i)+'.o']
  for phase in ('unobserved','root-whole','root-strict-537','whole','strict-own-537'):
   run=json.loads(f[phase+'/RESULT.json']);assert run['returncode']==0 and not run['from_start']
   seed=parent['full-O2/checkpoint-524.bin']
   if phase=='root-strict-537':seed=f['root-whole/checkpoint-537.bin']
   if phase=='strict-own-537':seed=f['whole/checkpoint-537.bin']
   assert run['restart_sha256']==sha(seed)
   expected_exe=original_build['executable_sha256'] if phase=='unobserved' else json.loads(f[('root-build' if phase.startswith('root-') else 'forcing-build')+'/BUILD.json'])['executable_sha256']
   assert run['executable_sha256']==expected_exe
   assert run['inputs']==json.loads(parent['full-O2/RESULT.json'])['inputs']
   for n,pin in run['inputs'].items():assert sha(f[phase+'/'+n])==pin and f[phase+'/'+n]==parent['full-O2/'+n]
   strict=phase in ('root-strict-537','strict-own-537') or (phase=='unobserved' and opt=='O2')
   assert run['scope']==('STRICT_SAME_BUILD_RESTART_MEASUREMENT' if strict else 'INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION')
   assert f[phase+'/checkpoint.bin']==f['unobserved/checkpoint.bin']
  for whole,tail in [('root-whole','root-strict-537'),('whole','strict-own-537')]:
   for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
    assert f[whole+'/'+name]==f['unobserved/'+name]
    assert table(f[tail+'/'+name])==[r for r in table(f[whole+'/'+name]) if float(r[clock])>537]
   for name in ('root_accepted.dat','root_nodes.dat'):
    assert f[tail+'/'+name].splitlines()==[r for r in f[whole+'/'+name].splitlines() if float(r.split()[0])>=537]
  for name in ('budget.csv','crop.csv','root_accepted.dat','root_nodes.dat'):assert f['whole/'+name]==f['root-whole/'+name]
  for name in ('micro_trials.dat','oxygen_trials.dat'):
   assert f['strict-own-537/'+name].splitlines()==[r for r in f['whole/'+name].splitlines() if float(r.split()[0])>=537]
  if opt=='O2':
   assert f['whole/checkpoint.bin']==parent['full-O2/checkpoint-584.bin']
   assert table(f['whole/budget.csv'])==[r for r in table(parent['full-O2/budget.csv']) if 524<float(r['t1_day'])<=584]
   original=[r for r in table(parent['full-O2/crop.csv']) if 524<float(r['day'])<=584]
   diffs=[dict(day=x['day'],fields={k:dict(restarted=x[k],full=y[k]) for k in x if x[k]!=y[k]}) for x,y in zip(table(f['whole/crop.csv']),original)]
   assert len(diffs)==60 and all(set(x['fields'])=={'pressure_average_cm'} for x in diffs)
   assert all(float(x['fields']['pressure_average_cm']['restarted'])==0 and float(x['fields']['pressure_average_cm']['full'])!=0 for x in diffs)
   assert diffs==json.loads(f['RETAINED_DIAGNOSTIC_FAILURE.json'])
  budget=table(f['whole/budget.csv']);report=root_audit(trace,nodes,budget);controls=[]
  for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
   residuals=[float(r[prefix+'_end_'+unit])-float(r[prefix+'_start_'+unit])-float(r[prefix+'_in_'+unit])+float(r[prefix+'_out_'+unit]) for r in budget]
   assert max(map(abs,residuals))<=1e-10 and abs(math.fsum(residuals))<=1e-8
  def refuse(label,fn):
   try:fn()
   except (AssertionError,StopIteration):controls.append(label)
   else:raise AssertionError('accepted pressure oxygen defect '+label)
  for label in ('missing_leaf','oxygen_rate','node_sink','daily_budget'):
   t,n,b=copy.deepcopy((trace,nodes,budget))
   if label=='missing_leaf':t.pop(0)
   elif label=='oxygen_rate':t[0][4]+=1e-6
   elif label=='node_sink':n[0][70]+=1e-6
   else:b[0]['oxygen_reduction_cm']=str(float(b[0]['oxygen_reduction_cm'])+1e-6)
   refuse(label,lambda:root_audit(t,n,b))
  raw=data(f['whole/oxygen_trials.dat'],41);micro=data(f['whole/micro_trials.dat'],40)
  factors=factor_select(raw,nodes,trace,reg);finals=final_select(micro,nodes,trace,reg)
  for label in ('missing_factor','ambiguous_factor','wrong_head','missing_receipt'):
   r,n,a=copy.deepcopy((raw,nodes,trace))
   if label=='missing_factor':r=[x for x in r if x[:2]!=factors[0][0][:2]]
   elif label=='ambiguous_factor':
    extra=copy.deepcopy(factors[0]);extra[0][13]+=1;r+=extra
   elif label=='wrong_head':
    for x in r:
     if x[:2]==factors[0][0][:2]:x[11]+=1e-3
   else:a.remove(reg['selected_profiles'][0]['receipt'])
   refuse(label,lambda:factor_select(r,n,a,reg))
  altered=copy.deepcopy(micro)
  for x in altered:
   if x[:2]==finals[0][0][:2]:x[39]+=1e-6
  refuse('wrong_final_sink',lambda:final_select(altered,nodes,trace,reg))
  altered=copy.deepcopy(finals[0]);altered[0][4]+=1e-6
  raw_output=('ATTR '+' '.join(str(finals[0][0][i]) for i in (3,4,5,27))+'\n').encode()
  refuse('falsified_partition_output',lambda:partition_output(raw_output,altered))
  report.update(profiles=len(factors),rooted_node_comparisons=sum(int(x[0][10]) for x in factors),rejected_controls=controls,
                retained_full_crop_diagnostic_failure=(opt=='O2'),frames=[dict(time=x[0][:2],intermediate_factor_loss=x[0][4],accepted_micro_loss=y[0][4],maximum_drought_mode=int(y[0][11])) for x,y in zip(factors,finals)])
  reports[opt]=report;selected[opt]=(factors,finals)
 return reports,selected

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 manifest=json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text());path=BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.tar.xz'
 assert sha(path.read_bytes())==manifest['archive_sha256'];parent=unpack(path,manifest['files_sha256'])
 for n,h in manifest['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
 if a.capture:files={f.relative_to(a.capture.resolve()).as_posix():f.read_bytes() for f in a.capture.resolve().rglob('*') if f.is_file() and f.suffix not in ('.mod','.smod')}
 else:
  m=json.loads((BASE/(STEM+'.json')).read_text())
  for n,h in m['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==m['archive_sha256'];files=unpack(path,m['files_sha256'])
 reports,selections=native(files,parent,manifest)
 maxima={}
 with tempfile.TemporaryDirectory(prefix='swap5-pressure-oxygen-') as temp:
  root=a.capture.resolve() if a.capture else Path(temp)
  for opt,(factors,finals) in selections.items():
   factor=factor_replay(factors,opt,root/('factor-'+opt),a.compiler)
   partition=partition_replay(finals,opt,root/('partition-'+opt),a.compiler)
   maxima[opt]=dict(maximum_original_factor_difference=factor,maximum_literal_partition_difference=partition)
   if not a.capture:
    for kind,frames in [('factor',factors),('partition',finals)]:
     directory=kind+'-'+opt;record=json.loads(files[directory+'/'+('REPLAY.json')]);exe='oracle.exe' if kind=='factor' else 'partition.exe'
     assert sha(files[directory+'/'+exe])==record['executable_sha256']
     if kind=='partition':assert files[directory+'/literal.f90'].decode()==literal_source()[0]
     else:
      carrier=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text())
      assert sha(files[directory+'/oxygenstress.f90'])==record['source_sha256']==carrier['sha256']
     for i,frame in enumerate(frames):
      expected=('\n'.join(' '.join(f'{v:.17e}' for v in row) for row in frame)+'\n').encode()
      assert files[f'{directory}/{i}.input']==expected
      (factor_output if kind=='factor' else partition_output)(files[f'{directory}/{i}.stdout'],frame)
  if a.capture:
   for folder in ('factor-O0','factor-O2','partition-O0','partition-O2'):
    for f in (root/folder).iterdir():
     if f.is_file() and f.suffix!='.mod':files[f.relative_to(root).as_posix()]=f.read_bytes()
 result=dict(status='SAME_PRESSURE_VARIANT_ACCEPTED_OXYGEN_AND_ORIGINAL_REPLAY_PASS',native=reports,
             original_replay_maxima=maxima,full_frozen_oxygen_comparison='REMAINS_FAILED day584; no changed bound or whole-trajectory correction',production_admission=False,whole_scientific_admission=False)
 if a.capture:
  files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode();path=BASE/(STEM+'.tar.xz')
  with tarfile.open(path,'w:xz') as t:
   for n,b in sorted(files.items()):
    entry=tarfile.TarInfo(n);entry.size=len(b);entry.mtime=0;t.addfile(entry,io.BytesIO(b))
  deps=dict(manifest['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/pressure_oxygen_observer.py','tests/dataqual15_hupsel/pressure_oxygen_evidence.py','tests/dataqual15_hupsel/pressure_oxygen_partition_driver.f90',
            'tests/dataqual15_hupsel/root_oxygen_observer.py','tests/dataqual15_hupsel/root_oxygen_evidence.py','tests/dataqual15_hupsel/matched_oxygen_observer.py','tests/dataqual15_hupsel/matched_micro_observer.py',
            'tests/dataqual15_hupsel/matched_oxygen_evidence.py','tests/dataqual15_hupsel/matched_micro_replay.py','tests/dataqual15_hupsel/matched_oxygen_owners.f90','tests/dataqual15_hupsel/matched_oxygen_driver.f90',
            'tests/physics/run_ppa_micro02_source_oracle.py','integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json',
            'integration/dataqual15_hupsel/MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json','integration/dataqual15_hupsel/MICRO_PRESSURE_RUNTIME_CANONICAL_RECEIPT_20261104.json',
            'integration/dataqual15_hupsel/PRESSURE_OXYGEN_PREREGISTRATION_20261104.json','.github/workflows/hupsel-pressure-oxygen.yml'):
   deps[n]=norm(ROOT/n)
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(status=result['status'],archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256=deps,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
 else:
  saved=json.loads(files['AUDIT.json']);assert result['native']==saved['native']
  # Fresh POSIX process values can differ at roundoff. Each is independently
  # checked against unchanged source bounds; never equate toolchains by fiat.
 print(result['status']);print(json.dumps(maxima))

if __name__=='__main__':main()
