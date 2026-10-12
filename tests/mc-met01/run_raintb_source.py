#!/usr/bin/env python3
"""Independent literal B1.11 AFGEN and rainfall arithmetic, typed inputs only."""
from pathlib import Path
import base64,hashlib,io,tarfile,tempfile,subprocess
ROOT=Path(__file__).resolve().parents[2]
def main():
 raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  meteo=t.extractfile('SWAP/MOD_meteo.f90').read();functions=t.extractfile('SWAP/functions.f90').read()
 assert hashlib.sha256(meteo).hexdigest()=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
 s=functions.decode().replace('\r\n','\n');start=s.index('   real(8) function afgen (');end=s.index('   end function afgen',start)+len('   end function afgen')
 afgen=s[start:end]
 lines=meteo.decode().splitlines()
 assert '      real(8), parameter   :: vsmall = 1.0d-8' in lines
 assert '            if (all_rain(i) > vsmall) then' in lines
 statements=[]
 for marker in ['rflx = afgen(raintb, size(raintb), doy)','rtim = dmin1(1.d0, all_rain(i) * 0.1d0 / rflx)','rainflx(rain_rec) = all_rain(i) * 0.1d0 / rtim']:
  match=[l for l in lines if l.strip()==marker];assert len(match)==1;statements+=match
 oracle="""subroutine b111_pulse(raintb,n,doy,rain,duration,rate)
use iso_fortran_env,only:real64
implicit none
integer,intent(in)::n
real(real64),intent(in)::raintb(n),doy,rain
real(real64),intent(out)::duration,rate
real(real64)::all_rain(1),rainflx(1),rtim,rflx,afgen
integer::i,rain_rec
i=1;rain_rec=1;all_rain(1)=rain
rtim=0.d0;rainflx=0.d0
if(all_rain(i)>1.0d-8) then
"""+'\n'.join(statements)+"\nend if\nduration=rtim;rate=rainflx(1)\nend subroutine\n"+afgen+'\n'
 with tempfile.TemporaryDirectory(prefix='mc-met01-source-') as d:
  d=Path(d);(d/'oracle.f90').write_text(oracle)
  for opt in [0,2]:
   subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(d),'-I',str(d),str(ROOT/'src/adapter/mod_swap_daily_weather_file_adapter.f90'),str(d/'oracle.f90'),str(ROOT/'tests/mc-met01/test_raintb_source.f90'),'-o',str(d/f'test{opt}')],check=True,cwd=d)
   r=subprocess.run([str(d/f'test{opt}')],check=True,capture_output=True,text=True);(d/f'o{opt}.log').write_text(r.stdout);print(r.stdout,end='')
  assert (d/'o0.log').read_bytes()==(d/'o2.log').read_bytes()
 print('MC_MET01_LITERAL_RAINTB_O0_O2=PASS')
if __name__=='__main__':main()
