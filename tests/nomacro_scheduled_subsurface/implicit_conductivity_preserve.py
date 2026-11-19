"""Fresh original explicit numerical routes against immutable admitted raw members."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path,PurePosixPath,PureWindowsPath
import age_groundwater_runtime as current
from age_groundwater_output import active_selection
from original_output_files import records

m=current.m;ROOT=current.ROOT
FAMILIES={
 'age-groundwater':('AGE_GROUNDWATER_QUALIFICATION.json',('ordinary-periodic-crossing-binary','history-periodic-crossing-binary','history-explicit-perstep-binary')),
 'age':('AGE_PERSTEP_QUALIFICATION.json',('ordinary-explicit-h0-binary','history-monthly-h2-vector','history-explicit-h1-binary')),
 'nonstep':('OUTPUT_HYSTERESIS_QUALIFICATION.json',('age-hys1-csv3',)),
 'direct':('DIRECT_SOIL_AGE_QUALIFICATION.json',('interval-perstep-monthly',)),
 'groundwater':('GROUNDWATER_CHEMICAL_QUALIFICATION.json',('within-csv3','crossing-default')),
 'groundwater-history':('GROUNDWATER_HISTORY_QUALIFICATION.json',('hys1-snow0-original','hys2-snow1-chemistry-bbc','hys1-heat0-drain0-et1-default','hys0-snow1-default')),
 'cde':('CDE_CLOCK_QUALIFICATION.json',('ordinary-explicit-hys0-binary','ordinary-periodic-hys1-vector','snow-monthly-hys2-binary')),
}



def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','prior-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--evidence-root',type=Path);p.add_argument('--family',choices=tuple(FAMILIES),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
 a=p.parse_args();a.output.mkdir();name,keys=FAMILIES[a.family];authority=ROOT/'integration/f-ci/nomacro-complete01'/name;qualification=json.loads(authority.read_text(encoding='utf8'))
 prefix={'age-groundwater':'AGE_GROUNDWATER','age':'AGE_PERSTEP','nonstep':'OUTPUT_HYSTERESIS','direct':'DIRECT_SOIL_AGE','groundwater':'GROUNDWATER_CHEMICAL','groundwater-history':'GROUNDWATER_HISTORY','cde':'CDE_CLOCK'}[a.family]
 recordname=f'{prefix}_{a.platform.upper()}_{a.optimization}_RAW_ARCHIVE.json'
 run=json.loads((a.prior_root/'RESULT.json').read_text(encoding='utf8')) if a.family in ('age-groundwater','age','groundwater','groundwater-history','cde') else qualification['platforms'][a.platform][a.optimization]
 record=qualification['archives'][recordname];members=record['members'];q=dict(status='RUNNING',family=a.family,optimization=a.optimization,platform=a.platform,qualification=name,qualification_sha256=m.sha(authority),immutable_prior_archive=recordname,profiles={})
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
 def location(member):return (a.evidence_root if a.platform=='Windows' else a.prior_root)/member
 def checked(path):
  member=path.relative_to(a.evidence_root if a.platform=='Windows' else a.prior_root).as_posix();assert hashlib.sha256(path.read_bytes()).hexdigest()==members[member],member
 def data(path):checked(path);return json.loads(path.read_text(encoding='utf8'))
 save()
 try:
  for key in keys:
   item=run['cases'][key];prior=item['short'];bd=prior['trajectory']['build_sha256'];matches=[path for path,value in members.items() if path.endswith('/build/BUILD.json') and value==bd];assert len(matches)==1,(key,matches)
   oldbuildpath=location(matches[0]);oldbuild=data(oldbuildpath);oldroot=oldbuildpath.parent.parent;oldreport=data(oldroot/'RESULT.json');assert oldreport==prior
   inputs=oldroot/'input';assert inputs.is_dir(),inputs
   for child in oldbuild['inputs']:checked(inputs/child)
   oldtrajectory=oldroot/'trajectory';checked(oldtrajectory/'daily.jsonl');olddata=m.rows(oldtrajectory);days=prior['trajectory']['days'];assert len(olddata)==days and days in (10,35)
   args={k:oldbuild['identity'][k] for k in ('time_step_policy','solute_step_policy','soil_table_policy')}
   args['original_output']=oldbuild['identity'].get('original_output') is not None
   source_policy=oldbuild['identity'].get('conserved_original_age',{}).get('irrigation_source',{}).get('policy')
   args['age_irrigation_source']=source_policy=='original-fixed-current-irrigation-age-days-v1'
   args['age_direct_soil_source']=source_policy=='original-fixed-direct-soil-age-transport-then-input-v1'
   project=m.e.load(inputs,**args);out=a.output/key;out.mkdir();build=out/'build';cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
   for flag in ('original_output','age_irrigation_source','age_direct_soil_source'):
    if getattr(project,flag):cmd.append('--'+flag.replace('_','-'))
   result=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(result.stdout,encoding='utf8');(out/'build.stderr').write_text(result.stderr,encoding='utf8');result.check_returncode()
   actual,_=m.validate_bundle(build,a.reference_work,project);assert m.e.inspect(inputs)['selectors']['SWKIMPL']==0;overlap=False
   for field in ('kernel_sources','kernel_flags','donor_flags'):assert actual['identity'][field]==oldbuild['identity'][field],(key,field)
   changed=sorted(k for k,v in oldbuild['identity']['donor_generated'].items() if actual['identity']['donor_generated'].get(k)!=v)
   if not overlap:assert actual['identity']['donor_generated']==oldbuild['identity']['donor_generated'] and actual['identity'].get('original_output')==oldbuild['identity'].get('original_output'),(key,changed)
   prior_checkpoints={int(path.stem.rsplit('-',1)[1]):path for path in oldtrajectory.glob('accepted-column-1-day-*.zip')};assert len(prior_checkpoints)>=2
   window=next(((s,e) for s,e in ((30,34),(4,8),(2,4)) if s in prior_checkpoints and e in prior_checkpoints),None);assert window is not None
   trajectory,rows=m.trajectory(build,a.reference_work,project,out/'trajectory',days,{days,*prior_checkpoints},120);assert m.physical(rows)==m.physical(olddata)
   native=[]
   for day,path in sorted(prior_checkpoints.items()):
    checked(path)
    with zipfile.ZipFile(path) as old,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as new:
     assert old.read('result.end')==new.read('result.end')
     left,right=old.read('macro.bin'),new.read('macro.bin');assert (left[8:]==right[8:] if overlap else left==right),(key,day)
     native.append(dict(day=day,old_codec=left[:8].decode(),current_codec=right[:8].decode(),complete_native_exact=not overlap,actual_codec_only_projection_exact=overlap))
   output={}
   for path in oldtrajectory.glob('original/*'):
    if path.suffix!='.csv' and not path.name.endswith('_output.bin'):continue
    if path.name not in ('result_output.csv','result_output.bin') and not path.name.lower().startswith('result.age'):continue
    checked(path);fresh=out/'trajectory/original'/path.name;assert records(path)==records(fresh),path.name;output[path.name]=dict(exact=True,records=len(records(path)))
   cold=current.own(build,a.reference_work,project,out/'trajectory',rows,*window,out/f'own-{window[0]}')
   q['profiles'][key]=dict(actual_build=actual,trajectory=trajectory,all_physical_exact=True,actual_immutable_prior_member_hashes=True,prior_build_sha256=bd,prior_report_sha256=m.sha(oldroot/'RESULT.json'),prior_daily_sha256=m.sha(oldtrajectory/'daily.jsonl'),prior_archive=recordname,prior_profile_prefix=oldroot.relative_to(a.evidence_root if a.platform=='Windows' else a.prior_root).as_posix(),overlap_new_codec=overlap,actual_generated_source_differences=changed,native=native,original_user_output=output,cold=cold);save();print(key,'ACTUAL_AFFECTED_SEAM_PRESERVED',flush=True)
  q['status']='ACTUAL_IMPLICIT_CONDUCTIVITY_PRIOR_'+a.family.upper()+'_SEAMS_PRESERVED';print(q['status'],flush=True)
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()


if __name__=='__main__':main()
