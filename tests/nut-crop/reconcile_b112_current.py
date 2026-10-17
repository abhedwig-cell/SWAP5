"""Recompile changed provider closure, execute affected native gates on combined tree."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time
ROOT=Path(__file__).resolve().parents[2];a=argparse.ArgumentParser();a.add_argument('--providers',type=Path,required=True);a.add_argument('--output',type=Path,required=True);args=a.parse_args();BASE=args.providers.resolve();OUT=args.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();prior=json.loads((BASE/'result.json').read_text());old_events=json.loads((BASE/'events.json').read_text());assert prior['status']=='B112_RETAINED_JOINT_PHYSICAL_PASS_NOT_ADMITTED'
result=prior.copy();result['reconciliation']={'prior_result_sha256':sha(BASE/'result.json'),'prior_status':prior['status'],'reused_artifacts':{},'recompiled':[]};events=[]
source_map={}
for p in (ROOT/'src').rglob('*.f90'):
 for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):source_map[n.lower()]=p
intrinsic={'iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'}
def save():(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
def run(command,b,category):
 command=list(map(str,command));t=time.perf_counter();r=subprocess.run(command,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(category=category,command=command,returncode=r.returncode,seconds=time.perf_counter()-t,stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()));save()
 if r.returncode:raise RuntimeError('failed current event '+str(i)+' '+r.stdout.decode()+r.stderr.decode())
 return r.stdout
for opt in ['O0','O2']:
 b=OUT/opt;shutil.copytree(BASE/opt,b)
 ee=[e for e in old_events if any('/'+opt+'/'in x for x in e['command'])];ce=[e for e in ee if e['category']in ['compile','driver_compile']]
 paths={}
 def rewrite(x):
  for old in ['n-b112-retained-joint-01','n-b112-retained-joint-02']:
   x=x.replace(str(BASE.parent/old),str(OUT))
  return x
 providers=source_map.copy();info={}
 for e in ce:
  p=Path(e['command'][e['command'].index('-c')+1]);obj=b/Path(e['command'][-1]).name
  info[p]=(obj,[rewrite(x)for x in e['command']]);paths[p]=e
  for n in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[n.lower()]=p
 first=ce[0]['command'];fc=first[:first.index('-'+opt)];flags=[rewrite(x)for x in first[first.index('-'+opt):first.index('-c')]]
 done={};active=set();counter=0
 def visit(p):
  global counter
  if p in done:return done[p]
  assert p not in active,('cycle',p);active.add(p);dirty=False
  for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   n=n.lower()
   if n in intrinsic:continue
   q=providers[n]
   if q!=p:dirty=visit(q)or dirty
  if p in info:obj,command=info[p]
  else:
   obj=b/f'current-extra-{counter}.o';counter+=1;command=fc+flags+['-c',str(p),'-o',str(obj)];info[p]=(obj,command);dirty=True
  if p.is_relative_to(ROOT):
   rel=str(p.relative_to(ROOT));h=sha(p);dirty=prior['input_sha256'].get(rel)!=h or dirty;result['input_sha256'][rel]=h
  if dirty:
   run(command,b,'compile'if p in providers.values()else'driver_compile');result['reconciliation']['recompiled'].append(str(p))
  else:result['reconciliation']['reused_artifacts'][str(obj)]=sha(obj)
  active.remove(p);done[p]=dirty;return dirty
 for p in list(info):visit(p)
 extras=[v[0]for p,v in info.items()if p not in paths]
 for e in ee:
  if e['category']not in ['link','native']:continue
  command=[rewrite(x)for x in e['command']]
  if e['category']=='link':command=command[:-2]+list(map(str,extras))+command[-2:]
  run(command,b,e['category'])
 # Every accepted endpoint/restart remains byte exact, including all new profile stages.
 for p in (BASE/opt).glob('*.bin*'):
  if p.name.startswith(('b112-','b111-','reproductive-','test_crop_soil_joint-','test_reactive_joint-','test_mineral_joint-')) and 'invalid'not in p.name:
   assert (b/p.name).read_bytes()==p.read_bytes(),('combined native byte drift',p.name)
result['execution_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();result['source_tree']=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip();result['input_sha256'][str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__))
result['cost_seconds']={c:sum(e['seconds']for e in events if e['category']==c)for c in {e['category']for e in events}};(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print('B112_CURRENT_COMBINED_NATIVE=PASS',result['cost_seconds'])
