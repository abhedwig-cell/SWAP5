"""Focused native-label admission supplement with independent original TTUTIL."""
from pathlib import Path
import base64,hashlib,io,json,os,runpy,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_LABEL_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
os.environ['N_NATIVE_RESULT_DIR']=str(OUT/'native')
ns=runpy.run_path(str(ROOT/'tests/nut-input/run_native_snm.py'))
os.environ['TTUTIL_RESULT_DIR']=str(OUT/'ttutil')
runpy.run_path(str(ROOT/'tests/nut-input/run_ttutil_native_oracle.py'))
os.environ['N_INPUT_RESULT_DIR']=str(OUT/'export')
runpy.run_path(str(ROOT/'tests/nut-input/run_input.py'))
params=ns['params']
base='''MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac
20 'first' 0. 0. 0. .21 .10
7 'second' 0. 0. 0. .07 .03
smedate iMat Dosagekgha VolatFraction
1900-12-30 2 100. .1
1901-01-01 1 50. .1
1901-01-01 2 25. .1
;
'''+params
fixtures={n:(base.replace("20 'first'",f"{a} 'first'").replace("7 'second'",f"{b} 'second'"),0) for n,a,b in [('sparse',20,7),('duplicate',7,7),('reversed',2,1),('ordered',1,2)]}
for n,token in [('zero','0'),('over_max','21'),('integer_overflow','999999999999999999999999999999999999999999999999999999')]:
 fixtures[n]=(base.replace("20 'first'",token+" 'first'"),-2)
fixtures['second_bad']=(base.replace("7 'second'","0 'second'"),-3)
fixtures['label_not_key']=(base.replace('1901-01-01 1 50.','1901-01-01 20 50.'),-6)
for n,(s,_) in fixtures.items():(OUT/(n+'.snm')).write_text(s)
events=[];outputs={}
def run(args,b,cat):
 args=list(map(str,args));start=time.perf_counter();p=subprocess.run(args,cwd=b,capture_output=True);i=len(events)
 for st in ['stdout','stderr']:(OUT/f'{i:03d}.{st}').write_bytes(getattr(p,st))
 events.append(dict(command=args,category=cat,returncode=p.returncode,seconds=time.perf_counter()-start));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
original='''program original_labels
 implicit none
 integer::mat(1000),n,nm,i,expect1,expect2
 real(8)::frac(20),dates(1000)
 character(512)::path,a,b
 call get_command_argument(1,path);call get_command_argument(2,a);call get_command_argument(3,b)
 read(a,*)expect1;read(b,*)expect2
 call rdinit(20,0,trim(path))
 call rdainr('MatNum',1,20,mat,20,nm)
 if(nm/=2.or.any(mat(:2)/=[expect1,expect2]))error stop 1
 call rdfdor('NH4NFrac',0d0,1d0,frac,20,nm)
 call rdatim('smedate',dates,1000,n)
 call rdfinr('iMat',1,1000,mat,1000,n)
 if(n/=3.or.any(mat(:n)/=[2,1,2]))error stop 2
 if(any(frac(mat(:n))/=[.07d0,.21d0,.07d0]))error stop 3
 close(20)
 print '(A)','ORIGINAL_LABEL_OVERWRITE_POSITION_LOOKUP=PASS'
end program
'''
for opt in ['O0','O2']:
 b=OUT/'native'/opt;flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-I'+str(b),'-J'+str(b)]
 objects=sorted(b.glob('*.o'),key=lambda p:int(p.stem))[:-1]
 driver=ROOT/'integration/audits/test_nut_material_labels.f90';o=b/'labels.o';exe=b/'labels'
 run(['gfortran',*flags,'-c',driver,'-o',o],b,'compile');run(['gfortran',*flags,*objects,o,'-o',exe],b,'link')
 outputs[opt]={n:run([exe,OUT/(n+'.snm'),e],b,'native') for n,(_,e) in fixtures.items()}
 b=OUT/'ttutil'/opt;(b/'labels.f90').write_text(original);exe=b/'labels'
 run(['gfortran','-'+opt,b/'labels.f90',*sorted(b.glob('*.o')),'-o',exe],b,'original_link')
 for n,a,c in [('sparse',20,7),('duplicate',7,7),('reversed',2,1),('ordered',1,2)]:
  outputs[opt]['original_'+n]=run([exe,OUT/(n+'.snm'),a,c],b,'original_native')
assert outputs['O0']==outputs['O2']
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes()))) as t:
 raw=t.extractfile('SWAP/management_soil.f90').read()
assert hashlib.sha256(raw).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
(OUT/'original_management.txt').write_text('\n'.join(raw.decode('latin1').splitlines()[119:132])+'\n')
inputs={str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__),driver,ROOT/'src/process/mod_soil_n_unified_input.f90']}
r=dict(status='NATIVE_POSITION_LABEL_SUPPLEMENT_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,fixtures={n:sha(OUT/(n+'.snm')) for n in fixtures},outputs=outputs,original_program_sha256=hashlib.sha256(original.encode()).hexdigest(),management_sha256=hashlib.sha256(raw).hexdigest(),cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in sorted({e['category'] for e in events})})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
