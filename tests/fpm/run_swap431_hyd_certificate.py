#!/usr/bin/env python3
"""Reuse the existing HYD production closure for bounded certificate owner checks."""
import hashlib,json,os,pathlib,re,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
BUILD=pathlib.Path(os.environ['HYD_CERTIFICATE_BUILD']);BUILD.mkdir(parents=True,exist_ok=True)
EVIDENCE=pathlib.Path(os.environ['HYD_CERTIFICATE_EVIDENCE']);EVIDENCE.mkdir(parents=True,exist_ok=False)
shell=(ROOT/'tests/fpm/run_ppa_wu05a8_real_richards.sh').read_text()
paths=re.search(r'MODULE_SRC=\((.*?)\n\)',shell,re.S).group(1).split()
paths=subprocess.check_output(['python','-B','tests/support/augment_bartholomeus_backend_sources.py',*paths],cwd=ROOT,text=True).splitlines()
drivers=[('analytical','tests/fpm/test_swap431_hyd_certificate.f90',[]),('runtime','tests/fpm/test_swap431_hyd_serialized_runtime.f90',['--certificate-envelope']),('direct_retention','tests/fpe/test_fpe_temporal11_direct_retention_certificate.f90',[]),('fsi38','tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90',[])]
manifest={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in [*paths,*[d[1] for d in drivers]]}
(EVIDENCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(EVIDENCE/'compiler.txt').write_bytes(subprocess.check_output(['gfortran','--version']))
result={'providers':len(paths),'source_sha256':manifest,'optimizations':{}}
flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace']
for opt in ['O0','O2']:
 out=BUILD/opt;out.mkdir(exist_ok=True);objects=[];compile_seconds=0;native={}
 log=open(EVIDENCE/(opt+'-compile.log'),'wb');new=False
 for p in paths:
  obj=out/(pathlib.Path(p).stem+'.o');pin=obj.with_suffix('.sha256')
  # Once an upstream provider changes, rebuild its downstream module consumers.
  new=new or not obj.exists() or not pin.exists() or pin.read_text()!=manifest[p]
  if new:
   t=time.monotonic();run=subprocess.run(['gfortran','-'+opt,*flags,'-J'+str(out),'-I'+str(out),'-c',str(ROOT/p),'-o',str(obj)],cwd=out,stdout=log,stderr=log)
   compile_seconds+=time.monotonic()-t
   if run.returncode: log.close();raise SystemExit('compile failed '+opt+' '+p)
   pin.write_text(manifest[p])
  objects.append(str(obj))
 log.close()
 for name,path,args in drivers:
  obj=out/(name+'-driver.o');exe=out/name;t=time.monotonic()
  run=subprocess.run(['gfortran','-'+opt,*flags,'-J'+str(out),'-I'+str(out),'-c',str(ROOT/path),'-o',str(obj)],cwd=out,capture_output=True)
  driver_compile=time.monotonic()-t;(EVIDENCE/(opt+'-'+name+'-compile.log')).write_bytes(run.stdout+run.stderr)
  if run.returncode:run.check_returncode()
  t=time.monotonic();subprocess.run(['gfortran','-'+opt,*objects,str(obj),'-o',str(exe)],cwd=out,check=True,capture_output=True);link=time.monotonic()-t;t=time.monotonic()
  run=subprocess.run([str(exe),*args],cwd=out,capture_output=True);elapsed=time.monotonic()-t
  (EVIDENCE/(opt+'-'+name+'.stdout')).write_bytes(run.stdout);(EVIDENCE/(opt+'-'+name+'.stderr')).write_bytes(run.stderr)
  native[name]={'exit':run.returncode,'driver_compile_seconds':driver_compile,'link_seconds':link,'native_seconds':elapsed,'stdout_sha256':hashlib.sha256(run.stdout).hexdigest()}
  print(opt,name,'exit',run.returncode,flush=True)
  if run.returncode:print(run.stdout.decode()[-2500:]+run.stderr.decode()[-1500:],flush=True)
 result['optimizations'][opt]={'provider_compile_seconds':compile_seconds,'provider_build_reused':not new,'drivers':native}
 (EVIDENCE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
result['identities']={name:(EVIDENCE/('O0-'+name+'.stdout')).read_bytes()==(EVIDENCE/('O2-'+name+'.stdout')).read_bytes() for name,_,_ in drivers}
result['pass']=all(r['exit']==0 for o in result['optimizations'].values() for r in o['drivers'].values()) and all(result['identities'].values())
(EVIDENCE/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print('SWAP431_HYD_CERTIFICATE_OWNER_O0_O2='+('PASS' if result['pass'] else 'FAIL'),flush=True)
raise SystemExit(0 if result['pass'] else 1)
