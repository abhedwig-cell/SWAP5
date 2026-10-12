#!/usr/bin/env python3
"""Compile literal B1.11 ETpot/penmon/astro/raero independently from production."""
from pathlib import Path
import base64,hashlib,io,re,subprocess,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
def oracle():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes()))) as t:
  b=t.extractfile('SWAP/MOD_meteo.f90').read();variables=t.extractfile('SWAP/variables.f90').read();params=t.extractfile('SWAP/params.f90').read()
 assert hashlib.sha256(b).hexdigest()=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
 assert hashlib.sha256(variables).hexdigest()=='327a064ca74f6c4bebc327a38de367824c7fe535baa1a8611879f9a6a479c856'
 assert hashlib.sha256(params).hexdigest()=='c51e7e9f094e6f15fbe078339e480476080829514814d2535cde4ea662bb566b'
 for marker in ['real(8), parameter :: pi = 3.141592653589793238462643383279502884197d0','real(8), parameter :: radial = pi / 180.d0']:assert marker in variables.decode()
 for marker in ['real(8), parameter   :: small  = 1.0d-6','real(8), parameter   :: vlarge = 1.0d12']:assert marker in params.decode()
 s=b.decode().replace('\r\n','\n');parts=[]
 for name in ['ETpot','penmon','astro','raero']:
  if name=='raero':start=s.index('   function raero(');end=s.index('   end function',start)
  else:start=re.search(r'   subroutine '+name+r'\s*\(',s).start() if name in ['penmon','astro'] else s.index('   subroutine ETpot\n');end=s.index('   end subroutine',start)
  end=s.index('\n',end);part=s[start:end]
  part=re.sub(r'^\s*use (plant_interface|variables|MOD_params|parameters),.*\n','',part,flags=re.M|re.I)
  parts.append(part)
 return '''module b111_daily_demand_oracle
implicit none
real(8),parameter::pi=3.141592653589793238462643383279502884197d0,radial=pi/180.d0,small=1.d-6,vlarge=1.d12
integer::swetr,swmetdetail,swdivide,swcf,swcfbs,daynr,n_metdetail,i_metdetail
logical::fl_cropemergence
real(8)::lat,rad,tav,tmn,tmx,hum,win,alt,altw,alth,fwind,angstroma,angstromb,long,long_tz
real(8)::ch,albedo,rsc,rsw,lai,cf,cfbs,fco2tra,vcover,rsoil,cfevappond,etr
real(8)::es0,et0,ew0,ep0,epond,peva,ptra_dry,ptra_wet,eintc,dt_interc_event,crsflx_in,crsflx_out,wfrac
contains
'''+ '\n'.join(parts)+'\nend module\n'
def main():
 with tempfile.TemporaryDirectory(prefix='mc-met01-demand-source-') as tmp:
  d=Path(tmp);(d/'oracle.f90').write_text(oracle());out=[]
  (d/'pm-view.met').write_text("'SYN' 1 1 2000 100 1 2 1.25 3.5 0 0.1 0.1\n")
  for opt in [0,2]:
   exe=d/f'test{opt}';subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-I',str(d),'-J',str(d),str(ROOT/'src/process/mod_reference_et_demand_process.f90'),str(ROOT/'src/adapter/mod_swap_daily_weather_file_adapter.f90'),str(d/'oracle.f90'),str(ROOT/'tests/mc-met01/test_daily_demand_source.f90'),'-o',str(exe)],cwd=d,check=True)
   r=subprocess.run([str(exe),str(d/'pm-view.met')],capture_output=True,text=True,check=True);print(r.stdout,end='');out.append(r.stdout)
  assert out[0]==out[1]
 print('MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS')
if __name__=='__main__':main()
