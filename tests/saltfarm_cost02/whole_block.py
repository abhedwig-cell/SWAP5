"""Private selective interprocedural compile discriminator; same physical source."""
from pathlib import Path
import argparse,contextlib,csv,ctypes,json,shutil,subprocess,sys,zipfile
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();sys.path[:0]=[str(a.source/'app/hybrid_water'),str(a.source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.qualification/'provider';old=a.qualification/'saltfarm-O2-candidate-build';parent=a.qualification/'saltfarm-O2-candidate-full';meta,case=validate_bundle(old,ref,h.SALTFARM);build=out/'build';shutil.copytree(old,build);commands=[]
names=[p.stem for p in sorted((ref/'build/swap-selected').glob('*.f90'))]+['hybrid_step_budget']
for name in names:
 src=old/(name+'.f90')
 if name=='hybrid_step_budget':src=a.source/'app/hybrid_water/hybrid_step_budget.f90'
 if not src.exists():src=ref/'build/swap-selected'/(name+'.f90')
 shutil.copyfile(src,build/(name+'.f90'))
 flags=['-O3' if flag=='-O2' else flag for flag in meta['identity']['donor_flags']]
 command=['gfortran',*flags,'-I',str(build),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c',name+'.f90'];commands.append(command);r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=45);(build/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
exe=build/'candidate.exe';objects=[build/f.name if (build/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];command=['gfortran','-O3',*h.NO_MACRO_FP_FLAGS,'-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(command);r=subprocess.run(command,capture_output=True,text=True,timeout=60);(build/'link.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
result={'hypothesis':'Reassessed whole original block O3 with unchanged arithmetic safety, formulas and solver/state contracts','commands':commands,'runs':[]}
for i,mode in enumerate(('baseline','candidate','candidate','baseline')):
 folder=out/(str(i)+'-'+mode);folder.mkdir()
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,h.executable(old,'day_donor') if mode=='baseline' else exe,h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding={**meta['binding'],'private_cost_control':mode},model=h.SALTFARM.model,project=h.SALTFARM)
   data=[]
   with (folder/'daily.jsonl').open('w') as journal:
    for day in range(1,366):
     row=host.step(1,checkpoint=day==109);assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
   host.close()
   from ctypes import wintypes
   process=host.columns[0].worker;c,e,k,u=(wintypes.FILETIME() for _ in range(4));get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL
   assert get(int(process._handle),ctypes.byref(c),ctypes.byref(e),ctypes.byref(k),ctypes.byref(u))
   sec=lambda v:((v.dwHighDateTime<<32)+v.dwLowDateTime)/1e7
   return data,dict(user=sec(u),system=sec(k))
 (data,cpu),seconds=bounded(15,trial);assert physical(data)==physical(rows(parent)[:365])
 with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(parent/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 parse=lambda p:list(csv.DictReader(s for s in p.read_text().splitlines() if s.strip() and not s.startswith('*')))
 assert parse(folder/'original/result_output.csv')==parse(parent/'original/result_output.csv')[:366]
 result['runs'].append(dict(mode=mode,seconds=seconds,donor_cpu=cpu,exact_physical=True,exact_csv=True,exact_native109=True));(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['runs'][-1],flush=True)
