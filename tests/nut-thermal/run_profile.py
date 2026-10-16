"""Small real production reducer, mechanically extracted B111 oracle, O0/O2."""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_THERMAL_PROFILE_DIR']).resolve();OUT.mkdir(exist_ok=False)
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as a:
 raw=a.extractfile('SWAP/management_soil.f90').read()
assert hashlib.sha256(raw).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
s=raw.decode();start=s.index('      dum1=0.0d0; dum2=0.0d0; dum3=0.0d0; dum4=0.0d0',s.index('      case (4)'))
end=s.index('      dt_WSN',start);body=s[start:end]
oracle='''subroutine literal_profile(dz,tsoil,dz_WSN,Temp,selected)
 real(real64),intent(in)::dz(:),tsoil(:),dz_WSN
 real(real64),intent(out)::Temp,selected
 real(real64)::dum1,dum2,dum3,dum4,WFrac_t,theta(size(dz))
 integer::idum,i,numnod
 numnod=size(dz);theta=0d0
'''+body+'\n selected=dum1\nend subroutine\n'
(OUT/'literal_profile.inc').write_text(oracle)
events=[]
def run(args,category):
 begin=time.perf_counter();p=subprocess.run(list(map(str,args)),cwd=OUT,capture_output=True)
 index=len(events)
 for name in ['stdout','stderr']:(OUT/f'{index}.{name}').write_bytes(getattr(p,name))
 events.append(dict(category=category,seconds=time.perf_counter()-begin,returncode=p.returncode,command=list(map(str,args))))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stderr.decode()+p.stdout.decode())
 return p.stdout
src=ROOT/'src/process/mod_soil_n_profile_temperature.f90';driver=ROOT/'tests/nut-thermal/test_profile.f90'
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),'-I'+str(OUT)]
 run(['gfortran',*flags,'-c',src,'-o',b/'process.o'],'compile')
 run(['gfortran',*flags,'-c',driver,'-o',b/'driver.o'],'driver_compile')
 run(['gfortran',*flags,b/'process.o',b/'driver.o','-o',b/'test'],'link')
 assert b'NUT_THERMAL_LITERAL_PROFILE=PASS'in run([b/'test'],'native')
result=dict(status='PASS',providers=1,fixtures=23,authority_sha256=hashlib.sha256(raw).hexdigest(),literal_body_sha256=hashlib.sha256(body.encode()).hexdigest(),inputs={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in [src,driver,Path(__file__)]},cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in {e['category']for e in events}})
result.update(execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip())
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
