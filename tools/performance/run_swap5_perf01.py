#!/usr/bin/env python3
"""Paired actual Full Richards trajectories; no compilation time inside native timing.

The historical executable is a separate required comparator, not silently inferred
from the earlier SWAP5 revision. Cases are synthetic diagnostic columns, not
calibrated crops or received HRU datasets.
"""
import argparse, hashlib, importlib.util, json, os, platform, re, statistics, subprocess, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CASES={1:('bare',30),2:('prescribed_roots',30),3:('dry',1),4:('shallow_head',1),5:('rain_pulse',3),6:('prescribed_drainage',30),7:('long_balanced',365),8:('layered_column',30)}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--baseline-tree',required=True,type=Path);ap.add_argument('--output',required=True,type=Path);ap.add_argument('--repeat',type=int,default=5);ap.add_argument('--optimizations',nargs='+',default=['O0','O2']);a=ap.parse_args()
 if a.repeat<3:ap.error('at least three repetitions')
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 spec=importlib.util.spec_from_file_location('audit',ROOT/'tools/performance/run_richards_revision_audit.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 m.DRIVER=ROOT/'tests/performance/swap5_perf01_column.f90'
 report=dict(baseline=str(a.baseline_tree.resolve()),candidate_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),host=platform.uname()._asdict(),compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],core=max(os.sched_getaffinity(0)),builds={},runs=[],summary=[],legacy_swap431='NOT_YET_MEASURED',scope='50-node synthetic physical solver columns; prescribed roots/drainage, no live crop or HRU provenance',case_catalog=CASES)
 (out/'CONTROL.json').write_text(json.dumps(report,indent=2))
 for opt in a.optimizations:
  m.COMMON=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-'+opt]
  if opt=='O0':m.COMMON+=['-fcheck=all','-ffpe-trap=invalid,zero,overflow']
  for arm,tree in [('before',a.baseline_tree.resolve()),('after',ROOT)]:
   key=arm+'-'+opt;report['builds'][key]=m.build(tree,out/key)
  for case,(name,days) in CASES.items():
   for repeat in range(a.repeat):
    for arm in (['before','after'] if repeat%2==0 else ['after','before']):
     key=arm+'-'+opt;folder=out/f'{key}-{case}-{repeat}';folder.mkdir()
     start=time.monotonic();p=subprocess.run([str(out/key/'trajectory'),str(days),str(case)],cwd=folder,capture_output=True,preexec_fn=lambda:os.sched_setaffinity(0,{report['core']}),timeout=90);wall=time.monotonic()-start
     (folder/'stdout').write_bytes(p.stdout);(folder/'stderr').write_bytes(p.stderr)
     rec=dict(arm=arm,opt=opt,case=name,days=days,repeat=repeat,exit=p.returncode,wall_seconds=wall,stdout_sha256=hashlib.sha256(p.stdout).hexdigest())
     series=folder/'trajectory.bin'
     if series.exists():rec['series_sha256']=sha(series)
     t=re.search(rb'CPU=\s*(\S+) WALL=\s*(\S+)',p.stderr)
     if t:rec.update(core_cpu=float(t[1]),core_wall=float(t[2]))
     diag=next((x for x in p.stdout.decode().splitlines() if x.startswith('RICHARDS_AUDIT_RESULT')),'')
     rec['diagnostics']=dict(x.split('=',1) for x in diag.split('|')[1:])
     report['runs'].append(rec)
     (out/'CONTROL.json').write_text(json.dumps(report,indent=2))
     print(key,name,repeat,'exit',p.returncode,flush=True)
   runs=[x for x in report['runs'] if x['opt']==opt and x['case']==name]
   equal=all(x['exit']==0 for x in runs) and len({x.get('series_sha256') for x in runs})==1 and len({x['stdout_sha256'] for x in runs})==1
   row=dict(opt=opt,case=name,days=days,byte_exact_series_and_work=equal)
   for arm in ['before','after']:
    rr=[x for x in runs if x['arm']==arm and 'core_cpu' in x]
    if rr:row[arm]={k:dict(median=statistics.median(x[k] for x in rr),min=min(x[k] for x in rr),max=max(x[k] for x in rr)) for k in ['wall_seconds','core_cpu','core_wall']}
   if 'before' in row and 'after' in row:row['core_speedup']=row['before']['core_cpu']['median']/row['after']['core_cpu']['median']
   report['summary'].append(row);(out/'CONTROL.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report['summary'],indent=2))
 if not all(x['byte_exact_series_and_work'] for x in report['summary']):raise SystemExit(1)
if __name__=='__main__':main()
