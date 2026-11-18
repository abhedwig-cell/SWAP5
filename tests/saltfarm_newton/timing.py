"""Sequential ABBA on two current bound builds; no concurrent compilation."""
from pathlib import Path
from dataclasses import replace
import argparse,contextlib,json,sys,ctypes,re
root=Path(__file__).resolve().parents[2];sys.path[:0]=[str(root/'app/hybrid_water'),str(root/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);a=p.parse_args();out=a.work/'timing';out.mkdir();result=[]
for i,mode in enumerate(('control','candidate','candidate','control')):
 project=replace(h.SALTFARM,water_polish_policy=h.ALWAYS_WATER_POLISH) if mode=='control' else h.SALTFARM;h.PROJECTS=tuple(project if x.case==project.case else x for x in h.PROJECTS)
 bundle=a.work/('control-O2' if mode=='control' else 'qualified-O2');meta,case=validate_bundle(bundle,a.reference,project);folder=out/(str(i)+'-'+mode);folder.mkdir();data=[]
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
   with (folder/'daily.jsonl').open('w') as journal:
    for day in range(1,1462):
     row=host.step(1);assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
   host.close()
   from ctypes import wintypes
   c,e,k,u=(wintypes.FILETIME() for _ in range(4));get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL;assert get(int(host.columns[0].worker._handle),ctypes.byref(c),ctypes.byref(e),ctypes.byref(k),ctypes.byref(u));sec=lambda x:((x.dwHighDateTime<<32)+x.dwLowDateTime)/1e7
   return dict(user=sec(u),system=sec(k))
 cpu,seconds=bounded(25,trial);budgets=check(data)
 if mode=='candidate':assert physical(data)==physical(rows(a.work/'accept-O2/full'))
 else:
  if i==0:control=data
  else:assert physical(data)==physical(control)
 hist={int(n):dict(calls=int(c),btr=int(b)) for n,c,b in re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s*$',(folder/'original/swap.log').read_text(),re.M)}
 result.append(dict(mode=mode,days=len(data),seconds=seconds,donor_cpu=cpu,budgets=budgets,iterations=sum(n*v['calls'] for n,v in hist.items()),headcalc_calls=sum(v['calls'] for v in hist.values()),histogram=hist,build_sha256=h.sha(bundle/'BUILD.json')))
 (out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({k:v for k,v in result[-1].items() if k not in ('histogram','budgets') }),flush=True)
