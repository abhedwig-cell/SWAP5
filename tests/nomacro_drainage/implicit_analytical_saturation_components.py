"""Real original parameter/curve branch controls; no forward model period."""
import argparse,hashlib,json,math,re,shutil,struct,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from implicit_saturation_derivative import source as preceding_source
from implicit_analytical_saturation import source as current_source
from original_output_baseline import assignment
SHA=lambda b:hashlib.sha256(b).hexdigest()


def main():
 p=argparse.ArgumentParser()
 for n in ['output','build-root','reference-work','original-profile','node-trace']:p.add_argument('--'+n,type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args();a.output.mkdir()
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all'],cwd=R)
 q=json.loads((a.original_profile/'RESULT.json').read_text());meta=json.loads((Path(q['build_root'])/'BUILD.json').read_text());accepted=json.loads((a.original_profile/'trajectory/daily.jsonl').read_text().splitlines()[3])['pressure_head_cm']
 lines=[line.split() for line in a.node_trace.read_text().splitlines() if line.lstrip().startswith('IH11_PDI_NODE ')];trial=lines[:34];assert [int(v[2]) for v in trial]==list(range(1,35));failed=[float(v[5]) for v in trial]
 queries=[*(list(enumerate(accepted,1))),*(list(enumerate(failed,1))),*(list(enumerate([0.0]*34,1)))]
 query_bytes=('\n'.join(str(i)+' '+repr(h) for i,h in queries)+'\n').encode();original=(a.reference_work/'build/swap-selected/MOD_MvG_functions.f90').read_bytes().decode('cp1252').replace('\r\n','\n');before=preceding_source(original);after=current_source(before)
 # Entire original physical functions and parameter/init declarations remain
 # literal; only the pre-existing dhconduc constant-region block changes.
 low=before.index('      real(8) function dhconduc');high=before.index('      end function dhconduc',low)+len('      end function dhconduc')
 assert before[:low]==after[:low] and before[high:]==after[after.index('      end function dhconduc',low)+len('      end function dhconduc'):]
 objects=sorted(f for f in (a.reference_work/'build/swap-obj').glob('*.o') if f.name!='swap_main.o');ttutil=a.reference_work/'build/ttutil-obj/libttutil.a';driver=Path(__file__).with_name('implicit_analytical_saturation_probe.f90');result=dict(status='RUNNING_REAL_ORIGINAL_MODEL_BRANCH_COMPONENTS',actual_compiler_source=head,original_scientific_input_source=q['actual_source'],optimization=a.optimization,model_days=0,forward_model_executions=0,new_soil_parameter_values=False,query_heads='Actual accepted day4, actual nonconverged iteration99 node vectors, and the original h=0 mathematical branch boundary; all query locals, no simulation head assignment',query_sha256=SHA(query_bytes),original_parameter_input_sha256=SHA((Path(q['input_root'])/'swap.swp').read_bytes()),original_library_sha256=SHA(ttutil.read_bytes()),original_objects={f.name:SHA(f.read_bytes()) for f in objects},driver_sha256=SHA(driver.read_bytes()),physical_function_source_bytes_unchanged=True,component_capacity_owner='Actual original SDK; this checks ONLY the constant-region derivative composition, not full model7 capacity qualification. Public model7 still selects its separately qualified capacity owner.',variants={},controls=[])
 save=lambda:(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
 save()
 try:
  data={}
  for variant,text in [('original43',original),('preceding',before),('per-model',after)]:
   root=a.build_root/variant;root.mkdir();path=root/'MOD_MvG_functions.f90';path.write_text(text,encoding='cp1252');exe=root/'actual_branch_probe.exe';flags=['C:/msys64/ucrt64/bin/gfortran.exe','-'+a.optimization,'-ffree-line-length-none','-ffp-contract=off','-I',str(root),'-I',str(a.reference_work/'build/swap-obj'),'-I',str(a.reference_work/'build/ttutil-obj')];linked=[root/'MOD_MvG_functions.o' if f.name=='MOD_MvG_functions.o' else f for f in objects]
   commands=[flags+['-c',str(path),'-o','MOD_MvG_functions.o'],flags+[str(driver),*map(str,linked),str(ttutil),'-o',str(exe)]]
   log=a.output/variant;log.mkdir()
   for i,command in enumerate(commands):
    with (log/('compile-'+str(i)+'.stdout')).open('xb') as out,(log/('compile-'+str(i)+'.stderr')).open('xb') as err:child=subprocess.run(command,cwd=root,stdout=out,stderr=err,timeout=90)
    child.check_returncode()
   result['variants'][variant]=dict(actual_source_sha256=SHA(path.read_bytes()),actual_executable_sha256=SHA(exe.read_bytes()),actual_object_sha256=SHA((root/'MOD_MvG_functions.o').read_bytes()),compiler_commands=commands);save()
   for model in range(1,12):
    worker=log/('model-'+str(model));shutil.copytree(Path(q['input_root']),worker);control=worker/'swap.swp';text=control.read_text(encoding='cp1252');control.write_text(assignment(text,'iHWCKmodel',str(model)),encoding='cp1252')
    # Original model3's valid oxygen1 control is explicit; no forward root or
    # weather/flux model is executed by this mathematical component.
    if model==3:
     for crop in worker.glob('*.crp'):crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWOXYGEN',1),encoding='cp1252')
    (worker/'mathematical-head-queries.txt').write_bytes(query_bytes)
    with (log/('model-'+str(model)+'.stdout')).open('xb') as out,(log/('model-'+str(model)+'.stderr')).open('xb') as err:child=subprocess.run([str(exe)],cwd=worker,stdout=out,stderr=err,timeout=30)
    raw=(log/('model-'+str(model)+'.stdout')).read_bytes();assert child.returncode==0 and b'ACTUAL_BRANCH_QUERIES_COMPLETE_ZERO_MODEL_DAYS' in raw
    observed=[]
    for line in raw.decode().splitlines():
     if not line.startswith('ACTUAL_BRANCH_QUERY '):continue
     fields=line.split();values=list(map(float,fields[4:]));assert len(values)==11 and all(map(math.isfinite,values));observed.append(dict(node=int(fields[1]),layer=int(fields[2]),model=int(fields[3]),values=values))
    assert len(observed)==102 and all(v['model']==model for v in observed);data[variant,model]=observed
  for model in range(1,12):
   old=data['preceding',model];new=data['per-model',model]
   for left,right in zip(old,new):
    assert left['node']==right['node'] and left['model']==right['model'] and left['values'][:4]==right['values'][:4] and left['values'][5:]==right['values'][5:]
   if model in (1,2):assert old==new
   if model>=3:assert all(row['values'][4]==0.0 for row in new[68:])
   result['controls'].append(dict(model=model,queries=102,physical_water_capacity_K_and_stencils_bit_identical=True,default_model1_or_Gardner2_derivative_bit_identical=(old==new) if model in (1,2) else None,original_h0_constant_branch_zero=True if model>=3 else None));save()
  old=data['preceding',11][34+20];new=data['per-model',11][34+20];legacy=data['original43',11][34+20]
  assert old['values'][0]==failed[20] and old['values'][4]==0.0 and new['values'][4]==legacy['values'][4]>0
  result['actual_regression_witness']=dict(model=11,node=21,head=failed[20],preceding_derivative=old['values'][4],corrected_original_nonconstant_derivative=new['values'][4],original43_derivative=legacy['values'][4],physical_K=new['values'][3],independent_finite_difference_K=new['values'][7],half_stencil_K=new['values'][8])
  result.update(status='REAL_SELECTED_PROFILE_ORIGINAL_MODEL_BRANCH_COMPONENT_PASS_PHYSICAL_FUNCTIONS_AND_MODEL1_2_UNCHANGED',query_rows=3*11*102,full_model_periods_replayed=0)
 except Exception as error:result.update(status='FAILED_REAL_ORIGINAL_MODEL_BRANCH_COMPONENTS',error=repr(error));raise
 finally:save()
 print(result['status'],a.optimization,result.get('query_rows'),flush=True)


if __name__=='__main__':main()
