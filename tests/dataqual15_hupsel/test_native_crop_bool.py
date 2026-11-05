"""Host-representation controls for the exact private scalar helper."""
import os,shutil,subprocess,tempfile,unittest
from pathlib import Path
import native_crop_bool as candidate

ROOT=Path(__file__).resolve().parents[2]
DRIVER='''program probe
  use iso_fortran_env,only:int32
  implicit none
  logical::v,saved
  integer::u,io,j,mode,n
  integer(int32)::bits,got,bad(4)=[2,-1,256,2147483647]
  if(storage_size(v)/=32)stop 9
  do j=0,1
    v=j==1
    open(newunit=u,status='scratch',access='stream',form='unformatted')
    call scalar_logical_io(u,.false.,v,io)
    if(io/=0)stop 1
    rewind(u);read(u)got
    if(got/=transfer(v,got))stop 2
    rewind(u);v=.not.v
    call scalar_logical_io(u,.true.,v,io)
    if(io/=0.or.(v.neqv.(j==1)))stop 3
    close(u)
  end do
  do j=1,4
    do mode=1,2
      bits=bad(j);v=.true.;saved=v
      open(newunit=u,status='scratch',access='stream',form='unformatted')
      if(mode==1)then
        write(u)bits;rewind(u)
        call scalar_logical_io(u,.true.,v,io)
        if(v.neqv.saved)stop 4
      else
        v=transfer(bits,v)
        call scalar_logical_io(u,.false.,v,io)
        inquire(unit=u,size=n)
        if(n/=0)stop 5
      end if
      if(io==0)stop 6
      close(u)
    end do
  end do
  open(newunit=u,status='scratch',access='stream',form='unformatted')
  v=.true.
  call scalar_logical_io(u,.true.,v,io)
  if(io==0.or..not.v)stop 7
  close(u)
contains
'''+candidate.HELPER+'end program\n'

class Policy(unittest.TestCase):
    def test_exact_scalar_surface(self):
        source=(ROOT/candidate.SOURCE).read_text(encoding='utf-8')
        result=candidate.candidate(source)
        self.assertEqual(result.count('call scalar_logical_io('),32)
        self.assertIn('read(u,iostat=io)v%evolution_continuation',result)
        self.assertNotEqual(result,source)

    def test_host_helper_O0_O2(self):
        compiler=shutil.which('gfortran');self.assertIsNotNone(compiler)
        for opt in ('-O0','-O2'):
            with tempfile.TemporaryDirectory(prefix='swap-bool-')as directory:
                root=Path(directory);source=root/'probe.f90';source.write_text(DRIVER,encoding='utf-8')
                exe=root/('probe.exe'if os.name=='nt'else'probe')
                subprocess.run([compiler,opt,'-fcheck=all',str(source),'-o',str(exe)],check=True,capture_output=True)
                subprocess.run([str(exe)],cwd=root,check=True,capture_output=True)

if __name__=='__main__':unittest.main()
