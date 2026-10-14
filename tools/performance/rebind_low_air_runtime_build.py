#!/usr/bin/env python3
"""Rebuild an internal runtime body in a byte-verified same-toolchain live build.

Every other input/object and the exported module interface must remain identical.
No receipt is accepted if an interface or unrelated source changed.
"""
import argparse,hashlib,json,pathlib,shutil,subprocess,time,resource
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--qualification',type=pathlib.Path,required=True);args=a.parse_args();old=args.build.resolve();out=args.output.resolve();out.mkdir(exist_ok=False,parents=True)
 m=json.loads((old/'RESULTS.json').read_text());runtime=ROOT/'src/runtime/mod_canonical_interval_runtime.f90';prior_runtime=old/'mod_canonical_interval_runtime.f90'
 assert m['compiler']==subprocess.check_output(['gfortran','--version'],text=True)
 for p,h in m['sources'].items():
  if pathlib.Path(p) not in [runtime,prior_runtime]:assert sha(p)==h,p
 idx=m['ordered_sources'].index(str(prior_runtime));objects=[old/f'{i}.o'for i in range(len(m['ordered_sources']))]
 object_hashes={str(p):sha(p)for p in objects}
 from verify_low_air_ab import verify
 verify(args.qualification)
 q=json.loads((args.qualification/'RESULTS.json').read_text())
 assert q['build_manifest_sha256']==sha(old/'RESULTS.json')
 for p,h in q['objects'].items():assert object_hashes[p]==h,'provider artifact drift '+p
 assert set(q['objects'])=={str(p)for p in objects[:-1]}

 for p in old.glob('*.mod'):shutil.copy2(p,out/p.name)
 for i,p in enumerate(objects):
  if i!=idx:(out/f'{i}.o').symlink_to(p)
 copied=out/'mod_canonical_interval_runtime.f90';copied.write_bytes(runtime.read_bytes());driver=out/'low_air_driver.f90';driver.write_bytes((old/'low_air_driver.f90').read_bytes())
 before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
 subprocess.run(['gfortran',*m['flags'],'-J',str(out),'-I',str(out),'-c',str(copied),'-o',str(out/f'{idx}.o')],check=True)
 after=resource.getrusage(resource.RUSAGE_CHILDREN)
 assert sha(out/'mod_canonical_interval_runtime.mod')==sha(old/'mod_canonical_interval_runtime.mod'),'exported interface changed; rebuild full closure'
 m['events']=[{'label':'runtime_rebind_compile','wall_seconds':time.monotonic()-start,'cpu_seconds':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'exit':0}]
 m['ordered_sources'][idx]=str(copied);m['ordered_sources'][-1]=str(driver)
 del m['sources'][str(prior_runtime)];del m['sources'][str(old/'low_air_driver.f90')]
 m['sources'].update({str(copied):sha(copied),str(runtime):sha(runtime),str(driver):sha(driver)})
 m['rebind']={'qualification_manifest_sha256':sha(args.qualification/'RESULTS.json'),'old_manifest_sha256':sha(old/'RESULTS.json'),'verified_exported_module_sha256':sha(out/'mod_canonical_interval_runtime.mod'),'inherited_objects':object_hashes,'changed_provider_index':idx,'scope':'Identical exported ABI and all unrelated inputs/objects; runtime body rebuilt. Not qualification.'}
 m['head']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();m['terminal_status']='LIVE_VERIFIED_REBIND_BUILD_ONLY'
 (out/'RESULTS.json').write_text(json.dumps(m,indent=2)+'\n');print('LIVE_RUNTIME_REBIND=PASS')
if __name__=='__main__':main()
