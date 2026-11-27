"""Real original private module seam; technical states are not scientific inputs."""
from pathlib import Path
import argparse,hashlib,json,os,struct,subprocess,sys,time
R=Path(__file__).resolve().parents[2];sys.path.insert(0,str(R/'app/hybrid_water'))
import original_tillage_checkpoint as seam
J=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
SHA=lambda b:hashlib.sha256(b).hexdigest()


def driver():
 lines=['program test_original_tillage_state','use MOD_tillage','use MOD_swap_base, only: swtill',
        'use MOD_grid, only: NumLay, NumNod','use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan',
        'implicit none','type('+seam.TYPE+') :: a,b,c,bad','logical :: ok','integer :: i,model,unit',
        'character(len=20) :: mode','character(len=1024) :: filename',
        '! Technical state vectors only: no project, weather, physical timestep or density input.',
        'NumLay=2; NumNod=2; swtill=1','a%Ntill=2; a%iTill=2; a%Ntypes=2; a%i_n_model=3; a%iRedist=2',
        'a%MaxNumSoilHo=2; a%MaxNumSoilCP=2; a%Max_Z_tillage=2d0']
 for name,size in seam.INTEGER_ARRAYS.items():lines.append('a%'+name+' = [1,2]')
 for name,size in {**seam.REAL_ARRAYS,**seam.MATCH_ARRAYS}.items():
  lines.append('a%'+name+' = [(dble(i),i=1,a%'+size+')]')
 lines += ['call get_command_argument(1,mode)','call get_command_argument(2,filename)',
           "if(trim(mode)=='cold')then",
           "open(newunit=unit,file=trim(filename),access='stream',form='unformatted',status='old')",
           "call hybrid_tillage_read_post_event(unit,repeat('a',64),bad,ok)",
           'close(unit)','if(.not.ok)error stop "Cold native read refused"',
           'call hybrid_tillage_restore_post_event(bad,ok)','if(.not.ok)error stop "Cold restore refused"',
           'call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Cold capture refused"',
           'call identical(a,c)',"write(*,'(a)')'ORIGINAL_PRIVATE_TILLAGE_COLD_STATE_EXACT'",'stop','end if',
           'call hybrid_tillage_restore_post_event(a,ok)','if(.not.ok)error stop "Valid technical post-event state refused"',
           "if(trim(mode)=='cold_reject')then",
           "open(newunit=unit,file=trim(filename),access='stream',form='unformatted',status='old')",
           "call hybrid_tillage_read_post_event(unit,repeat('a',64),bad,ok)",
           'close(unit)','if(ok)error stop "Corrupt native read accepted"',
           'call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Rejected read damaged private state"',
           'call identical(a,c)',"write(*,'(a)')'ORIGINAL_PRIVATE_TILLAGE_COLD_CORRUPTION_REFUSED_NO_MUTATION'",'stop','end if',
           'a%Date_tillage(1)=99d0',
           'call hybrid_tillage_capture_post_event(b,ok)','if(.not.ok.or.b%Date_tillage(1)/=1d0)error stop "Caller aliases private saved state"',
           'a=b','a%Rho_cons(1)=123d0',
           'call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Capture refused"','call identical(b,c)',
           'bad=b; bad%schema=2','call refuse_without_mutation(bad,b)',
           'bad=b; bad%iTill=1','call refuse_without_mutation(bad,b)',
           'bad=b; bad%Date_tillage=[1d0]','call refuse_without_mutation(bad,b)',
           'bad=b; bad%Rho_cons(1)=ieee_value(0d0,ieee_quiet_nan)','call refuse_without_mutation(bad,b)',
           'swtill=0','call hybrid_tillage_capture_post_event(c,ok)','if(ok)error stop "Inactive capture accepted"',
           'call hybrid_tillage_restore_post_event(b,ok)','if(ok)error stop "Inactive restore accepted"',
           'swtill=1','call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Active state lost"','call identical(b,c)',
           'do model=1,2','a=b; a%i_n_model=model']
 for name in seam.MATCH_ARRAYS:lines.append('deallocate(a%'+name+')')
 lines += ['call hybrid_tillage_restore_post_event(a,ok)','if(.not.ok)error stop "Inactive matching arrays required"',
           'call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Matching-free state capture refused"']
 for name in seam.MATCH_ARRAYS:lines.append('if(allocated(c%'+name+'))error stop "Undefined inactive matching state serialized"')
 lines += ['end do','call hybrid_tillage_restore_post_event(b,ok)','if(.not.ok)error stop "Rollback refused"',
           'call hybrid_tillage_capture_post_event(c,ok)','if(.not.ok)error stop "Rollback capture refused"','call identical(b,c)',
           "open(newunit=unit,file='state.bin',access='stream',form='unformatted',status='new')",
           "call hybrid_tillage_write_post_event(unit,repeat('a',64),b,ok)",
           'close(unit)','if(.not.ok)error stop "Native write refused"',
           'write(*,\'(a)\')"ORIGINAL_PRIVATE_TILLAGE_POST_EVENT_TECHNICAL_STATE_PASS"','contains',
           'subroutine refuse_without_mutation(incoming,previous)','type('+seam.TYPE+'),intent(in)::incoming,previous',
           'type('+seam.TYPE+')::actual','logical::accepted',
           'call hybrid_tillage_restore_post_event(incoming,accepted)','if(accepted)error stop "Invalid technical native accepted"',
           'call hybrid_tillage_capture_post_event(actual,accepted)','if(.not.accepted)error stop "Rejected restore damaged state"',
           'call identical(previous,actual)','end subroutine',
           'subroutine identical(x,y)','type('+seam.TYPE+'),intent(in)::x,y']
 for name in seam.INTEGERS+('Max_Z_tillage',):lines.append('if(x%'+name+'/=y%'+name+')error stop "Changed private scalar '+name+'"')
 for name in {**seam.INTEGER_ARRAYS,**seam.REAL_ARRAYS,**seam.MATCH_ARRAYS}:
  lines.append('if(any(x%'+name+'/=y%'+name+'))error stop "Changed private array '+name+'"')
 return '\n'.join(lines+['end subroutine','end program'])+'\n'


