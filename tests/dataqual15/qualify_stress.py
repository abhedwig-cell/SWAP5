"""Paired real oxygen owners and source-input timestep refinement; no production edits.

The generated applications differ only in output diagnostics and an explicit
DTMAX cap. Every trajectory starts on day1. Diagnostic binaries/checkpoints
have their own bindings and are never substituted into the qualified capsule.
"""
import argparse,csv,hashlib,io,json,re,subprocess,sys,tarfile,time
from pathlib import Path
from original_sources import build_original
from checkpoint_layout import payload
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True)
 p.add_argument('--paired-only',action='store_true');p.add_argument('--observations',type=Path);a=p.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve());events=[]
 report=dict(status='IN_PROGRESS',scope='PAIRED_OXYGEN_COMPONENT_AND_NUMERICAL_REFINEMENT_NOT_SCIENTIFIC_EQUIVALENCE',scientific_equivalence=False,events=events)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(command,label,cwd=out,timeout=240):
  start=time.monotonic();r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=timeout)
  index=len(events);(out/f'{index}.stdout').write_bytes(r.stdout);(out/f'{index}.stderr').write_bytes(r.stderr)
  events.append(dict(label=label,command=list(map(str,command)),returncode=r.returncode,seconds=time.monotonic()-start));save()
  assert r.returncode==0,(label,r.stderr.decode(errors='replace')[-3000:],r.stdout.decode(errors='replace')[-1000:])
  return r.stdout
 originals={}
 for opt in ['O0','O2']:originals[opt]=build_original(out/('original-'+opt),fc,opt)
 observations=a.observations.resolve()if a.observations else None
 if not a.paired_only:
  source=ROOT/'app/grass_project/initial_interval.f90';original=source.read_text();snippet=ROOT/'tests/dataqual15/stress_observations.inc'
  assert original.count('  call prepare_source_day(day_index)')==1 and original.count('\ncontains\n')==1
  observed=original.replace('  call prepare_source_day(day_index)','  call prepare_source_day(day_index)\n  call write_stress_observation(day_index)')
  observed=observed.replace('\ncontains\n','\ncontains\n'+snippet.read_text()+'\n')
  trace="     step_dt=q%t1-q%t0"
  assert observed.count(trace)==1
  observed=observed.replace(trace,trace+"\n     if(any(day_index==[25,72,73,127]))write(*,*)'STRESS_ACCEPTED',day_index,q%t0,q%t1, &\n       q%root_potential_cm_day,sum(q%root_sink),q%deepest_root_oxygen_factor")
  builds={};trajectories={};horizons=[('coarse',None),('half',.02),('quarter',.01)]
  for name,cap in horizons:
   folder=out/name;folder.mkdir();driver=folder/'observed_grass.f90';text=observed
   if cap:
    needle="call rdsdor('dtmax',1d-7,1d0,source_dtmax)";assert text.count(needle)==1
    text=text.replace(needle,needle+f';source_dtmax=min(source_dtmax,{cap}d0)')
   driver.write_text(text,newline='\n');build=folder/'build';case=folder/'native'
   command=[sys.executable,'-B',ROOT/'tools/solute/build_grass_startup.py','--compiler',fc,'--input-archive',originals['O2']/'ttobj/libttutil.a','--output',build,'--optimization','O2','--profile','checked','--driver',driver,'--end','1','--policy','retained']
   if builds:command+=['--reuse-build',builds['coarse']]
   run(command,'build-'+name,timeout=600);builds[name]=build
   run([sys.executable,'-B',ROOT/'tests/dataqual15/run_original.py','--bundle',build,'--output',case,'--end','140','--capture','24','25','71','72','73','126','127','140','--timeout','2400'],'trajectory-'+name,timeout=2430)
   terminal=json.loads((case/'RESULT.json').read_text());assert terminal['returncode']==0 and terminal['completed_days']==140 and not terminal['censored']
   trajectories[name]=case
  observations=trajectories['coarse']
  with tarfile.open(ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz','r:xz')as archive:
   spec=json.load(archive.extractfile('SPEC.json'));prefix=spec['full']
   rows=lambda raw:list(csv.DictReader(io.StringIO(raw.decode())))
   for name in ['budget.csv','crop.csv']:
    assert rows((observations/name).read_bytes())==rows(archive.extractfile(prefix+'/'+name).read())[:140],('read-only diagnostic trajectory changed',name)
   assert payload((observations/'checkpoint.bin').read_bytes())==payload(archive.extractfile(prefix+'/checkpoint-140.bin').read())
   reference=list(csv.DictReader(line for line in archive.extractfile(spec['reference_B0']+'/result_output.csv').read().decode().splitlines()if line.strip()and not line.startswith('*')))
  getrows=lambda path:list(csv.DictReader(path.open()))
  report['refinement']={}
  for name,case in trajectories.items():
   budget=getrows(case/'budget.csv');crop=getrows(case/'crop.csv')
   report['refinement'][name]=dict(end_day=140,maximum_water_residual_cm=max(abs(float(row['residual_cm']))for row in budget),selected_days={str(day):dict(native=budget[day-1],crop=crop[day-1],source={key:reference[day][key]for key in ['TPOT','TACT','TREDWET','TREDDRY','WRT','WLV','HRVDM']})for day in [25,72,73,126,127,140]})
  report['coarse_output_only_trajectory_exact']=True
 assert observations is not None
 # Production oxygen closure linked to the unmodified original B1.11 model
 # routines; original MOD_grid, watcon and OxygenStress are real providers.
 driver=ROOT/'tests/dataqual15/stress_oracle.f90';mapping={}
 for path in (ROOT/'src').rglob('*.f90'):
  for module in re.findall(r'^\s*module\s+(\w+)\s*$',path.read_text(),re.M|re.I):mapping[module.lower()]=path
 ordered=[];seen=set()
 def visit(path):
  if path in seen:return
  seen.add(path)
  for module in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',path.read_text(),re.M|re.I):
   if module.lower()in mapping and mapping[module.lower()]!=path:visit(mapping[module.lower()])
  ordered.append(path)
 visit(driver);ordered.remove(driver);report['source_sha256']={str(path.relative_to(ROOT)):sha(path)for path in ordered+[driver,ROOT/'tests/dataqual15/stress_observations.inc']}
 report['paired']={}
 for opt in ['O0','O2']:
  folder=out/opt;folder.mkdir();ref=originals[opt];flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(folder),'-J'+str(folder),'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj')];objects=[]
  for i,path in enumerate(ordered):
   obj=folder/f'{i}.o';run([fc,*flags,'-c',path,'-o',obj],'paired-compile');objects.append(obj)
  exe=folder/'paired';args=folder/'link.args';args.write_text('\n'.join('"'+str(arg).replace('\\','/')+'"'for arg in [*flags,driver,*objects,*sorted((ref/'swobj').glob('*.o')),ref/'ttobj/libttutil.a','-o',exe]),newline='\n');run([fc,'@'+str(args)],'paired-link')
  report['paired'][opt]={}
  for day in [25,72,73,127]:
   path=observations/f'stress-input-{day}.dat';stdout=run([exe,path],f'paired-{opt}-{day}');(folder/f'day-{day}.stdout').write_bytes(stdout)
   lines=stdout.decode().splitlines();maximum=next(float(line.split()[-1])for line in lines if line.startswith('PAIRED_MAX_FACTOR_DIFFERENCE'))
   report['paired'][opt][str(day)]=dict(maximum_factor_difference=maximum,observation_sha256=sha(path),stdout_sha256=hashlib.sha256(stdout).hexdigest())
 assert all(sha(ROOT/path)==digest for path,digest in report['source_sha256'].items())
 report['status']='PAIRED_OXYGEN_AND_REFINEMENT_MEASURED';report['limitations']=['Daily left states, not the complete accepted-substep temperature trajectory','Paired oxygen component does not yet certify the entire original uptake composition','No harvest-equivalence limit is inferred from the existing 1e-4 oxygen component gate'];save()
 print(json.dumps({key:value for key,value in report.items()if key not in ['events','source_sha256','refinement']},indent=2))

if __name__=='__main__':main()
