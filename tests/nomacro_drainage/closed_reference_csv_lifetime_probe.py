"""Preregistered zero-day original SDK diagnosis; never qualifies B0/B1 science."""
from pathlib import Path
from contextlib import ExitStack
import argparse,hashlib,json,os,struct,subprocess,time
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource

R=Path(__file__).resolve().parents[2]
J=Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider')
CANONICAL='bd9b3b2e74e93fccb8bbcc8b06822efcd740f349'
CASES=['original-model3-snow9-control-stack64-v1','gardner-snow-paired9-explicit-water','gardner-mixed2-1-snow-paired9-explicit-cde']
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
    p=argparse.ArgumentParser();p.add_argument('--build-O0',type=Path,required=True);p.add_argument('--build-O2',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    assert not a.output.exists();a.output.mkdir()
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','--ignored'],cwd=R)
    report=dict(status='RUNNING_ZERO_DAY_ORIGINAL_BINARY_BUFFER_DIAGNOSIS',actual_controller_source=head,canonical=CANONICAL,compiler_executions=0,link_executions=0,model_dynamic_tasks=0,original_mixed_SDK=True,all_O0_original_SDK_claimed=False,qualified_B1=False,scientific_causality='UNKNOWN',commands=[],observations=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    prepared_raw=(J/'PREPARED.json').read_bytes();prepared=json.loads(prepared_raw)
    assert SHA(prepared_raw)=='a2f529bc5d69c9e15bdda4c7aeb643a48685b50e10c2c1fce9eb639faf8a2da5'
    for name,digest in prepared['provider_files'].items():assert SHA((J/name).read_bytes())==digest,name
    compiler=Path('C:/msys64/ucrt64/bin/gfortran.exe');assert SHA(compiler.read_bytes())==prepared['toolchain']['gfortran']['sha256']
    source=J/'build/swap-selected';obj=J/'build/swap-obj';lib=J/'build/ttutil-obj/libttutil.a'
    objects=sorted(obj.glob('*.o'));assert any(x.name=='swap_main.o' for x in objects)
    original=(source/'swap_csv_output.f90').read_bytes();needle=b'real(4),      allocatable               :: buffer(:)'
    assert original.count(needle)==1
    corrected=original.replace(needle,b'real(4),      allocatable, save         :: buffer(:)')
    close=b'      close (unit=iuncsv)';assert corrected.count(close)==1
    corrected=corrected.replace(close,close+b'\r\n      if (allocated(buffer)) deallocate(buffer)')
    assert corrected.replace(b'real(4),      allocatable, save         :: buffer(:)',needle).replace(close+b'\r\n      if (allocated(buffer)) deallocate(buffer)',close)==original
    report['original_csv_sha256']=SHA(original);report['candidate_csv_sha256']=SHA(corrected)
    raw=(source/'swap_main.f90').read_text(encoding='cp1252')
    driver=raw[:raw.index('!  Dynamic call to swap')]
    driver=driver.replace('use MOD_swap_base, only: unit_log, unit_wrn, sw_animo','use MOD_swap_base, only: unit_log, unit_wrn, sw_animo, pathwork\nuse Variables, only: outfil\nuse SWAP_csv_output, only: csv_out')
    driver+='''write(*,'(a)') 'REFERENCE_TASK1_INITIALIZED_ZERO_DYNAMIC_DAYS'
call csv_out(2)
call csv_out(2)
call csv_out(3)
call copy_binary(trim(pathwork)//trim(outfil)//'_output.bin','first-output.bin')
call csv_out(1)
call csv_out(2)
call csv_out(2)
call csv_out(3)
call copy_binary(trim(pathwork)//trim(outfil)//'_output.bin','second-output.bin')
end do
call CloseTempFil
write(*,'(a)') 'REFERENCE_BINARY_LIFECYCLE_ZERO_DYNAMIC_DAYS_COMPLETE'
stop
contains
subroutine copy_binary(src,dest)
character(len=*),intent(in)::src,dest
character(len=1),allocatable::bytes(:)
integer::n,iu,ou
inquire(file=src,size=n)
allocate(bytes(n))
open(newunit=iu,file=src,access='stream',form='unformatted',status='old')
read(iu)bytes
close(iu)
open(newunit=ou,file=dest,access='stream',form='unformatted',status='new')
write(ou)bytes
close(ou)
end subroutine copy_binary
end program swap_main
'''
    assert 'iTask = 2' not in driver and 'iTask = 3' not in driver
    def command(cmd,cwd,kind):
        start=time.perf_counter();child=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=45)
        tag=str(len(report['commands']));(cwd/(tag+'.stdout')).write_bytes(child.stdout);(cwd/(tag+'.stderr')).write_bytes(child.stderr)
        report['commands'].append(dict(command=list(map(str,cmd)),returncode=child.returncode,seconds=time.perf_counter()-start,kind=kind));report[kind+'_executions']+=1;save();child.check_returncode()
    executables=[]
    for opt,build in [('O0',a.build_O0),('O2',a.build_O2)]:
        build.mkdir(exist_ok=True);assert not list(build.iterdir())
        (build/'reference_task1.f90').write_text(driver,encoding='cp1252');(build/'swap_csv_output.f90').write_bytes(corrected)
        flags=['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch',*prepared['floating_point_profile']['flags'],'-I'+str(obj),'-I'+str(J/'build/ttutil-obj')]
        for name in ['reference_task1','swap_csv_output']:command([str(compiler),*flags,'-c',name+'.f90'],build,'compiler')
        baseline=build/'original-buffer.exe';candidate=build/'candidate-buffer.exe'
        for mode,exe in [('original',baseline),('candidate',candidate)]:
            closure=[str(build/'reference_task1.o')]+[str(build/'swap_csv_output.o') if mode=='candidate' and x.name=='swap_csv_output.o' else str(x) for x in objects if x.name!='swap_main.o']
            command([str(compiler),'-o',str(exe),*closure,str(lib)],build,'link')
            executables.append((opt,mode,exe))
    with ExitStack() as stack:
        store=Archive(GitArchiveSource(R,CANONICAL),'CLOSED_GARDNER_STATE12_REPAIRED_LOCAL_AND_POSTIMAGES_RAW_V1',stack)
        assert store.record['sha256']=='280f57ca5554a5bcd746fa3cb56460da35c668952b52f64e267d6c7aba6a8089'
        for opt,mode,exe in executables:
            for case in CASES:
                root=a.output/(opt+'-'+mode+'-'+case);root.mkdir();prefix='actual/closure12-original-causal-v1/'+case+'/'
                inventory={}
                # The original failed observation's input inventory is explicit for Gardner;
                # all four accepted input file extensions are copied for the positive control.
                for name in store.names:
                    if not name.startswith(prefix):continue
                    relative=name[len(prefix):]
                    if Path(relative).suffix.lower() not in ['.swp','.met','.crp','.bbc','.dra','.inp']:continue
                    raw=store.get(name);dest=root/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw);inventory[relative]=SHA(raw)
                assert 'swap.swp' in inventory
                start=time.perf_counter();child=subprocess.run([str(exe),'./swap.swp'],cwd=root,capture_output=True,timeout=15)
                (root/'stdout.txt').write_bytes(child.stdout);(root/'stderr.txt').write_bytes(child.stderr)
                item=dict(optimization=opt,mode=mode,case=case,command=[str(exe),'./swap.swp'],executable_sha256=SHA(exe.read_bytes()),returncode=child.returncode,seconds=time.perf_counter()-start,input_inventory=inventory,task1_completed=b'REFERENCE_TASK1_INITIALIZED_ZERO_DYNAMIC_DAYS' in child.stdout,lifecycle_completed=b'REFERENCE_BINARY_LIFECYCLE_ZERO_DYNAMIC_DAYS_COMPLETE' in child.stdout)
                report['observations'].append(item);save()
                if mode=='original':assert child.returncode!=0 and not item['task1_completed']
                else:
                    assert child.returncode==0 and item['task1_completed'] and item['lifecycle_completed'],child.stderr
                    first=(root/'first-output.bin').read_bytes();second=(root/'second-output.bin').read_bytes();parlen=struct.unpack_from('<4i',second)[3];record=19+4*(parlen-1)
                    assert len(first)-len(second)==record and first[-2*record:]==second[-2*record:] and second[-2*record:-record]==second[-record:]
                    item['binary_record_bytes']=record;item['unchanged_state_repeated_records_exact']=True;item['close_reopen_records_exact']=True;item['first_binary_sha256']=SHA(first);item['second_binary_sha256']=SHA(second);save()
                for name,digest in inventory.items():assert SHA((root/name).read_bytes())==digest
                print(opt,mode,case,child.returncode,item['task1_completed'],item['lifecycle_completed'],flush=True)
    for name,digest in prepared['provider_files'].items():assert SHA((J/name).read_bytes())==digest
    report.update(status='ZERO_DAY_ORIGINAL_BINARY_LIFETIME_DEFECT_REPRODUCED_CANDIDATE_CONTROL_PASS_NOT_B1_QUALIFIED',unchanged_original_SDK_objects={x.name:SHA(x.read_bytes()) for x in objects if x.name not in ['swap_main.o','swap_csv_output.o']},full_period_Gardner_Snow_causality='UNKNOWN',original_failures_relabelled=False)
    save()


if __name__=='__main__':main()