def main():
 p=argparse.ArgumentParser();p.add_argument('--build-O0',type=Path,required=True);p.add_argument('--build-O2',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','--ignored'],cwd=R)
 assert not a.output.exists();a.output.mkdir()
 q=dict(status='RUNNING_ORIGINAL_PRIVATE_TILLAGE_STATE_COMPONENT_NOT_PHYSICAL_QUALIFICATION',actual_compiler_source=head,actual_generator_sha256=SHA(Path(seam.__file__).read_bytes()),new_reader_admission=False,full_tillage_functionality_qualified=False,scientific_input_invented=False,technical_state_vectors_are_not_physical_parameters=True,original_physical_routines_modified=False,model_executions=0,model_days=0,compiler_executions=0,link_executions=0,contexts=[])
 def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save();prepared=json.loads((J/'PREPARED.json').read_text())
 for n,d in prepared['provider_files'].items():assert SHA((J/n).read_bytes())==d
 original=(J/'build/swap-selected/tillage.f90').read_bytes();patched=seam.source(original);assert SHA(original)==seam.ORIGINAL_SHA
 compiler=Path('C:/msys64/ucrt64/bin/gfortran.exe');assert SHA(compiler.read_bytes())==prepared['toolchain']['gfortran']['sha256']
 for opt,build in [('O0',a.build_O0),('O2',a.build_O2)]:
  assert build.exists() and not list(build.iterdir());(build/'tillage.f90').write_bytes(patched);(build/'technical_driver.f90').write_text(driver())
  commands=[]
  flags=['-'+opt,'-fcheck=all','-ffree-line-length-none','-ffp-contract=off','-march=x86-64','-mtune=generic','-I.','-I'+str(J/'build/swap-obj'),'-I'+str(J/'build/ttutil-obj')]
  def run(cmd,kind):
   start=time.perf_counter();child=subprocess.run(list(map(str,cmd)),cwd=build,capture_output=True,timeout=45);tag=str(len(commands));(build/(tag+'.stdout')).write_bytes(child.stdout);(build/(tag+'.stderr')).write_bytes(child.stderr)
   commands.append(dict(command=list(map(str,cmd)),returncode=child.returncode,seconds=time.perf_counter()-start,kind=kind));q[kind+'_executions']=q.get(kind+'_executions',0)+1;save();child.check_returncode();return child
  run([compiler,*flags,'-c','tillage.f90'],'compiler');run([compiler,*flags,'-c','technical_driver.f90'],'compiler')
  objects=[build/'tillage.o' if f.name=='tillage.o' else f for f in sorted((J/'build/swap-obj').glob('*.o')) if f.name!='swap_main.o']
  exe=build/'technical-state.exe';run([compiler,'-fcheck=all','-o',exe,build/'technical_driver.o',*objects,J/'build/ttutil-obj/libttutil.a'],'link')
  child=run([exe],'technical_process');assert b'ORIGINAL_PRIVATE_TILLAGE_POST_EVENT_TECHNICAL_STATE_PASS' in child.stdout
  child=run([exe,'cold',build/'state.bin'],'technical_cold_process');assert b'ORIGINAL_PRIVATE_TILLAGE_COLD_STATE_EXACT' in child.stdout
  raw=(build/'state.bin').read_bytes();assert raw[:8]==b'SW5TIL01' and raw[8:72].decode()==seam.ORIGINAL_SHA and raw[72:136]==b'a'*64
  controls={'magic':b'X'+raw[1:],'source':raw[:8]+b'0'+raw[9:],'binding':raw[:72]+b'b'+raw[73:],'schema':raw[:136]+struct.pack('<i',2)+raw[140:],'allocation_bound':raw[:140]+struct.pack('<i',2147483647)+raw[144:],'nonfinite':raw[:168]+struct.pack('<d',float('nan'))+raw[176:],'truncated':raw[:-1],'trailer':raw+b'X'}
  for name,poison in controls.items():
   path=build/(name+'.bin');path.write_bytes(poison);child=run([exe,'cold_reject',path],'technical_negative_process');assert b'ORIGINAL_PRIVATE_TILLAGE_COLD_CORRUPTION_REFUSED_NO_MUTATION' in child.stdout
  q['contexts'].append(dict(optimization=opt,commands=commands,actual_source=head,original_source_sha256=SHA(original),generated_source_sha256=SHA(patched),executable_sha256=SHA(exe.read_bytes()),unchanged_original_objects={f.name:SHA(f.read_bytes()) for f in objects if f.parent!=build},deep_copy_and_failed_restore_no_mutation=True,undefined_inactive_matching_arrays_not_read_or_serialized=True,exact_cold_technical_state=True,actual_original_native_sha256=SHA(raw),actual_cold_corruption_refusals={name:SHA(value) for name,value in controls.items()},original_physical_timestep_calls=0));save();print(opt,'ORIGINAL_PRIVATE_STATE_COMPONENT_PASS_NO_PHYSICAL_TRAJECTORY',flush=True)
 q['status']='TWO_REAL_ORIGINAL_PRIVATE_TILLAGE_POST_EVENT_COMPONENTS_PASS_PHYSICAL_QUALIFICATION_PENDING';save()


if __name__=='__main__':main()
