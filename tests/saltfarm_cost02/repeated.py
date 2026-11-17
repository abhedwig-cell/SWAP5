"""Private selective interprocedural compile discriminator; same physical source."""
from pathlib import Path
import argparse,contextlib,csv,ctypes,json,shutil,subprocess,sys,zipfile
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--qualification',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();sys.path[:0]=[str(a.source/'app/hybrid_water'),str(a.source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows
out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=a.qualification/'provider';old=a.qualification/'saltfarm-O2-candidate-build';parent=a.qualification/'saltfarm-O2-candidate-full';meta,case=validate_bundle(old,ref,h.SALTFARM);build=out/'build';shutil.copytree(old,build);commands=[]
source=(old/'headcalc.f90').read_text(encoding='cp1252')
source=source.replace('only: swmacro, i_instance','only: swmacro, i_instance, swhyst')
source=source.replace('only: numnod, z, dz, disnod','only: numnod, z, dz, disnod, layer')
source=source.replace('only: watcon, hconduc, moiscap, dhconduc, cofgen','only: watcon, hconduc, moiscap, dhconduc, cofgen, swsophy, fl_use_tables, iHWCKmodel')
anchor='   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at'
assert source.count(anchor)==1
source=source.replace(anchor,anchor+'\nlogical::reuse_analytic,cap_valid(numnod),water_valid(numnod)\nreal(8)::cap_head(numnod),cap_value(numnod),water_head(numnod),water_value(numnod)')
anchor='   mass_polish_at = 0'
assert source.count(anchor)==1
source=source.replace(anchor,'   cap_valid=.false.\n   water_valid=.false.\n   reuse_analytic=swmacro==0.and.swhyst==0.and.swkimpl==0.and.swsophy==0.and..not.fl_use_tables.and.swbotb/=1\n'+anchor)
for function,target,key in [('moiscap','dimoca(i)','cap'),('watcon','theta(i)','water')]:
 anchor=target+' = '+function+'(i, h(i))' if function=='moiscap' else target+' = '+function+'(i,h(i))'
 assert source.count(anchor)==1,anchor
 block=f"""if (reuse_analytic.and.h(i)<0d0.and.iHWCKmodel(layer(i))==1) then
 if ({key}_valid(i)) then
  if(h(i)=={key}_head(i)) then
   {target}={key}_value(i)
  else
   {target}={function}(i,h(i))
  end if
 else
  {target}={function}(i,h(i))
 end if
 {key}_head(i)=h(i)
 {key}_value(i)={target}
 {key}_valid(i)=.true.
else
 {target}={function}(i,h(i))
end if"""
 source=source.replace(anchor,block)
(build/'headcalc.f90').write_text(source,encoding='cp1252')
command=['gfortran',*meta['identity']['donor_flags'],'-I',str(build),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c','headcalc.f90'];commands.append(command);r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
exe=build/'candidate.exe';objects=[build/f.name if (build/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];command=['gfortran','-o',str(exe),*map(str,objects),str(build/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(command);r=subprocess.run(command,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
result={'hypothesis':'Invocation-local exact repeated-head evaluator reuse; same parameters and physical expressions, no iteration or tolerance shortcut','commands':commands,'runs':[]}
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
