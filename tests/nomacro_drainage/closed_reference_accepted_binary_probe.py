"""Exact existing output correction on original SDK, with explicit source roles."""
from pathlib import Path
from contextlib import ExitStack
import argparse,hashlib,importlib.util,json,os,struct,subprocess,time
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource

R=Path(__file__).resolve().parents[2]
J=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
M='bd9b3b2e74e93fccb8bbcc8b06822efcd740f349'
CASES=['original-model3-snow9-control-stack64-v1','gardner-snow-paired9-explicit-water','gardner-mixed2-1-snow-paired9-explicit-cde']
SHA=lambda b:hashlib.sha256(b).hexdigest()


def main():
 p=argparse.ArgumentParser();p.add_argument('--build-O0',type=Path,required=True);p.add_argument('--build-O2',type=Path,required=True);p.add_argument('--caller-O0',type=Path,required=True);p.add_argument('--caller-O2',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--full-period',action='store_true');a=p.parse_args()
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','--ignored'],cwd=R)
 prepared=json.loads((J/'PREPARED.json').read_bytes())
 assert SHA((J/'PREPARED.json').read_bytes())=='a2f529bc5d69c9e15bdda4c7aeb643a48685b50e10c2c1fce9eb639faf8a2da5'
 for n,d in prepared['provider_files'].items():assert SHA((J/n).read_bytes())==d,n
 patch=R/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py'
 for n in ['source.py','manifest.json']:
  f=patch.with_name(n);assert f.read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',M+':'+f.relative_to(R).as_posix()],cwd=R)
 spec=importlib.util.spec_from_file_location('explicit_accepted_original_binary_correction',patch);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
 original=(J/'build/swap-selected/swap_csv_output.f90').read_bytes();corrected=module.source(original)
 anchor=b'      else if (swcsv == 3) then ! binary\r\n         ! datetime';replacement=anchor.replace(b'         ! datetime',b'         allocate(buffer(parlen-1))\r\n         ! datetime')
 assert original.count(anchor)==1 and original.replace(anchor,replacement)==corrected
 compiler=Path('C:/msys64/ucrt64/bin/gfortran.exe');assert SHA(compiler.read_bytes())==prepared['toolchain']['gfortran']['sha256']
 obj=J/'build/swap-obj';lib=J/'build/ttutil-obj/libttutil.a';objects=sorted(obj.glob('*.o'))
 stage='full-period' if a.full_period else 'zero-day';report_path=a.output/(stage+'-RESULT.json')
 assert not report_path.exists();a.output.mkdir(exist_ok=True)
 q=dict(status='RUNNING_EXPLICIT_EXISTING_BINARY_CORRECTED_ORIGINAL_SDK_'+stage,actual_controller_source=head,canonical=M,original_SDK_mixed_profiles=True,qualified_B1_snapshot=False,existing_correction='NOMACRO-BINARY-OUTPUT-01',exact_component_introduction_commit='395866169da009fc3dd5ed5ff53a4f29e201f2db',original_csv_sha256=SHA(original),corrected_csv_sha256=SHA(corrected),patch_source_sha256=SHA(patch.read_bytes()),compiler_executions=0,link_executions=0,commands=[],observations=[],scientific_causality='UNKNOWN',original_failure_roles_relabelled=False)
 def save():report_path.write_text(json.dumps(q,indent=2)+'\n')
 def cmd(command,build,kind):
  start=time.perf_counter();child=subprocess.run(list(map(str,command)),cwd=build,capture_output=True,timeout=45);i=str(len(q['commands']));(build/(i+'.stdout')).write_bytes(child.stdout);(build/(i+'.stderr')).write_bytes(child.stderr)
  q['commands'].append(dict(command=list(map(str,command)),returncode=child.returncode,seconds=time.perf_counter()-start,kind=kind));q[kind+'_executions']+=1;save();child.check_returncode()
 save()
 zero=json.loads((a.output/'zero-day-RESULT.json').read_text()) if a.full_period else None
 if zero:assert zero['status']=='SIX_EXACT_EXISTING_BINARY_COMPONENT_ZERO_DAY_LIFECYCLE_CONTROLS_PASS' and len(zero['observations'])==6
 for opt,build,caller in [('O0',a.build_O0,a.caller_O0),('O2',a.build_O2,a.caller_O2)]:
  if not a.full_period:
   assert build.exists() and not list(build.iterdir());(build/'swap_csv_output.f90').write_bytes(corrected)
   (build/'reference_task1.f90').write_bytes((caller/'reference_task1.f90').read_bytes());(build/'reference_task1.o').write_bytes((caller/'reference_task1.o').read_bytes())
   flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*prepared['floating_point_profile']['flags'],'-I'+str(obj),'-I'+str(J/'build/ttutil-obj')]
   cmd([compiler,*flags,'-c','swap_csv_output.f90'],build,'compiler')
   for mode in ['zero-day','full-period']:
    closure=[build/'swap_csv_output.o' if x.name=='swap_csv_output.o' else build/'reference_task1.o' if mode=='zero-day' and x.name=='swap_main.o' else x for x in objects]
    cmd([compiler,'-o',build/(mode+'.exe'),*closure,lib],build,'link')
  else:
   assert (build/'swap_csv_output.f90').read_bytes()==corrected
   old=next(v for v in zero['builds'] if v['optimization']==opt)
   for n,d in old['build_files'].items():assert SHA((build/n).read_bytes())==d
 q['builds']=[dict(optimization=opt,build_files={f.name:SHA(f.read_bytes()) for f in build.iterdir() if f.is_file()}) for opt,build in [('O0',a.build_O0),('O2',a.build_O2)]];save()
 with ExitStack() as stack:
  store=Archive(GitArchiveSource(R,M),'CLOSED_GARDNER_STATE12_REPAIRED_LOCAL_AND_POSTIMAGES_RAW_V1',stack)
  assert store.record['sha256']=='280f57ca5554a5bcd746fa3cb56460da35c668952b52f64e267d6c7aba6a8089'
  original_observation=json.loads(store.get('actual/closure12-original-causal-v1/RESULT.json'));inputs={v['case']:v['identical_input_inventory'] for v in original_observation['cases']}
  # Both model3 controls are prerequisites to Gardner full-period observations.
  for case in CASES:
   for opt,build in [('O0',a.build_O0),('O2',a.build_O2)]:
    root=a.output/(stage+'-'+opt+'-'+case);root.mkdir();prefix='actual/closure12-original-causal-v1/'+case+'/'
    inventory={}
    for name,d in inputs.get(case,inputs[CASES[1]]).items():
     raw=store.get(prefix+name)
     if case!=CASES[0] or name!='swap.swp':assert SHA(raw)==d
     dest=root/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw);inventory[name]=SHA(raw)
    exe=build/(stage+'.exe');start=time.perf_counter()
    try:
     child=subprocess.run([str(exe),'./swap.swp'],cwd=root,capture_output=True,timeout=30 if a.full_period else 15);rc=child.returncode;out=child.stdout;err=child.stderr;censored=False
    except subprocess.TimeoutExpired as failure:rc=None;out=failure.stdout or b'';err=failure.stderr or b'';censored=True
    (root/'stdout.txt').write_bytes(out);(root/'stderr.txt').write_bytes(err)
    item=dict(case=case,optimization=opt,actual_observer=head,actual_root=str(root),returncode=rc,censored=censored,seconds=time.perf_counter()-start,executable_sha256=SHA(exe.read_bytes()),input_inventory=inventory,model_dynamic_tasks=1 if a.full_period else 0)
    q['observations'].append(item);save()
    if not a.full_period:
     assert rc==0 and b'REFERENCE_BINARY_LIFECYCLE_ZERO_DYNAMIC_DAYS_COMPLETE' in out,err
     first=(root/'first-output.bin').read_bytes();second=(root/'second-output.bin').read_bytes();parlen=struct.unpack_from('<4i',second,400)[3];length=19+4*(parlen-1)
     assert len(first)-len(second)==length and first[-2*length:]==second[-2*length:] and second[-2*length:-length]==second[-length:]
     item.update(binary_record_bytes=length,unchanged_state_repeated_records_exact=True,close_reopen_records_exact=True)
    else:
     item['original_normal_completion_marker']=b'Swap normal completion!' in out
     item['nonfinite_or_error_diagnostics']={f.name:[l.decode('cp1252',errors='replace') for l in f.read_bytes().splitlines() if any(x in l.lower() for x in [b'error',b'nan',b'infinity',b'no convergence'])][-30:] for f in root.iterdir() if f.suffix.lower() in ['.err','.log','.bal','.blc']}
     if case==CASES[0] and (censored or rc!=100 or not item['original_normal_completion_marker']):
      q['status']='CORRECTED_REFERENCE_MODEL3_FULL_CONTROL_NOT_PASSED_GARDNER_NOT_EXECUTED';save();print(q['status'],opt,rc,censored,flush=True);return
    for name,d in inventory.items():assert SHA((root/name).read_bytes())==d
    save();print(stage,opt,case,rc,censored,flush=True)
 for n,d in prepared['provider_files'].items():assert SHA((J/n).read_bytes())==d,n
 q['status']='SIX_EXISTING_BINARY_CORRECTED_ORIGINAL_FULL_PERIOD_CAUSAL_OBSERVATIONS_RETAINED_NOT_B1_ADMISSION' if a.full_period else 'SIX_EXACT_EXISTING_BINARY_COMPONENT_ZERO_DAY_LIFECYCLE_CONTROLS_PASS';save()


if __name__=='__main__':main()
