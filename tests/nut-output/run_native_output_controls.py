"""Three compiled native controls: enabled path, default gate, atomic request."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
proof=a.proof.resolve();out=a.output.resolve();out.mkdir(exist_ok=False)
r=json.loads((proof/'result.json').read_text());assert r['status']=='NATIVE_OUTPUT_INPUT_O0_O2_PASS'
for p,h in r['input_sha256'].items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h,p
events=json.loads((proof/'events.json').read_text());cmd=next(e['command']for e in events if e['category']=='link'and e['command'][-1].endswith('O0/request'))
objects=[p for p in cmd if p.endswith('.o')];flags=cmd[1:cmd.index(objects[0])];source=ROOT/'src/process/mod_soil_n_historical_named_input.f90'
compile_event=next(e for e in events if e['category']=='compile'and str(source)in e['command']);old=compile_event['command'][-1]
s=source.read_text();mutants={
 'enabled_route_removed':(s.replace("if(trim(token)=='.true.')then","if(trim(token)=='.unsupported.')then",1),'true.snm',1,1),
 'default_true_gate_removed':(s.replace('       if(.not.present(extended_output))return','       ! mutation: accept without capture',1),'true.snm',-1,0),
 'request_reset_removed':((ROOT/'src/process/mod_soil_n_unified_input.f90').read_text().replace('if(present(extended_output))extended_output=.false.','! mutation: stale request retained'),'late_missing.snm',-1,1)}
results={};records=[];fc=os.environ.get('FC','gfortran')
for name,(text,fixture,expected,mode)in mutants.items():
 if name=='request_reset_removed':
  source=ROOT/'src/process/mod_soil_n_unified_input.f90'
  old=next(e['command'][-1]for e in events if e['category']=='compile'and str(source)in e['command'])
 assert text!=source.read_text()
 b=out/name;b.mkdir();path=b/'mutant.f90';path.write_text(text);obj=b/'mutant.o';exe=b/'test'
 f=[('-J'+str(b))if v.startswith('-J')else v for v in flags]+['-I'+str(proof/'O0')]
 for category,command in [('compile',[fc,*f,'-c',path,'-o',obj]),('link',[fc,*f,*[obj if v==old else v for v in objects],'-o',exe]),('native',[exe,proof/fixture,expected,mode])]:
  command=list(map(str,command));t=time.perf_counter();v=subprocess.run(command,cwd=b,capture_output=True);i=len(records)
  for key in ['stdout','stderr']:(out/f'{i:04d}.{key}').write_bytes(getattr(v,key))
  records.append(dict(command=command,category=category,returncode=v.returncode,seconds=time.perf_counter()-t,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
  (out/'events.json').write_text(json.dumps(records,indent=2)+'\n')
  if category!='native':assert v.returncode==0,v.stderr.decode()
  else:assert v.returncode!=0,'mutant escaped '+name
 results[name]=dict(compiled=True,assertions_rejected=True,returncode=v.returncode)
report=dict(status='NATIVE_OUTPUT_THREE_COMPILED_CONTROLS_PASS',controls=results,input_sha256={str(source.relative_to(ROOT)):hashlib.sha256(source.read_bytes()).hexdigest()},proof_sha256=hashlib.sha256((proof/'result.json').read_bytes()).hexdigest())
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
