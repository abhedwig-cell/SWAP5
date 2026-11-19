"""Real front-door AGE refusals and literal water/CDE guard-only composition."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys,time
import implicit_conductivity_runtime as c
from daily_coupling import CoupledDailyColumn
from implicit_conductivity_admission import AGE_REFUSAL,require_transport
from original_output_baseline import assignment

MODEL_SOURCE='f7f23dbe531b579991d3a77fd2b67cb05a08f67a'
COUPLING_GUARD='    from implicit_conductivity_admission import require_transport\n    require_transport(project)\n'
CLI_GUARD='        from implicit_conductivity_admission import require_transport\n        require_transport(project)\n'


def literal_composition():
 r=c.ROOT
 def git(*args):return subprocess.check_output(['git',*args],cwd=r)
 changed=set(git('diff','--name-only',MODEL_SOURCE,'HEAD','--','app','src','reference','tools').decode().splitlines())
 assert changed=={'app/hybrid_water/implicit_conductivity_admission.py','app/hybrid_water/daily_coupling.py','tools/solute/run_water.py'},changed
 for name,guard in [('app/hybrid_water/daily_coupling.py',COUPLING_GUARD),('tools/solute/run_water.py',CLI_GUARD)]:
  current=(r/name).read_text(encoding='utf8');assert current.count(guard)==1
  assert current.replace(guard,'',1).encode()==git('show',MODEL_SOURCE+':'+name).replace(b'\r\n',b'\n'),name
 return dict(status='LITERAL_MODEL_RUNTIME_PLUS_ONLY_TWO_PUBLIC_ADMISSION_CALLS',model_source=MODEL_SOURCE,changed_production=sorted(changed))


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();matrix=json.loads((a.matrix_root/'RESULT.json').read_text());q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=c.ROOT,text=True).strip(),literal_composition=literal_composition(),refusals=[],actual_water_cde_validations=[],literal_age_zero_delegations=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  candidates=dict(matrix['cases'])
  if not any(item['short']['parameters']['solute']==2 for item in candidates.values()):
   # Linux never compiles the unqualified AGE prototype. Use valid original
   # AGE descriptors and a real existing W/C bundle/origin to prove the AGE
   # guard precedes any bundle/native access; no fake provider is supplied.
   actual=matrix['cases']['water-head']
   for name,hys,bot,k,step,mode,fmt,reset in [('age-head-history',2,5,6,True,'explicit',3,1),('age-air-history',1,8,2,False,'monthly',1,0),('age-groundwater-history',1,1,3,True,'explicit',3,1)]:
    inputs=a.output/('descriptor-'+name);c.fixture(inputs,2,hys,bot,step,k,mode,fmt,reset)
    candidates[name]=dict(actual,input_root=str(inputs),guard_probe_role='Actual original AGE descriptor against an actual foreign W/C bundle; refuse before bundle/native access')
  for name,item in candidates.items():
   short=item['short'];project=c.m.e.load(Path(item['input_root']),original_output=True);build=Path(item['build_root'])
   if not project.age:
    require_transport(project);c.m.validate_bundle(build,a.reference_work,project);q['actual_water_cde_validations'].append(name);save();continue
   target=a.output/name;target.mkdir();origin=Path(item['short_root'])/'trajectory/accepted-column-1-day-4.zip';digest=c.m.sha(origin)
   command=[sys.executable,'-B',str(c.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(project.input_directory),'--original-output','--reference-work',str(a.reference_work),'--build-only','--output',str(target/'public-build')]
   t=time.perf_counter();result=subprocess.run(command,cwd=c.ROOT,capture_output=True,text=True,timeout=30);(target/'public.stdout').write_text(result.stdout);(target/'public.stderr').write_text(result.stderr)
   assert result.returncode!=0 and AGE_REFUSAL in result.stderr and not (target/'public-build').exists(),(name,result.returncode,result.stderr)
   try:CoupledDailyColumn(build,a.reference_work,target/'coupled',project,'implicit-age-refusal',origin=origin,day=4,adopt_native=True)
   except ValueError as error:assert str(error)==AGE_REFUSAL
   else:raise AssertionError('Unqualified implicit AGE coupled worker accepted')
   assert c.m.sha(origin)==digest and not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
   q['refusals'].append(dict(name=name,public_returncode=result.returncode,seconds=time.perf_counter()-t,public_before_compilation=True,coupled_before_worker=True,actual_origin_sha256=digest,origin_unchanged=True,probe_role=item.get('guard_probe_role','Actual retained same-domain AGE prototype bundle/origin')));save()
   import shutil
   zero=target/'original-implicit-zero';shutil.copytree(project.input_directory,zero);path=zero/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),'SWKIMPL',0),encoding='cp1252')
   delegated=c.m.e.load(zero,original_output=True);require_transport(delegated)
   q['literal_age_zero_delegations'].append(dict(name=name,status='GUARD_DELEGATES_OLD_AGE_POLICY',fresh_physical_pass_claim=False));save()
  assert len(q['refusals'])==3 and len(q['actual_water_cde_validations'])==8
  q['status']='THREE_ACTUAL_IMPLICIT_AGE_FRONT_DOOR_REFUSALS_EIGHT_LITERAL_WATER_CDE_BUNDLES_PASS';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
