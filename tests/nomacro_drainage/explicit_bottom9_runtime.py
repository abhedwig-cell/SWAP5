"""Run actual explicit paired head/flux contexts through unchanged production hosts."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
import original_output_matrix as original
from explicit_bottom9_source_inverse import CORE,LAST_NODE_CORE,complete_inverse,git
from groundwater_water_output import metadata
from original_output_files import compare
m=original.m


def own(build,reference,project,full,data,start,end,out):
 meta,case=m.validate_bundle(build,reference,project);source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
 result,seconds=m.bounded(90,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=meta['binding'],model=project.model,project=project));assert result['first_refusal'] is None,result
 actual=m.rows(out);m.check(actual);assert m.physical(actual)==m.physical(data[start:end])
 with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
  assert a.read('macro.bin')[:8]==m.e.auxiliary_magic(project)
  for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
 files=compare(full/'original',out/'original',metadata(project),start,end,project.start_date);assert m.sha(source)==digest
 return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_user_output=files,origin_unchanged=True,seconds=seconds)


def main():
 p=argparse.ArgumentParser()
 for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--case',required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();complete_inverse();a.output.mkdir()
 q=dict(status='RUNNING',source=git('rev-parse','HEAD').decode().strip(),physical_core=CORE,input_admission_core=LAST_NODE_CORE,case=a.case,optimization=a.optimization,days=35,input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(a.build_root/'bundle'),canonical_admission=False)
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  project=m.e.load(a.input,original_output=True,time_step_policy='original-adaptive-day-seed-v1');s=m.e.switches((a.input/'swap.swp').read_text(encoding='cp1252'));assert s['SWINCO'] in (1,2) and s['SWBOTB']==9 and s['SWMACRO']==s['SWFROST']==s['SWSOPHY']==0
  q.update(native_codec=m.e.auxiliary_magic(project).decode(),actual_original_output_metadata=metadata(project),kind=('water','cde','age')[s['SWSOLU']]);build=Path(q['build_root'])
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
  started=time.perf_counter();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240);(a.output/'build.stdout').write_text(result.stdout);(a.output/'build.stderr').write_text(result.stderr);q['build']=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-started);save();result.check_returncode()
  m.validate_bundle(build,a.reference_work,project);q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',35,{2,4,19,23,30,34,35},600);q['cold']=[];save()
  for start,end in ((2,4),(19,23),(30,34)):q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,start,end,a.output/('own-'+str(start))));save()
  q['status']='ACTUAL_EXPLICIT_PAIRED_HEAD_FLUX_PHYSICAL_NATIVE_EXACT_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],a.case,a.optimization,flush=True)


if __name__=='__main__':main()
