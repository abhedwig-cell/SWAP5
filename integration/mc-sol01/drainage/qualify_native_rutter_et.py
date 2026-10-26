"""Small actual-provider test against the exact archived original ETpot body."""
import argparse,base64,hashlib,io,json,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();events=[]
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz')as t:raw=t.extractfile('SWAP/MOD_meteo.f90').read()
assert sha(raw)=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f';text=raw.decode('latin1');i=text.index('   subroutine ETpot');j=text.index('   end subroutine ETpot',i)+len('   end subroutine ETpot');body=text[i:j]
(out/'original_ETpot.body').write_bytes(body.encode('latin1'))
stubs='''module plant_interface
 implicit none
 logical::fl_cropemergence
 real(8)::fco2tra,vcover,cf,dt_interc_event,crsflx_in,crsflx_out
 integer::swcf
end module
module variables
 implicit none
 integer::swcfbs,daynr
 real(8)::cfbs,rsoil
end module
module legacy_etpot_oracle
 implicit none
 integer::swmetdetail,swetr,swdivide
 real(8)::etr,cfevappond,es0,ep0,et0,ew0,epond,peva,ptra_dry,ptra_wet,eintc,wfrac
contains
'''
footer='''
 subroutine penmon(daynr,swcfbs,rsoil,vcover)
 integer::daynr,swcfbs
 real(8)::rsoil,vcover
 error stop 'PM not selected in ETref oracle'
 end subroutine
end module
'''
oracle=out/'original_ETpot.f90';oracle.write_bytes((stubs+body+footer).encode('latin1'));source=ROOT/'src/process/mod_reference_et_demand_process.f90';driver=ROOT/'tests/nut-sol/test_native_rutter_et.f90';streams=[]
for opt in ['O0','O2']:
 d=out/opt;d.mkdir();exe=d/'test';flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(d),'-I'+str(d)]
 for label,cmd in [('link',[a.fc,*flags,str(source),str(oracle),str(driver),'-o',str(exe)]),('native',[str(exe)])]:
  start=time.monotonic();cp=subprocess.run(cmd,cwd=d,capture_output=True)
  for stream in ['stdout','stderr']:(d/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(label=opt+'/'+label,command=cmd,returncode=cp.returncode,seconds=time.monotonic()-start));assert cp.returncode==0,cp.stdout.decode()+cp.stderr.decode()
 streams.append(cp.stdout)
assert streams[0]==streams[1]and b'ORIGINAL_ETPOT_RUTTER_BIT_EXACT_CASES=864'in streams[0]
record=dict(status='ORIGINAL_RUTTER_ETREF_O0_O2_864_BIT_EXACT',original_mod_meteo_sha256=sha(raw),exact_original_body_sha256=sha(body.encode('latin1')),input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [archive,source,driver,Path(__file__)]},events=events,compiler=subprocess.check_output([a.fc,'--version'],text=True).splitlines()[0],qualified=False,canonically_admitted=False)
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
