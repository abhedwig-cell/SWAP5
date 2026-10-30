"""Paired real oxygen owners and source-input timestep refinement; no production edits.

The generated applications differ only in output diagnostics and an explicit
DTMAX cap. Every trajectory starts on day1. Diagnostic binaries/checkpoints
have their own bindings and are never substituted into the qualified capsule.
"""
import argparse,csv,hashlib,io,json,math,re,struct,subprocess,sys,tarfile,time
from pathlib import Path,PurePosixPath
from original_sources import build_original
from checkpoint_layout import payload,layout
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
 (out/'grass.crp').write_bytes((ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/grass.crp').read_bytes())
 report['grass_input_sha256']=sha(out/'grass.crp')
 if a.paired_only:
  assert a.observations is not None
  observed=a.observations.resolve();prior=observed.parents[1];build=json.loads((prior/'coarse/build/BUILD.json').read_text());previous=json.loads((prior/'RESULT.json').read_text())
  assert previous['status']=='PAIRED_OXYGEN_AND_REFINEMENT_MEASURED'and previous['coarse_output_only_trajectory_exact']
  generated=PurePosixPath(next(path for path in build['source_sha256']if path.endswith('/observed_backend.f90'))).parent
  prefix='/home/runner/work/SWAP5/SWAP5/'
  for path,digest in build['source_sha256'].items():
   if path.startswith(prefix):owner=ROOT/path[len(prefix):]
   else:
    relative=PurePosixPath(path).relative_to(generated);assert relative.name in ['observed_backend.f90','observed_grass.f90','original_input_helpers.f90'];owner=prior/relative.as_posix()
   assert sha(owner)==digest,('inherited observed source changed',path)
  assert sha(prior/'coarse/build/swap5_grass_startup')==build['executable_sha256']
  assert sha(observed/'stress-trials.dat')==previous['accepted_pair_selection']['trial_observation_sha256']
  for name,digest in previous['refinement']['coarse']['raw_sha256'].items():assert sha(observed/name)==digest
  inputs={'input.swp':'swap.swp','grass.crp':'grass.crp','input.met':'260.met','swap.bbc':'swap.bbc','swap.dra':'swap.dra'}
  for name,original in inputs.items():
   assert sha(observed/name)==build['original_inputs_sha256'][name]
   assert(observed/name).read_bytes()==(ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'/original).read_bytes()
  assert(observed/'application.binding').read_bytes()==(prior/'coarse/build/original-interval/application.binding').read_bytes()
  with tarfile.open(ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz','r:xz')as archive:
   specification=json.load(archive.extractfile('SPEC.json'));native_prefix=specification['full']
   rows=lambda raw:list(csv.DictReader(io.StringIO(raw.decode())))
   for name in ['budget.csv','crop.csv']:assert rows((observed/name).read_bytes())==rows(archive.extractfile(native_prefix+'/'+name).read())[:140]
   assert payload((observed/'checkpoint.bin').read_bytes())==payload(archive.extractfile(native_prefix+'/checkpoint-140.bin').read())
  report['inherited_observations']=dict(result_sha256=sha(prior/'RESULT.json'),application_executable_sha256=build['executable_sha256'],source_and_inputs_verified=True,full_140_day_budget_crop_payload_exact=True)
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
  backend=out/'observed_backend.f90'
  backend_text=(ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
  marker='          self%last_observation%bartholomeus_executed=.true.'
  assert backend_text.count(marker)==1
  tracing="""          if(oxygen_status==FMR_BARTHOLOMEUS_EXEC_OK.and.oxygen_nodes>0.and. &
              any(int(floor(t0))==[24,71,72,126]))then
           block
            integer::dq_unit,dq_node
            open(newunit=dq_unit,file='stress-trials.dat',status='unknown',position='append',action='write')
            write(dq_unit,*)t0,t1,oxygen_nodes
            do dq_node=1,oxygen_nodes
             write(dq_unit,*)dq_node,hydraulic_start%pressure_head(dq_node), &
               hydraulic_start%water_content(dq_node),oxygen_thermal%temperature_c(dq_node), &
               oxygen_factors(dq_node),oxygen_base%root_extraction_sink(dq_node), &
               oxygen_final%root_extraction_sink(dq_node)
            end do
            close(dq_unit)
           end block
          end if
"""
  backend.write_text(backend_text.replace(marker,tracing+marker),newline='\n')
  builds={};trajectories={};horizons=[('coarse',None),('half',.02),('quarter',.01)]
  for name,cap in horizons:
   folder=out/name;folder.mkdir();driver=folder/'observed_grass.f90';text=observed
   if cap:
    needle="call rdsdor('dtmax',1d-7,1d0,source_dtmax)";assert text.count(needle)==1
    text=text.replace(needle,needle+f';source_dtmax=min(source_dtmax,{cap}d0)')
   driver.write_text(text,newline='\n');build=folder/'build';case=folder/'native'
   command=[sys.executable,'-B',ROOT/'tools/solute/build_grass_startup.py','--compiler',fc,'--input-archive',originals['O2']/'ttobj/libttutil.a','--output',build,'--optimization','O2','--profile','checked','--driver',driver,'--provider-override',backend,'--end','1','--policy','retained']
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
   measurement=report['refinement'][name]
   receipt={day:[]for day in [25,72,73,127]}
   for line in (case/'stdout').read_text().splitlines():
    fields=line.split()
    if fields and fields[0]=='STRESS_ACCEPTED':
     day=int(fields[1]);receipt[day].append(list(map(float,fields[2:])))
   measurement['accepted_substeps']={}
   for day,rows in receipt.items():
    assert rows,('missing accepted duration observation',name,day)
    duration=[r[1]-r[0]for r in rows];assert all(dt>0 for dt in duration)
    assert abs(math.fsum(duration)-1)<1e-10,('accepted day coverage',name,day)
    amounts={key:math.fsum(r[index]*dt for r,dt in zip(rows,duration))for key,index in [('potential_cm',2),('uptake_cm',3),('deepest_oxygen_integral_day',4)]}
    assert abs(amounts['potential_cm']-float(budget[day-1]['potential_cm']))<1e-10
    assert abs(amounts['uptake_cm']-float(budget[day-1]['uptake_cm']))<1e-10
    measurement['accepted_substeps'][str(day)]=dict(count=len(rows),minimum_duration_day=min(duration),maximum_duration_day=max(duration),duration_sum_day=math.fsum(duration),**amounts)
   for day in [25,72,73,126,127,140]:
    checkpoint=case/f'checkpoint-{day}.bin';raw=checkpoint.read_bytes();state=layout(raw)
    actual,potential=struct.unpack_from('=dd',raw,state['management']+4)
    measurement['selected_days'][str(day)]['native_harvest_kg_ha']=actual
    measurement['selected_days'][str(day)]['native_potential_harvest_kg_ha']=potential
   measurement['cumulative_140_cm']={key:math.fsum(float(row[key])for row in budget)for key in ['potential_cm','uptake_cm','oxygen_cm','drought_cm']}
   measurement['raw_sha256']={file:sha(case/file)for file in ['budget.csv','crop.csv','stdout','checkpoint.bin']}

  report['coarse_output_only_trajectory_exact']=True
 assert observations is not None
 accepted={}
 for line in (observations/'stdout').read_text().splitlines():
  fields=line.split()
  if fields and fields[0]=='STRESS_ACCEPTED':
   values=list(map(float,fields[2:]));accepted[(round(values[0],12),round(values[1],12))]=(int(fields[1]),values)
 prepared=out/'prepared-inputs';prepared.mkdir()
 for day in [25,72,73,127]:
  daily=(observations/f'stress-input-{day}.dat').read_text().splitlines()
  origin=(observations/f'checkpoint-{day-1}.bin').read_bytes();state=layout(origin)
  root_depth=struct.unpack_from('=d',origin,state['roots'])[0]
  first=min(values for key,(selected_day,values)in accepted.items()if selected_day==day)
  daily[2]+=' '+format(first[2],'.17e')+' '+format(root_depth,'.17e')
  (prepared/f'day-{day}.dat').write_text('\n'.join(daily)+'\n',newline='\n')
 trial_file=observations/'stress-trials.dat';paired_records=[];batch=out/'accepted-oxygen-inputs.dat'
 if trial_file.exists():
  trials={};lines=iter(trial_file.read_text().splitlines())
  for line in lines:
   header=line.split();t0,t1=float(header[0]),float(header[1]);count=int(header[2]);nodes=[list(map(float,next(lines).split()))for _ in range(count)]
   key=(round(t0,12),round(t1,12))
   if key in accepted:trials[key]=nodes
  assert set(trials)==set(accepted),'accepted thermal/oxygen trial observations missing'
  with batch.open('w',newline='\n')as stream:
   for key,(day,receipt)in sorted(accepted.items()):
    daily=(prepared/f'day-{day}.dat').read_text().splitlines();header=daily[2].split();header[4]=format(receipt[2],'.17e');daily[2]=' '.join(header);node_count,root_count=map(int,daily[0].split());nodes=trials[key]
    assert len(nodes)==root_count
    stream.write('\n'.join(daily[:3])+'\n')
    for i,line in enumerate(daily[3:]):
     fields=line.split()
     if i<root_count:fields[3:6]=[format(v,'.17e')for v in nodes[i][1:4]]
     stream.write(' '.join(fields)+'\n')
    dt=receipt[1]-receipt[0]
    assert abs(sum(row[6]for row in nodes)-receipt[3])<1e-10,'production trace does not reproduce accepted uptake'
    paired_records.append(dict(day=day,t0=receipt[0],t1=receipt[1],duration=dt,nodes=nodes))
  report['accepted_pair_selection']=dict(cases=len(paired_records),batch_sha256=sha(batch),trial_observation_sha256=sha(trial_file),scope='Only actual accepted flux-receipt intervals; rejected/full sibling observations retained but excluded')

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
   path=prepared/f'day-{day}.dat';stdout=run([exe,path],f'paired-{opt}-{day}');(folder/f'day-{day}.stdout').write_bytes(stdout)
   lines=stdout.decode().splitlines();maximum=next(float(line.split()[-1])for line in lines if line.startswith('PAIRED_MAX_FACTOR_DIFFERENCE'))
   report['paired'][opt][str(day)]=dict(maximum_factor_difference=maximum,observation_sha256=sha(path),stdout_sha256=hashlib.sha256(stdout).hexdigest())
  if paired_records:
   raw=run([exe,batch],f'accepted-oxygen-{opt}',timeout=600);(folder/'accepted-oxygen.stdout').write_bytes(raw)
   cases={};whole={};record=0
   for line in raw.decode().splitlines():
    if line.startswith('PAIRED_CASE '):record=int(line.split()[-1]);cases[record]=[]
    elif line.startswith('PAIRED_WHOLE_UPTAKE '):whole[record]=list(map(float,line.split()[1:]))
    elif line.strip()and line.strip()[0].isdigit()and ','in line:cases[record].append(list(map(float,line.split(','))))
   assert len(cases)==len(paired_records)
   by_day={day:dict(current_uptake_cm=0.,original_oxygen_on_native_uptake_cm=0.,maximum_factor_difference=0.,maximum_current_reproduction_error=0.,stressed_nodes=0,cases=0,whole_original_uptake_cm=0.,whole_current_uptake_cm=0.,maximum_whole_node_uptake_difference_cm_day=0.)for day in [25,72,73,127]}
   for index,state in enumerate(paired_records,1):
    rows=cases[index];assert len(rows)==len(state['nodes']);measurement=by_day[state['day']];measurement['cases']+=1
    measurement['whole_original_uptake_cm']+=whole[index][0]*state['duration'];measurement['whole_current_uptake_cm']+=whole[index][1]*state['duration']
    measurement['maximum_whole_node_uptake_difference_cm_day']=max(measurement['maximum_whole_node_uptake_difference_cm_day'],whole[index][2])
    for row,production in zip(rows,state['nodes']):
     old,new=row[6],row[7];error=abs(new-production[4]);measurement['maximum_current_reproduction_error']=max(measurement['maximum_current_reproduction_error'],error)
     assert error<1e-12,('current standalone/actual backend oxygen mismatch',opt,index,row[0],error)
     measurement['maximum_factor_difference']=max(measurement['maximum_factor_difference'],abs(new-old))
     measurement['stressed_nodes']+=int(old<.99999 or new<.99999)
     measurement['current_uptake_cm']+=production[5]*new*state['duration']
     measurement['original_oxygen_on_native_uptake_cm']+=production[5]*old*state['duration']
   budgets=list(csv.DictReader((observations/'budget.csv').open()))
   for day,measurement in by_day.items():
    assert abs(measurement['current_uptake_cm']-float(budgets[day-1]['uptake_cm']))<1e-10
    measurement['oxygen_owner_only_uptake_difference_cm']=measurement['current_uptake_cm']-measurement['original_oxygen_on_native_uptake_cm']
    assert abs(measurement['whole_current_uptake_cm']-float(budgets[day-1]['uptake_cm']))<1e-10,'whole current uptake does not reproduce backend'
    assert abs(measurement['whole_original_uptake_cm']-measurement['original_oxygen_on_native_uptake_cm'])<1e-10,'original/current non-oxygen uptake composition differs'
   assert sum(row['stressed_nodes']for row in by_day.values())>0,'paired accepted selection has no stressed coverage'
   report['paired'][opt]['accepted_substeps']=by_day
 assert all(sha(ROOT/path)==digest for path,digest in report['source_sha256'].items())
 report['status']='PAIRED_OXYGEN_AND_REFINEMENT_MEASURED';report['limitations']=['Accepted-substep replay uses the native hydraulic/thermal trajectory and native pre-oxygen sinks; it does not substitute the donor trajectory','Whole uptake replay is qualified only for the selected original Grassgrowth options and observed native states','No harvest-equivalence limit is inferred from the existing 1e-4 oxygen component gate'];save()
 print(json.dumps({key:value for key,value in report.items()if key not in ['events','source_sha256','refinement']},indent=2))

if __name__=='__main__':main()
