"""Replay unchanged B1.11 MICRO table code, not the full uptake model."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEMBER = 'reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90'
PIN = 'cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477'
raw = (ROOT / MEMBER).read_bytes()
assert hashlib.sha256(raw).hexdigest() == PIN
start = raw.index(b'subroutine get_MFLP_K (iTask, H, jLayer, M, K)')
end = raw.index(b'end subroutine get_MFLP_K', start) + len(b'end subroutine get_MFLP_K')
block = raw[start:end]
HEADER = '''module MOD_grid
implicit none
integer :: layer(1)=1,numlay=1,nod1lay(1)=1
end module
module variables
implicit none
real(8) :: ksatfit(1)=1d0
end module
module MOD_MvG
implicit none
contains
real(8) function watcon(i,h)
integer,intent(in)::i
real(8),intent(in)::h
watcon=0.3d0
end function
real(8) function hconduc(i,h,w,t)
integer,intent(in)::i
real(8),intent(in)::h,w,t
hconduc=1d0
end function
end module
module literal_micro_table
implicit none
integer,parameter::iMethod=2
real(8),allocatable::M_table(:,:),K_table(:,:)
contains
'''
TRAILER = '''
end module
subroutine swap_error(where,message)
character(*),intent(in)::where,message
print *,where,message
error stop 99
end subroutine
program dry_table_audit
use literal_micro_table
implicit none
integer::pass,j,start
real(8)::m,k,head(6),poison(3),ms(6,3),ks(6,3)
head=[-20001d0,-20000d0,-19970d0,-19900d0,-19000d0,-1d0]
poison=[0d0,1d0,1d6]
start=int(100d0*log10(20000d0))
if(start/=430)error stop 1
call get_MFLP_K(1)
! Only cells the unchanged initializer does not write are varied. This is a
! deterministic admissible-realization test of indeterminate storage, not a
! claim about the allocator's actual bytes on a particular legacy run.
do pass=1,3
 K_table(start:,:)=poison(pass)
 M_table(start+1:,:)=poison(pass)
 do j=1,6
  call get_MFLP_K(2,head(j),1,m,k)
  ms(j,pass)=m;ks(j,pass)=k
  write(*,'(A,I0,A,F12.4,A,ES24.16,A,ES24.16)') &
   'POISON=',pass,' HEAD=',head(j),' M=',m,' K=',k
 end do
end do
if(any(ms(1,:)/=0d0).or.any(ks(1,:)/=0d0))error stop 2
if(any(ms(5,:)/=ms(5,1)).or.any(ks(5,:)/=ks(5,1)))error stop 3
if(any(ms(6,:)/=ms(6,1)).or.any(ks(6,:)/=ks(6,1)))error stop 4
if(ms(2,1)==ms(2,3).or.ks(2,1)==ks(2,3))error stop 5
if(ms(3,1)==ms(3,3).or.ks(3,1)==ks(3,3))error stop 6
if(any(ms(4,:)/=ms(4,1)).or.ks(4,1)==ks(4,3))error stop 7
print '(A)','B111_MICRO_UNINITIALIZED_DRY_BRACKET_CONFIRMED=PASS'
print '(A)','B111_MICRO_DRY_BELOW_AND_NORMAL_CONTROLS=PASS'
end program
'''
outputs = {}
with tempfile.TemporaryDirectory(prefix='micro01-dry-table-') as tmp:
    tmp = pathlib.Path(tmp)
    f = tmp / 'literal.f90'
    f.write_bytes(HEADER.encode() + block + TRAILER.encode())
    for opt in ('O0', 'O2'):
        subprocess.run(['gfortran', '-' + opt, '-ffree-line-length-none',
                        '-fcheck=all', '-ffpe-trap=invalid,zero,overflow',
                        str(f), '-o', str(tmp / opt)], cwd=tmp, check=True)
        execution = subprocess.run([str(tmp / opt)], text=True, capture_output=True)
        if execution.returncode:
            print(execution.stdout, end='')
            print(execution.stderr, end='')
            execution.check_returncode()
        outputs[opt] = execution.stdout
        print(outputs[opt], end='')
assert outputs['O0'] == outputs['O2']
print('B111_MICRO_DRY_TABLE_O0_O2_IDENTICAL=PASS')
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
result = {'schema': 'swap5.micro01.dry_table_reference.v1', 'tested_postimage': sha,
          'reference_member': MEMBER, 'reference_sha256': PIN,
          'literal_block_sha256': hashlib.sha256(block).hexdigest(),
          'status': 'CONFIRMED_REFERENCE_UNINITIALIZED_DRY_BRACKET',
          'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                            for p in (MEMBER, 'tests/physics/run_ppa_micro01_dry_table.py')},
          'runs': outputs,
          'claim_ceiling': 'Unchanged table routine with explicitly synthetic constant-K dependencies; '
                           'indeterminate cells varied deterministically. No full MICRO physics, '
                           'actual allocator-memory prediction, production admission or reference repair.'}
if os.environ.get('C3A_RESULT'):
    pathlib.Path(os.environ['C3A_RESULT']).write_text(json.dumps(result, indent=2) + '\n')
