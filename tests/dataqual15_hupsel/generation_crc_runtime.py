import argparse,hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
import crc_family_runtime as primitive
import native_n_crc_runtime as build_support
ROOT=Path(__file__).resolve().parents[2]
BASE='f12ae68d123ff374cc22ac56e378f6b974640312'
REGISTER='integration/dataqual15_hupsel/GENERATION_CRC_PREREGISTRATION_20261105.json'
SOURCES={n:'src/adapter/mod_crop_n_'+n+'_generation.f90'for n in ('output','saved')}
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def postimage(text):
 old=primitive.procedure(text,'function','crc32');assert text.count(old)==1
 anchor=' use iso_fortran_env,only:real64,int64,int32,int8\n';assert text.count(anchor)==1
 return text.replace(old,'',1).replace(anchor,anchor+' use mod_age_joint_restart_file,only:crc32\n',1)
def guard():
 r=json.loads((ROOT/REGISTER).read_text());assert r['baseline']==BASE and r['production_delta']==[]
 for a in ('src','app','reference'):
  assert git('rev-parse','HEAD:'+a)==git('rev-parse',BASE+':'+a)
  assert not git('diff','HEAD','--',a)and not git('ls-files','--others','--exclude-standard','--',a)
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h,p
 return r
def compile_local(out,compiler,opt):
 out.mkdir(parents=True);fixture=out/'fixture';fixture.mkdir();grid=fixture/'grid.f90';grid.write_text((ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text())
 mapping={}
 for p in [*sorted((ROOT/'src').rglob('*.f90')),grid]:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  assert p not in active;active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   if name.lower()in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
   assert name.lower()in mapping,(p,name)
   if mapping[name.lower()]!=p:visit(mapping[name.lower()])
  active.remove(p);seen.add(p);ordered.append(p)
 visit(ROOT/'src/adapter/mod_age_joint_restart_file.f90')
 for p in SOURCES.values():visit(ROOT/p)
 build_support.SOURCES=SOURCES;build_support.candidate=postimage
 for role in ('incumbent','candidate'):
  build_support.build(out/role,compiler,opt,fixture,ordered,{},out/'incumbent'if role=='candidate'else None)
 (out/'RESULT.json').write_text(json.dumps(dict(status='COMPLETE_GENERATION_MODULE_COHERENT_COMPILATION_ONLY',optimization=opt,providers=len(ordered),native_publication_executed=False,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
 print('Complete modules compile; native POSIX publication remains a separate gate',opt,len(ordered))
def execute_posix(out):
 assert os.name=='posix','Actual POSIX fsync/rename/SIGKILL contract required, no Windows shim'
 out.mkdir(parents=True);events=[];reports={}
 def run(command,view,label):
  started=time.monotonic();p=subprocess.run(list(map(str,command)),cwd=view,capture_output=True,timeout=1200);stem=str(len(events))+'-'+label
  for stream in ('stdout','stderr'):(out/(stem+'.'+stream)).write_bytes(getattr(p,stream))
  events.append(dict(label=label,command=list(map(str,command)),returncode=p.returncode,seconds=time.monotonic()-started,stdout=stem+'.stdout',stderr=stem+'.stderr'))
  (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,(label,p.stdout[-2000:],p.stderr[-4000:])
 for role in ('incumbent','candidate'):
  target=out/role;target.mkdir();view=target/'tree';subprocess.run(['git','worktree','add','--detach',str(view),BASE],cwd=ROOT,check=True,capture_output=True)
  try:
   sources={}
   for name,path in SOURCES.items():
    text=(ROOT/path).read_text();data=postimage(text)if role=='candidate'else text
    if role=='candidate':(view/path).write_text(data)
    sources[path]=sha(data.encode());(target/(name+'.f90')).write_text(data)
   assert set(subprocess.check_output(['git','diff','--name-only'],cwd=view,text=True).splitlines())==(set(SOURCES.values())if role=='candidate'else set())
   steps=[('accepted','run_accepted_output.py',[]),('csv','run_accepted_output_csv.py',['--physical',target/'accepted']),('joint','run_joint_output_generation.py',['--physical',target/'accepted','--csv',target/'csv']),('cold','run_native_output_project.py',[]),('saved','run_saved_output.py',['--cold',target/'cold'])]
   results={}
   for name,script,args in steps:
    run([sys.executable,'-B',view/'tests/nut-output'/script,*args,'--output',target/name],view,role+'-'+name)
    results[name]=json.loads((target/name/'result.json').read_text())
   reports[role]=dict(sources=sources,results=results)
  finally:
   # Only this deliberately isolated private proof view can be dirty.
   assert view.parent==target and view.name=='tree'
   subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,check=True,capture_output=True)
  (out/'RESULT.json').write_text(json.dumps(dict(status='IN_PROGRESS',roles=reports,production_source_changed=False,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
 # Every original recipe's physical/fresh/corrupt/kill assertion ran unchanged.
 for step in ('accepted','csv','joint','cold','saved'):
  assert reports['incumbent']['results'][step]['results']==reports['candidate']['results'][step]['results'],step
 (out/'RESULT.json').write_text(json.dumps(dict(status='COMPLETE_GENERATION_POSIX_O0_O2_NATIVE_FULL_POSTIMAGE_PASS',roles=reports,events=events,production_source_changed=False,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('COMPLETE_GENERATION_POSIX_O0_O2_NATIVE_FULL_POSTIMAGE_PASS')
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path);p.add_argument('--optimization',choices=('O0','O2'));p.add_argument('--posix',action='store_true');a=p.parse_args();guard();os.environ['OMP_NUM_THREADS']='1'
 if a.posix:execute_posix(a.output.resolve())
 else:assert a.compiler and a.optimization;compile_local(a.output.resolve(),a.compiler.resolve(),a.optimization)
 guard()
if __name__=='__main__':main()
