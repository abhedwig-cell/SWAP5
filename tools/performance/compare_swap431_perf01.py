#!/usr/bin/env python3
"""Interleave original SWAP431 and both SWAP5 binaries on one CPU; compare full traces."""
import argparse,hashlib,json,os,platform,re,statistics,subprocess,time
from pathlib import Path
import numpy as np
CASES={1:('bare',30),2:('prescribed_roots',30),3:('dry',1),4:('shallow_head',1),5:('rain_pulse',3),6:('prescribed_drainage',30),7:('long_balanced',365),8:('layered_column',30)}
DTYPE=np.dtype([('step','i4'),('dt','f8'),('nl','i4'),('retry','i4'),('mass','f8'),('h','f8',(50,)),('theta','f8',(50,)),('pond','f8'),('gwl','f8'),('top','f8'),('bottom','f8'),('root','f8'),('drain','f8')])
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 for key in ['legacy','before','after','output']:ap.add_argument('--'+key,type=Path,required=True)
 ap.add_argument('--repeat',type=int,default=9);a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bins={n:getattr(a,n).resolve()for n in ['legacy','before','after']};core=max(os.sched_getaffinity(0));report=dict(executables={n:dict(path=str(p),sha256=sha(p))for n,p in bins.items()},host=platform.uname()._asdict(),core=core,runs=[],summary=[],scope='Direct real hydraulic kernels; outer transaction policy is measured separately')
 for case,(name,days) in CASES.items():
  for repeat in range(a.repeat):
   order=['legacy','before','after'];offset=repeat%3;order=order[offset:]+order[:offset]
   if repeat%2:order=order[::-1]
   for arm in order:
    b=out/f'{case}-{repeat}-{arm}';b.mkdir();t=time.monotonic();p=subprocess.run([str(bins[arm]),str(days),str(case)],cwd=b,capture_output=True,preexec_fn=lambda:os.sched_setaffinity(0,{core}),timeout=90);wall=time.monotonic()-t
    (b/'stdout').write_bytes(p.stdout);(b/'stderr').write_bytes(p.stderr);m=re.search(rb'CPU=\s*(\S+) WALL=\s*(\S+)',p.stderr)
    rec=dict(arm=arm,case=name,days=days,repeat=repeat,exit=p.returncode,wall=wall,series_sha256=sha(b/('legacy_trajectory.bin'if arm=='legacy'else'trajectory.bin')))
    if m:rec.update(core_cpu=float(m[1]),core_wall=float(m[2]))
    report['runs'].append(rec);(out/'CONTROL.json').write_text(json.dumps(report,indent=2))
    if p.returncode:raise RuntimeError(str(b))
  rr=[x for x in report['runs'] if x['case']==name];row=dict(case=name,days=days)
  for arm in bins:
   z=[x for x in rr if x['arm']==arm];row[arm]={k:dict(median=statistics.median(x[k]for x in z),min=min(x[k]for x in z),max=max(x[k]for x in z))for k in ['wall','core_cpu','core_wall']}
  row['old_ratio']=row['before']['core_cpu']['median']/row['legacy']['core_cpu']['median'];row['new_ratio']=row['after']['core_cpu']['median']/row['legacy']['core_cpu']['median'];row['speedup']=row['before']['core_cpu']['median']/row['after']['core_cpu']['median']
  arrays={arm:np.fromfile(out/f'{case}-0-{arm}'/('legacy_trajectory.bin'if arm=='legacy'else'trajectory.bin'),dtype=DTYPE)for arm in bins}
  row['steps']={arm:len(v)for arm,v in arrays.items()};row['scientific_before_after_byte_exact']=all(len({x['series_sha256']for x in rr if x['arm']in ['before','after']})==1 for _ in [0])
  if not row['scientific_before_after_byte_exact']:raise RuntimeError('SWAP5 regression '+name)
  if len(arrays['legacy'])==len(arrays['before']):row['historical_max_abs']={k:float(np.max(np.abs(arrays['legacy'][k]-arrays['before'][k])))for k in DTYPE.names}
  row['nonlinear_iterations']={arm:int(v['nl'].sum())for arm,v in arrays.items()};row['accepted_dt']={arm:dict(min=float(v['dt'].min()),max=float(v['dt'].max()),median=float(np.median(v['dt'])))for arm,v in arrays.items()}
  row['retries']={arm:int(v['retry'][-1])for arm,v in arrays.items()};row['max_independent_mass']={arm:float(np.abs(v['mass']).max())for arm,v in arrays.items()}
  report['summary'].append(row);(out/'CONTROL.json').write_text(json.dumps(report,indent=2));print(name,row['old_ratio'],row['new_ratio'],row['speedup'],flush=True)
if __name__=='__main__':main()
