#!/usr/bin/env python3
"""Same-host complete highest low-air A/B, all original assertions retained.

Reuses one verified live build. Baseline and candidate differ only in the explicit
proposal selector. Does not alter immutable references or claim canonical admission.
"""
import argparse,hashlib,json,os,pathlib,resource,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);a.add_argument('--repeat',type=int,default=2);args=a.parse_args()
 if args.repeat<1:raise ValueError('positive repeats')
 b=args.build.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 r=json.loads((b/'RESULTS.json').read_text());flags=r['flags'];assert '-pg' not in flags
 assert r['ordered_sources'][-1]==str(b/'low_air_driver.f90')
 for p,h in r['sources'].items():assert sha(pathlib.Path(p))==h,'changed live build input '+p
 assert (b/'mod_canonical_interval_runtime.f90').read_bytes()==(ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_bytes()
 driver=ROOT/'tests/frost/test_ppa_wu05b15_low_air_runtime.f90'
 original=driver.read_bytes();policy=original.decode().replace('    config%transaction%retry_scale = 0.5_real64','    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64').replace('    cfg%numerical%transaction%retry_scale=.5_real64','    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64').encode()
 assert (b/'low_air_driver.f90').read_bytes()==policy,'candidate recipe mismatch'
 result={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'scope':'COMPLETE_HIGHEST_LOW_AIR_SAME_HOST_AB','build_manifest_sha256':sha(b/'RESULTS.json'),'flags':flags,'sources':r['sources'],'runs':[],'compiler':r['compiler'],'host':r['host'],'repeat':args.repeat,'full_o0_o2_qualified':False,'admitted':False}
 objects=[b/f'{i}.o' for i in range(len(r['ordered_sources'])-1)]
 result['objects']={str(p):sha(p) for p in objects}
 for name,text in [('baseline',original),('candidate',policy)]:
  p=out/(name+'.f90');p.write_bytes(text)
  subprocess.run(['gfortran',*flags,'-J',str(b),'-I',str(b),'-c',str(p),'-o',str(out/(name+'.o'))],check=True)
  subprocess.run(['gfortran',*flags,*map(str,objects),str(out/(name+'.o')),'-o',str(out/name)],check=True)
  result[name+'_binary_sha256']=sha(out/name)
 (out/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
 for round_index in range(args.repeat):
  for family in range(1,7):
   for name in (['baseline','candidate'] if round_index%2==0 else ['candidate','baseline']):
    prefix=out/f'{round_index}-{family}-{name}';before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
    print(f'START round={round_index} family={family} policy={name}',flush=True)
    with prefix.with_suffix('.stdout').open('w')as so,prefix.with_suffix('.stderr').open('w')as se:
     cp=subprocess.run([str(out/name),str(family)],stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'},timeout=900)
    after=resource.getrusage(resource.RUSAGE_CHILDREN);text=prefix.with_suffix('.stdout').read_text()
    record={'round':round_index,'family':family,'policy':name,'wall_seconds':time.monotonic()-start,'cpu_seconds':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'exit':cp.returncode,'stdout_sha256':sha(prefix.with_suffix('.stdout')),'complete':cp.returncode==0 and text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6 and 'PPA_WU05B15_EXTENDED_APPLICATION=PASS' in text and 'PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS' in text}
    result['runs'].append(record);(out/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(record),flush=True)
    if not record['complete']:raise RuntimeError('full original assertions failed; retain negative evidence')
 result['complete_single_optimization_ab']=True
 (out/'RESULTS.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
