"""Short original-source water orchestration and real coupled file restart."""
import argparse,csv,hashlib,json,re,shutil,struct,subprocess,sys,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--swp',type=Path,required=True);p.add_argument('--bundle-O0',type=Path,required=True);p.add_argument('--bundle-O2',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--reuse-completed',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=a.reuse_completed);events=json.loads((out/'events.json').read_text())if a.reuse_completed else[];cases={};bundles={}
def run(cmd,folder,label,success=True):
 previous=next((e for e in events if e['label']==label),None)
 if a.reuse_completed and previous is not None:
  assert previous['command']==list(map(str,cmd))and previous['expected_success']==success
  assert(previous['returncode']==0)==success
  return subprocess.CompletedProcess(cmd,previous['returncode'],(out/(label+'.stdout')).read_bytes(),(out/(label+'.stderr')).read_bytes())
 t=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True,timeout=90)
 (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
 events.append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=cp.returncode,expected_success=success))
 (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert (cp.returncode==0)==success,(label,cp.stdout[-1000:],cp.stderr[-1800:])
 return cp
# Exact source event endpoints, read from the already prepared immutable plan.
# The first high-intensity pond/head interval ends at rain event4.
target=1.0539999999964493;split_event=.8664999999964493
for opt in ['O0','O2']:
 bundle=getattr(a,'bundle_'+opt).resolve();b=json.loads((bundle/'bundle.json').read_bytes());bundles[opt]=b
 for exe,h in b['executable_sha256'].items():assert sha(Path(exe).read_bytes())==h
 for name,day,stop,restart in [('continuous',2,target,None),('day-prefix',1,None,None),('day-resumed',2,target,'day-prefix'),('event-prefix',1,split_event,None),('event-resumed',2,target,'event-prefix')]:
  label=opt+'-'+name;folder=out/label
  cmd=[sys.executable,'-B',ROOT/'tools/solute/run_native_water.py',a.swp.resolve(),'--bundle',bundle,'--output',folder,'--stop-after',day,'--timeout-seconds',60]
  if stop is not None:cmd+=['--stop-at-time',repr(stop)]
  if restart:cmd+=['--restart',out/(opt+'-'+restart)/'restart.bin']
  run(cmd,ROOT,label)
  m=json.loads((folder/'manifest.json').read_bytes());assert m['status']=='COMPLETE'and all(e['returncode']==0 and not e['censored']for e in m['events'])
  assert m['compiler_and_source_bundle']==b
  for file,h in m['files'].items():assert sha((folder/file).read_bytes())==h
  assert b'NATIVE_SWSOLU0_MACRO_RUTTER_HEAT_PROJECT_PASS'in(folder/'native.stdout').read_bytes()
  rows=list(csv.DictReader((folder/'budget.csv').open()));progress=list(csv.DictReader((folder/'progress.csv').open()))
  assert rows and progress and float(progress[-1]['t1'])==(float(day)if stop is None else stop)
  assert all(float(x[k])<1e-10 for x in rows for k in ['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm'])
  assert all(abs(float(x['water_residual_cm']))<1e-10 for x in rows)
  assert all(int(x['mass_rejections'])==0 for x in progress)
  cases[label]=dict(rows=rows,progress=progress,manifest_sha256=sha((folder/'manifest.json').read_bytes()))
 full=out/(opt+'-continuous')
 for resumed in ['day-resumed','event-resumed']:
  for f in ['state.csv','temperature.csv','restart.bin']:
   assert(full/f).read_bytes()==(out/(opt+'-'+resumed)/f).read_bytes(),(opt,resumed,f)
 assert cases[opt+'-continuous']['rows'][-1]==cases[opt+'-day-resumed']['rows'][-1]
 assert sum(float(x['direct_macro_cm'])for x in cases[opt+'-continuous']['rows'])>0,'source direct macro input not exercised'
 source=(out/(opt+'-day-prefix')/'restart.bin').read_bytes();manifest=json.loads((full/'manifest.json').read_bytes());binding=manifest['binding_sha256'];exe=b['exe']
 def crc(raw):return raw[:-4]+struct.pack('=I',zlib.crc32(raw[:-4]))
 def replace(raw,at,payload):return crc(raw[:at]+payload+raw[at+len(payload):])
 n=struct.unpack_from('=i',source,72)[0];assert n==112
 heads=list(csv.DictReader((out/(opt+'-day-prefix')/'state.csv').open()));head_offset=source.find(struct.pack('=d',float(heads[0]['head_cm'])),92);assert head_offset>92
 clock=source.find(struct.pack('=d',1.),92,head_offset);assert clock>=92
 controls=[('crc',source[:150]+bytes([source[150]^1])+source[151:]),('truncated',source[:-7]),('dimension',replace(source,72,struct.pack('=i',113))),('nan-head',replace(source,head_offset,struct.pack('=d',float('nan')))),('negative-pond',replace(source,head_offset+16*n,struct.pack('=d',-1.))),('clock',replace(source,clock,struct.pack('=d',2.))),('foreign-binding',source)]
 for name,raw in controls:
  label=opt+'-bad-'+name;folder=out/label;folder.mkdir(exist_ok=a.reuse_completed)
  for f in ['input.nml','input.swp','input.bbc','input.dra','macro.nml']:shutil.copyfile(full/f,folder/f)
  (folder/'bad.bin').write_bytes(raw);used_binding=('f'*64 if binding!='f'*64 else'e'*64)if name=='foreign-binding'else binding
  cp=run([exe,'input.nml','bad.bin',2,'input.swp','macro.nml',used_binding,repr(target)],folder,label,False)
  assert b'native macro water restart rejected'in cp.stdout,(label,cp.stdout[-500:])
  assert not any((folder/f).exists()for f in ['budget.csv','progress.csv','restart.bin','state.csv','temperature.csv'])
  assert(out/(opt+'-day-prefix')/'restart.bin').read_bytes()==source
for f in ['state.csv','temperature.csv','budget.csv','progress.csv','native.stdout','macro.nml']:
 assert(out/'O0-continuous'/f).read_bytes()==(out/'O2-continuous'/f).read_bytes(),('cross optimization',f)
def physical_input(opt):
 raw=(out/(opt+'-continuous')/'input.nml').read_text()
 pattern=r'^! (project_reader|crop_reader|root_reader|exe)_executable_sha256=([a-f0-9]{64})$'
 matches=re.findall(pattern,raw,re.M);assert len(matches)==4
 b=bundles[opt]
 for key,h in matches:assert b['executable_sha256'][b[key]]==h
 return re.sub(pattern,'',raw,flags=re.M)
assert physical_input('O0')==physical_input('O2')
assert(out/'O0-continuous/restart.bin').read_bytes()[72:-4]==(out/'O2-continuous/restart.bin').read_bytes()[72:-4]
inputs={p:sha((ROOT/p).read_bytes())for p in ['tests/nut-sol/qualify_native_macro_water.py','tools/solute/run_native_water.py','tools/solute/run_project.py']}
for b in bundles.values():
 for e in ['exe','project_reader','root_reader','crop_reader','macro_reader']:
  m=json.loads((Path(b[e]).parent/'build-complete.json').read_bytes());inputs.update(m['input_sha256'])
r=dict(status='ORIGINAL112_FIVE_DOMAIN_NATIVE_WATER_SHORT_O0_O2_RESTART_PASS',tested_end_day=target,source_event_split_day=split_event,original_source_unmodified=True,checked_optimizations=['O0','O2'],native_runs=10,fresh_process_restarts=4,file_negative_controls=14,endpoint_files_exact=12,physical_restart_payload_O0_O2_exact=True,full481=False,seasonal=False,qualified=False,canonically_admitted=False,validation_reused_completed_native_runs=a.reuse_completed,events=events,cases=cases,input_sha256=inputs)
(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
