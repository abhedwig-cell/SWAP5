"""Real original implicit Frost inputs with composed analytical layer models."""
import argparse,json,math,re,subprocess,sys,time,zipfile
from contextlib import ExitStack
from datetime import date
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from implicit_hydraulic_state_feedback import BASE,SHA
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from original_output_baseline import assignment
from explicit_bottom9_runtime import m,own
from implicit_hydraulic_state import selected,validate_candidate
from implicit_frost_root_state import validate_native
from frost_boundary_convergence import require_convergence
CASES={
 'mixed2-3-water-d0-b5':dict(models=[2,3],prefix='current/water-d0-b5-i1-h0-p2-regular-r0-year-seam/inputs/',year=True),
 'mixed4-5-cde-d1-b5':dict(models=[4,5],prefix='current-inherited-postimages/cde-b5-i1-h0-p2-dates-r1/inputs/',year=False),
 'mixed6-7-cde-d0-b8':dict(models=[6,7],prefix='current/cde-d0-b8-i1-h2-p2-dense/inputs/',year=False),
 'mixed8-9-water-d1-b8':dict(models=[8,9],prefix='current-inherited-postimages/water-b8-i1-h2-p1-dates-r1/inputs/',year=False),
 'mixed10-11-water-d0-b5':dict(models=[10,11],prefix='current/water-d0-b5-i1-h0-p2-regular-r0-year-seam/inputs/',year=True),
}


def main():
 p=argparse.ArgumentParser()
 for n in ['output','build-output','reference-work']:p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--case',choices=CASES,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True)
 a=p.parse_args();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=R)
 a.output.mkdir();inputs=a.output/'inputs';inputs.mkdir();spec=CASES[a.case]
 q=dict(status='RUNNING_ACTUAL_ORIGINAL_IMPLICIT_FROST_ANALYTICAL_STATE_FEEDBACK_NOT_ADMITTED',actual_source=head,case=a.case,specification=spec,optimization=a.optimization,days=35,input_root=str(inputs),build_root=str(a.build_output/'bundle'),canonical_admission=False)
 save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  with ExitStack() as stack:
   source=GitArchiveSource(R,BASE);name='FROST_UNDRAINED_STATE08_WINDOWS_O0_ORIGINAL_V1';origin=Archive(source,name,stack)
   for n in origin.names:
    if n.startswith(spec['prefix']):
     target=inputs/n[len(spec['prefix']):];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(origin.get(n))
   q['original_input_authority']=dict(actual_git_source=BASE,archive=name,archive_sha256=origin.record['sha256'],prefix=spec['prefix'])
   path=inputs/'swap.swp';before=path.read_bytes();text=before.decode('cp1252')
   assert re.findall(r'(?mi)^\s*SWKIMPL\s*=\s*(\d+)',text)==['1']
   assert re.findall(r'(?mi)^\s*SWFROST\s*=\s*(\d+)',text)==['1']
   models=spec['models'];edits=dict(SWHYST=0,iHWCKmodel=' '.join(map(str,models)))
   for key,value in edits.items():text=assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n'
   donor_name='FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1';donor=Archive(source,donor_name,stack);member='current-unaffected-postimages/model7-cde-d1-b8-dense/inputs/swap.swp';original=donor.get(member).decode('cp1252')
   keys=[*(['ALFA_2','NPAR_2','OMEGA_1'] if any(v in (3,6,7,10,11) for v in models) else []),*(['H0'] if any(v in (5,7,8,9,10,11) for v in models) else []),*(['HA','APAR','OMEGA_K','SWVAPOR'] if any(v>=8 for v in models) else [])];lines={}
   for key in keys:
    rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*(?:\r?\n|$)',original);assert len(rows)==1 and not re.search(r'(?mi)^\s*'+key+r'\s*=',text)
    lines[key]=rows[0];text+='\n'+rows[0]
   path.write_bytes(text.encode('cp1252'));q['original_additional_parameter_authority']=dict(archive=donor_name,archive_sha256=donor.record['sha256'],member=member,member_sha256=SHA(original.encode('cp1252')),literal_original_named_lines=lines)
   q['explicit_configuration_edits']=dict(assignments=edits,before_sha256=SHA(before),after_sha256=SHA(path.read_bytes()),original_numerical_limits_dates_boundaries_and_parameter_table_unchanged=True)
  if 3 in models:
   q['original_supported_oxygen1']=[]
   for crop in inputs.glob('*.crp'):
    before=crop.read_bytes();after=assignment(before.decode('cp1252'),'SWOXYGEN',1).encode('cp1252');crop.write_bytes(after);q['original_supported_oxygen1'].append(dict(file=crop.name,before_sha256=SHA(before),after_sha256=SHA(after)))
  policy='original-adaptive-event-closure-v1';project=m.e.load(inputs,original_output=True,time_step_policy=policy);item=selected(project);assert item and item['frost']==1
  q['actual_selection']=item;q['input_inventory']=m.e.inventory(inputs);save();build=Path(q['build_root'])
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  started=time.perf_counter()
  with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:child=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
  q['build']=dict(command=command,returncode=child.returncode,seconds=time.perf_counter()-started);save();child.check_returncode();meta,_=m.validate_bundle(build,a.reference_work,project);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes())
  windows=[(2,4),(7,9),(30,34)];cuts={35,*[day for pair in windows for day in pair]}
  if spec['year']:
   first=date.fromisoformat(meta['project']['start_date']);seam=(date(first.year+1,1,1)-first).days;assert 2<seam<35
   pair=(max(d for d in cuts if d<seam),min(d for d in cuts if d>seam));q['actual_calendar_derived_year_window']=dict(start_date=str(first),new_year_offset=seam,window=pair)
   if pair not in windows:windows.append(pair)
  q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,cuts,300);save();q['original_convergence']=require_convergence(a.output)
  q['native_samples']=[]
  for day in sorted(cuts):
   with zipfile.ZipFile(a.output/'trajectory'/f'accepted-column-1-day-{day}.zip') as z:raw=z.read('macro.bin');validate_candidate(raw,project);root=validate_native(raw,project)
   q['native_samples'].append(dict(day=day,bytes=len(raw),sha256=SHA(raw),actual_parent_magic=raw[:8].decode(),extension_tag='S5IFX001',original_root_diagnostic_rates=root))
  witness=[list(map(float,line.split()[1:])) for line in (a.output/'trajectory/original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_FROST_WITNESS ')];assert witness and all(len(v)==6 and all(map(math.isfinite,v)) for v in witness)
  q['actual_partial_frost_witnesses']=sum(0<v[0]<1 for v in witness);q['actual_snow_maximum_cm']=max(row['stock_end_cm'][2] for row in data);assert q['actual_partial_frost_witnesses']>0 and q['actual_snow_maximum_cm']>0
  q['cold']=[]
  for lo,hi in windows:q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,lo,hi,a.output/('own-'+str(lo))));save()
  from cde_clock_controls import transactions
  q['external_transactions']=transactions(build,a.reference_work,project,a.output/'trajectory',a.output/'transactions');assert all(v is True for v in q['external_transactions'].values())
  assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
  q['status']='ACTUAL_ORIGINAL_IMPLICIT_FROST_ANALYTICAL_STATE_PHYSICAL_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED_ACTUAL_ORIGINAL_IMPLICIT_FROST_ANALYTICAL_STATE_FEEDBACK_NOT_ADMITTED',error=repr(error));raise
 finally:save()
 print(q['status'],a.case,a.optimization,flush=True)


if __name__=='__main__':main()
