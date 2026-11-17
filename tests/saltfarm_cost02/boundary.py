"""Paired real-worker boundary discriminator; unchanged physical binaries."""
from pathlib import Path
import argparse,contextlib,csv,ctypes,json,shutil,subprocess,sys,zipfile
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--days',type=int,default=365);a=p.parse_args();sys.path[:0]=[str(a.source/'app/hybrid_water'),str(a.source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.qualification/'provider';old=a.qualification/'saltfarm-O2-candidate-build';parent=a.qualification/'saltfarm-O2-candidate-full';meta,case=validate_bundle(old,ref,h.SALTFARM);build=out/'build';shutil.copytree(old,build);commands=[]
import ast
candidate=ast.parse((Path(__file__).resolve().parents[2]/'app/hybrid_water/daily_host.py').read_text())
receive=next(n for n in candidate.body if isinstance(n,ast.FunctionDef) and n.name=='receive')
step=next(n for n in next(n for n in candidate.body if isinstance(n,ast.ClassDef) and n.name=='DailyHost').body if isinstance(n,ast.FunctionDef) and n.name=='step')
old_receive=h.receive;old_step=h.DailyHost.step;namespace=dict(h.__dict__);exec(compile(ast.Module(body=[receive,step],type_ignores=[]),'private-boundary-discriminator','exec'),namespace)
exe=h.executable(old,'day_donor')
result={'hypothesis':'Boundary-only redundant decimal reformat and per-line transcript flush removal; unchanged native worker and accepted-day durability','commands':commands,'runs':[]}
for i,mode in enumerate(('baseline','candidate','candidate','baseline')):
 h.receive=old_receive if mode=='baseline' else namespace['receive'];h.DailyHost.step=old_step if mode=='baseline' else namespace['step']
 # Method globals must see the selected receive function too.
 namespace['receive']=h.receive
 folder=out/(str(i)+'-'+mode);folder.mkdir()
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(old,'day_donor') if mode=='baseline' else exe,h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'private_cost_control':mode},model=h.SALTFARM.model,project=h.SALTFARM)
   data=[]
   with (folder/'daily.jsonl').open('w') as journal:
    for day in range(1,a.days+1):
     row=host.step(1,checkpoint=day in {109,1461});assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
   host.close()
   from ctypes import wintypes
   process=host.columns[0].worker;c,e,k,u=(wintypes.FILETIME() for _ in range(4));get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL
   assert get(int(process._handle),ctypes.byref(c),ctypes.byref(e),ctypes.byref(k),ctypes.byref(u))
   sec=lambda v:((v.dwHighDateTime<<32)+v.dwLowDateTime)/1e7
   return data,dict(user=sec(u),system=sec(k))
 (data,cpu),seconds=bounded(15,trial);assert physical(data)==physical(rows(parent)[:a.days])
 with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(parent/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 parse=lambda p:list(csv.DictReader(s for s in p.read_text().splitlines() if s.strip() and not s.startswith('*')))
 assert parse(folder/'original/result_output.csv')==parse(parent/'original/result_output.csv')[:a.days+1]
 if a.days==1461:
  with zipfile.ZipFile(folder/'accepted-column-1-day-1461.zip') as x,zipfile.ZipFile(a.qualification/'saltfarm-O2-control/accepted-column-1-day-1461.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 result['runs'].append(dict(mode=mode,seconds=seconds,donor_cpu=cpu,exact_physical=True,exact_csv=True,exact_native109=True));(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['runs'][-1],flush=True)
