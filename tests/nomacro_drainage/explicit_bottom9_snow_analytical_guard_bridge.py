"""Qualify one new native precondition against genuine original full-period data."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from explicit_bottom9_runtime import m
from explicit_bottom9_snow_analytical_source import complete_inverse,git
from analytical_hydraulic_archives import SHA
from calendar_publisher import publisher_equivalence
from groundwater_water_output import metadata
from original_output_files import compare as outputs


def generated_bridge(old,current,contract):
 suffixes={'.f90','.f','.for','.inc'}
 inventory=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and p.suffix.lower() in suffixes}
 left,right=inventory(old),inventory(current);assert left and left.keys()==right.keys();rows=[];changed=[]
 for name,path in sorted(left.items()):
  before,after=path.read_bytes(),right[name].read_bytes();original=before.replace(b'\r\n',b'\n');actual=after.replace(b'\r\n',b'\n')
  if actual!=original:
   assert Path(name).name in ('macropore.f90','snow_undrained_root_state.f90'),name
   for edit in reversed(contract['literal_edits']):
    old_text,new_text=edit['before'].encode(),edit['after'].encode();assert actual.count(new_text)==1;actual=actual.replace(new_text,old_text,1)
   assert actual==original,'Additional generated source change beyond pure inactive-vapor precondition: '+name;changed.append(name)
  rows.append(dict(file=name,original_sha256=SHA(before),current_sha256=SHA(after)))
 assert {Path(name).name for name in changed}=={'macropore.f90','snow_undrained_root_state.f90'}
 return dict(all_complete_generated_sources=rows,only_pure_native_precondition_differs=changed)


def compiled_bridge(old,current):
 suffixes={'.o','.mod','.smod','.exe','.dll','.so','.a'}
 inventory=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and (p.suffix.lower() in suffixes or p.name in ('day_donor','day_kernel'))}
 left,right=inventory(old),inventory(current);assert left and left.keys()==right.keys();rows=[];changed=[]
 permitted={'macropore.o','hybrid_snow_analytical_native.mod','day_donor.exe','day_donor'}
 for name,path in sorted(left.items()):
  before,after=path.read_bytes(),right[name].read_bytes();row=dict(file=name,original_sha256=SHA(before),current_sha256=SHA(after))
  if before==after:row['status']='ACTUAL_COMPLETE_COMPILED_BYTES_EXACT'
  elif Path(name).name in permitted:row['status']='CHANGED_ONLY_NATIVE_PRECONDITION_COMPILE_LINK_CLOSURE';changed.append(name)
  else:
   assert path.suffix.lower() in ('.dll','.exe') and before[:2]==after[:2]==b'MZ','Unexpected changed compiled file '+name
   row['PE_whole_code_data_relocations']=publisher_equivalence(path,right[name]);row['status']='ACTUAL_WHOLE_PE_CODE_DATA_EXACT_LINK_METADATA_RETAINED'
  rows.append(row)
 assert 'macropore.o' in {Path(name).name for name in changed}
 return dict(all_actual_compiled_files=rows,changed_native_precondition_closure=changed,physical_kernel_and_all_unaffected_objects_preserved=True)


def main():
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();a.output.mkdir();complete_inverse();head=git('rev-parse','HEAD').decode().strip()
 contract=json.loads((ROOT/'integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_VAPOR_DOMAIN_GUARD_CONTRACT_V1.json').read_text());path=contract['source_file'];before=git('show',contract['original_positive_source']+':'+path)
 actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(before)==contract['original_complete_lf_sha256'] and SHA(actual)==contract['proposed_complete_lf_sha256']
 assert git('diff','--name-only',contract['original_positive_source'],'HEAD','--','app','src','tools','reference').decode().splitlines()==[path]
 prior=json.loads((a.profile/'RESULT.json').read_text());assert prior['days']==35 and prior['status'].endswith('PASS_NOT_ADMITTED')
 old=Path(prior['build_root']);inputs=Path(prior['input_root']);oldmeta=json.loads((old/'BUILD.json').read_text());assert SHA((old/'BUILD.json').read_bytes())==prior['actual_BUILD_sha256']
 assert {name:SHA((inputs/name).read_bytes()) for name,_ in prior['input_inventory']}==dict(prior['input_inventory'])==oldmeta['inputs']
 project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1');build=a.build_root/'bundle'
 q=dict(status='RUNNING',source=head,original_full35_source=prior['source'],original_full35_profile=str(a.profile),original_full35_RESULT_sha256=SHA((a.profile/'RESULT.json').read_bytes()),original_BUILD_sha256=prior['actual_BUILD_sha256'],old_build_root=str(old),input_root=str(inputs),input_inventory=prior['input_inventory'],build_root=str(build),kind=prior['kind'],layer_models=prior['layer_models'],optimization=prior['optimization'],actual_current_warm_days=4,actual_current_cold_window=[4,7],original_full35_period_replayed=False,checkpoint_binding_rewritten=False,canonical_admission=False);start=time.monotonic()
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',prior['optimization'],'--kernel-opt',prior['optimization'],'--output',str(build)]
  with (a.output/'build.stdout').open('x') as out,(a.output/'build.stderr').open('x') as err:done=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300)
  done.check_returncode();assert git('rev-parse','HEAD').decode().strip()==head
  meta,case=m.validate_bundle(build,a.reference_work,project);assert meta['inputs']==oldmeta['inputs']
  q.update(actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),current_binding=meta['binding'],original_binding=oldmeta['binding'],complete_generated_bridge=generated_bridge(old,build,contract),complete_compiled_bridge=compiled_bridge(old,build));save()
  olddata=m.rows(a.profile/'trajectory');assert len(olddata)==35
  q['warm'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',4,{2,4},120);assert m.physical(data)==m.physical(olddata[:4]);save()
  for day in (2,4):
   with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(a.profile/f'trajectory/accepted-column-1-day-{day}.zip') as original:
    assert json.loads(new.read('checkpoint.json'))['binding']==meta['binding']
    for name in ('macro.bin','result.end'):assert new.read(name)==original.read(name),'Changed valid-domain native prefix '+name
  source=a.output/'trajectory/accepted-column-1-day-4.zip';digest=SHA(source.read_bytes());origin=a.output/'cold-origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);cold=a.output/'own-4';cold.mkdir()
  result,seconds=m.bounded(90,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,cold,7,checkpoint_day=4,origin=origin,origin_receipt=receipt,runtime=True,publish_day=7,checkpoint_binding=meta['binding'],model=project.model,project=project));assert result['first_refusal'] is None,result
  observed=m.rows(cold);m.check(observed);assert m.physical(observed)==m.physical(olddata[4:7]) and SHA(source.read_bytes())==digest
  if project.solute:assert any(row['solute_ledger_mg_cm2'][3]>0 for row in observed)
  with zipfile.ZipFile(cold/'accepted-column-1-day-7.zip') as new,zipfile.ZipFile(a.profile/'trajectory/accepted-column-1-day-7.zip') as original:
   assert json.loads(new.read('checkpoint.json'))['binding']==meta['binding']
   for name in ('macro.bin','result.end'):assert new.read(name)==original.read(name),'Changed valid-domain complete cold state '+name
  q['cold']=dict(start=4,end=7,physical_and_complete_native_exact_to_original_full35=True,current_origin_binding_verified=True,original_checkpoint_rebound=False,exact_original_user_output=outputs(a.profile/'trajectory/original',cold/'original',metadata(project),4,7,project.start_date),seconds=seconds)
  complete_inverse();assert git('rev-parse','HEAD').decode().strip()==head
  q['status']='ACTUAL_CURRENT_NATIVE_NO_VAPOR_GUARD_COMPLETE_SOURCE_COMPILED_WARM4_COLD4_7_PHYSICAL_NATIVE_USER_OUTPUT_BRIDGE_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:q.update(actual_completion_head=git('rev-parse','HEAD').decode().strip(),seconds=time.monotonic()-start);save()
 print(q['status'],q['layer_models'],q['kind'],q['optimization'],q['seconds'],flush=True)


if __name__=='__main__':main()
