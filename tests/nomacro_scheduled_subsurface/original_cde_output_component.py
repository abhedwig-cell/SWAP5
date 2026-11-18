"""Defined daily CDE output state against actual original module storage."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
FIELDS='samini,sqprec,sqirrig,sqbot,dectot,rottot,sqdra,imsqbot,imsqdra,imsqirrig,imsqprec,imdectot,imrottot,sbaldev,sdstor,isqtop,isqbot'
DRIVER='''program component
use iso_fortran_env,only:int64
use MOD_grid,only:numnod
use MOD_solute,only:FIELDS,imqsol
use variables,only:flzerointr
use hybrid_original_cde_output_state
implicit none
character(500)::path,mode
real(8)::before(21),after(21)
integer::u,i
call get_command_argument(1,mode);call get_command_argument(2,path)
numnod=3;flzerointr=.true.
call assign(2d0)
if(trim(mode)=='write')then
 open(newunit=u,file=trim(path),access='stream',form='unformatted',status='new')
 call hybrid_cde_output_checkpoint(u,.false.);close(u)
else
 call assign(5d0);call snapshot(before)
 open(newunit=u,file=trim(path),access='stream',form='unformatted',status='old')
 call hybrid_cde_output_checkpoint(u,.true.);close(u)
 call snapshot(after)
 if(any(transfer(before,0_int64,21)/=transfer(after,0_int64,21)))error stop 'Read mutated live CDE state'
 select case(trim(mode))
 case('pending-read')
  open(newunit=u,file=trim(path),access='stream',form='unformatted',status='old')
  call hybrid_cde_output_checkpoint(u,.true.)
 case('pending-write')
  open(newunit=u,status='scratch',access='stream',form='unformatted')
  call hybrid_cde_output_checkpoint(u,.false.)
 case('reset')
  flzerointr=.false.
 case('shape')
  numnod=4
 end select
 call hybrid_cde_output_apply();call snapshot(after)
 call assign(2d0);call snapshot(before)
 if(any(transfer(before,0_int64,21)/=transfer(after,0_int64,21)))error stop 'CDE output restore not exact'
 call hybrid_cde_output_apply()
end if
write(*,'(a)')'CDE_OUTPUT_COMPONENT_PASS'
contains
subroutine assign(factor)
real(8),intent(in)::factor
ASSIGN
do i=1,4
 imqsol(i)=factor*(17+i)
end do
end subroutine
subroutine snapshot(values)
real(8),intent(out)::values(21)
values=[FIELDS,imqsol(1:4)]
end subroutine
end program
'''.replace('FIELDS',FIELDS).replace('ASSIGN','\n'.join(f'{name}=factor*{i}' for i,name in enumerate(FIELDS.split(','),1)))


def main():
    p=argparse.ArgumentParser();p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.mkdir();provider=a.reference_work/'build';objects=provider/'swap-obj';tt=provider/'ttutil-obj'
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    q=dict(status='RUNNING',scope='Daily defined CDE output storage only; no chemical law or scientific oracle',source_sha256=sha(ROOT/'app/hybrid_water/original_cde_output_state.f90'),original_sources={},profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def call(cmd,cwd,label):
        start=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,text=True,timeout=60)
        (cwd/(label+'.stdout')).write_text(r.stdout);(cwd/(label+'.stderr')).write_text(r.stderr)
        return dict(returncode=r.returncode,seconds=time.monotonic()-start,stderr=r.stderr,stdout=r.stdout)
    try:
        for opt in ('O0','O2'):
            build=a.output/opt;build.mkdir();(build/'driver.f90').write_text(DRIVER)
            flags=['-'+opt,'-cpp','-Dlinux','-ffree-line-length-none','-fallow-argument-mismatch','-fcheck=all','-fbacktrace','-ffp-contract=off','-ffunction-sections','-fdata-sections','-J'+str(build),'-I'+str(build),'-I'+str(objects),'-I'+str(tt)]
            report=dict(flags=flags,builds=[],runs={});q['profiles'][opt]=report
            sources=[provider/'swap-selected/variables.f90',provider/'swap-selected/solute.f90',ROOT/'app/hybrid_water/original_cde_output_state.f90',build/'driver.f90']
            for source in sources:
                q['original_sources'][str(source)]=sha(source)
                result=call(['gfortran',*flags,'-c',source],build,'compile-'+source.stem);report['builds'].append(result);assert result['returncode']==0,result
            exe=build/'component.exe'
            closure=[build/(s.stem+'.o') for s in sources]
            # PE/COFF retains original submodule relocations despite section GC.
            # Use the measured real provider closure, never dummy physics symbols.
            inherited=[p for p in sorted(objects.glob('*.o')) if p.stem.lower() not in ('variables','solute','swap_main')]
            result=call(['gfortran','-Wl,--gc-sections','-o',exe,*closure,*inherited,tt/'libttutil.a'],build,'link');report['link']=result;assert result['returncode']==0,result['stderr']
            report['link_closure']={str(p):sha(p) for p in [*closure,*inherited,tt/'libttutil.a']};report['executable_sha256']=sha(exe)
            raw=build/'valid.bin';result=call([exe,'write',raw],build,'write');assert result['returncode']==0;report['runs']['write']=result
            original=raw.read_bytes();assert len(original)==24+21*16
            mutations={}
            def changed(offset,fmt,value):
                b=bytearray(original);struct.pack_into(fmt,b,offset,value);return bytes(b)
            mutations['header-witness']=changed(12,'<i',2)
            mutations['version']=changed(0,'<i',2)
            mutations['shape']=changed(4,'<i',4)
            mutations['length']=changed(8,'<i',22)
            mutations['value-witness']=changed(24+8,'<d',2.5)
            for name,value in [('nan',float('nan')),('inf',float('inf')),('negative-initial',-1.)]:
                b=bytearray(original)
                for offset in (24,24+21*8):struct.pack_into('<d',b,offset,value)
                mutations[name]=bytes(b)
            mutations['truncated-header']=original[:20];mutations['truncated-values']=original[:-1]
            for mode in ('read','pending-read','pending-write','reset','shape'):
                result=call([exe,mode,raw],build,'run-'+mode);report['runs'][mode]=result
                assert (result['returncode']==0)==(mode=='read'),result
                if mode=='read':assert 'CDE_OUTPUT_COMPONENT_PASS' in result['stdout']
            for name,body in mutations.items():
                path=build/(name+'.bin');path.write_bytes(body);result=call([exe,'read',path],build,'bad-'+name);report['runs'][name]=result;assert result['returncode']!=0,result
            report.update(staged_read_nonmutation=True,bit_exact_live_restore=True,repeated_apply_noop=True,actual_original_storage=True,native_refusals=14)
            save();print(opt,'CDE_OUTPUT_COMPONENT_PASS',flush=True)
        q['status']='DAILY_CDE_OUTPUT_STATE_O0_O2_EXACT_STAGED_RESTORE_AND_28_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
