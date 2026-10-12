#!/usr/bin/env python3
"""Compile literal B1.11 ETpot/penmon/astro/raero independently from production."""
from pathlib import Path
import base64,hashlib,io,re,subprocess,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
def oracle():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes()))) as t:b=t.extractfile('SWAP/MOD_meteo.f90').read()
 assert hashlib.sha256(b).hexdigest()=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
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
  for opt in [0,2]:
   exe=d/f'test{opt}';subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-I',str(d),'-J',str(d),str(ROOT/'src/process/mod_reference_et_demand_process.f90'),str(d/'oracle.f90'),str(ROOT/'tests/mc-met01/test_daily_demand_source.f90'),'-o',str(exe)],cwd=d,check=True)
   r=subprocess.run([str(exe)],capture_output=True,text=True,check=True);print(r.stdout,end='');out.append(r.stdout)
  assert out[0]==out[1]
 print('MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS')
if __name__=='__main__':main()
