"""Private bounded same-source clocks; never modifies a supported bundle."""
from pathlib import Path
import argparse,contextlib,ctypes,json,re,shutil,subprocess,sys,time,zipfile
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();w=a.work.resolve();source=w/'source';sys.path[:0]=[str(source/'app/hybrid_water'),str(source/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
ref=Path(r'C:\SWAP5-testing\rc3-local01\provider');old=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\qualified-O2');candidate=Path(r'C:\SWAP5-testing\saltfarm-newton-close01\accept-O2/full');control=Path(r'C:\SWAP5-testing\saltfarm-newton-work01\timing/0-control');control_native=Path(r'C:\SWAP5-testing\rc3-local01\saltfarm-O2-candidate-full');meta,case=validate_bundle(old,ref,h.SALTFARM)
module='''module perf_clock
implicit none
integer(8)::pc(8)=0,pt(8)=0,prate=0,pbegin,phead,piter,pnow
integer::pidx
end module
'''
labels=['root','water_solve','water_update','heat','solute','head_setup','ordinary_iteration','padding_iteration'];builds={};commands=[]
for mode,instrumented in [('control',False),('control',True),('candidate',True)]:
 tag=mode+('-clock' if instrumented else '-plain');b=w/tag;shutil.copytree(old,b);src=(old/'headcalc.f90').read_text(encoding='cp1252')
 if mode=='control':
  needle='if (.not.flnonconv .and. mass_polish_at==0 .and. &\n             abs(budget_total+budget_step)>0.5d0*1d-10*(t1900-budget_start+dt)) then';assert src.count(needle)==1;src=src.replace(needle,'if (.not.flnonconv .and. mass_polish_at==0) then')
  assert src==Path(r'C:\SWAP5-testing\saltfarm-newton-work01\control-O2\headcalc.f90').read_text(encoding='cp1252')
 names=['headcalc']
 if instrumented:
  (b/'perf_clock.f90').write_text(module);names=['perf_clock','headcalc','swap','swap_main'];src=src.replace('\nsubroutine headcalc\n','\nsubroutine headcalc\nuse perf_clock\n',1)
  needle='   if (fldaystart) then';assert src.count(needle)==1;src=src.replace(needle,'   call system_clock(phead,prate)\n'+needle)
  needle='   do numbit = 1, MaxIt1';assert src.count(needle)==1;src=src.replace(needle,'   call system_clock(pnow)\n   pc(6)=pc(6)+1\n   pt(6)=pt(6)+pnow-phead\n'+needle+'\n      call system_clock(piter)')
  needle='      if (flnonconv) hybrid_physical_iterations=0';assert src.count(needle)==1;src=src.replace(needle,'      call system_clock(pnow)\n      pidx=7\n      if(mass_polish_at>0)pidx=8\n      pc(pidx)=pc(pidx)+1\n      pt(pidx)=pt(pidx)+pnow-piter\n'+needle)
  swap=(old/'swap.f90').read_text(encoding='cp1252');needle='use hybrid_day_window, only: return_at_day_end, budget_step, budget_total, checkpoint_clock';assert swap.count(needle)==1;swap=swap.replace(needle,'use perf_clock\n'+needle)
  lines=['      if (swcrop == 1) call RootExtraction(2)','         if (.NOT.fldecdt) call SoilWater(2)','      call SoilWater(3)','      if (swhea > 0) call SoilTemperature(2)','      if (swsolu > 0) call Solute(2)']
  for i,line in enumerate(lines,1):
   assert swap.count(line)==1;swap=swap.replace(line,f'call system_clock(pbegin,prate)\n{line}\ncall system_clock(pnow)\npc({i})=pc({i})+1\npt({i})=pt({i})+pnow-pbegin')
  (b/'swap.f90').write_text(swap,encoding='cp1252');main=(old/'swap_main.f90').read_text(encoding='cp1252').replace('use iso_fortran_env, only: output_unit','use perf_clock\nuse iso_fortran_env, only: output_unit');needle="      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900";assert main.count(needle)==1;main=main.replace(needle,"      if(window==365)write(*,'(a,*(1x,i0))')'PERF_CLOCK',pc,pt,prate\n"+needle);(b/'swap_main.f90').write_text(main,encoding='cp1252')
 (b/'headcalc.f90').write_text(src,encoding='cp1252')
 for name in names:
  cmd=['gfortran',*meta['identity']['donor_flags'],'-I',str(b),'-I',str(ref/'build/swap-obj'),'-I',str(ref/'build/ttutil-obj'),'-c',name+'.f90'];commands.append(cmd);r=subprocess.run(cmd,cwd=b,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr
 objects=[b/f.name if (b/f.name).exists() else f for f in sorted((ref/'build/swap-obj').glob('*.o'))];exe=b/'diagnostic.exe';cmd=['gfortran','-o',str(exe),*map(str,objects),*([str(b/'perf_clock.o')] if instrumented else []),str(b/'hybrid_step_budget.o'),str(ref/'build/ttutil-obj/libttutil.a')];commands.append(cmd);r=subprocess.run(cmd,capture_output=True,text=True,timeout=45);assert r.returncode==0,r.stderr;builds[tag]=exe
builds['candidate-plain']=h.executable(old,'day_donor');(w/'COMMANDS.json').write_text(json.dumps(commands,indent=2))
def cpu(process):
 from ctypes import wintypes
 c,e,k,u=(wintypes.FILETIME() for _ in range(4));get=ctypes.windll.kernel32.GetProcessTimes;get.argtypes=[wintypes.HANDLE,*([ctypes.POINTER(wintypes.FILETIME)]*4)];get.restype=wintypes.BOOL;assert get(int(process._handle),ctypes.byref(c),ctypes.byref(e),ctypes.byref(k),ctypes.byref(u));sec=lambda x:((x.dwHighDateTime<<32)+x.dwLowDateTime)/1e7;return dict(user=sec(u),system=sec(k))
results=[]
for inst in (False,True):
 for mode in ('control','candidate','candidate','control'):
  tag=mode+('-clock' if inst else '-plain');folder=w/('run'+str(len(results))+'-'+tag);folder.mkdir();data=[];binding={**meta['binding'],'private_cost03':dict(mode=mode,instrumented=inst,source=h.sha(builds[tag].parent/'headcalc.f90'))}
  def trial():
   started=time.process_time()
   with contextlib.ExitStack() as stack:
    host=h.DailyHost(stack,builds[tag],h.executable(old,'day_kernel'),case,folder,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
    with (folder/'daily.jsonl').open('w') as journal:
     for day in range(1,366):
      row=host.step(1,checkpoint=day in (109,111));assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
    host.close()
   return dict(python=time.process_time()-started,donor=cpu(host.columns[0].worker),kernel=cpu(host.host))
  cpus,elapsed=bounded(15,trial);parent=candidate if mode=='candidate' else control;assert physical(data)==physical(rows(parent)[:365]);budgets=check(data);assert csvlines(folder/'original/result_output.csv')==csvlines(parent/'original/result_output.csv')[:367]
  origin_parent=candidate if mode=='candidate' else control_native
  with zipfile.ZipFile(folder/'accepted-column-1-day-109.zip') as x,zipfile.ZipFile(origin_parent/'accepted-column-1-day-109.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
  result=dict(mode=mode,instrumented=inst,days=365,wall=elapsed,cpu=cpus,budgets=budgets,exact_physical_csv=True,exact_native109=True,folder=str(folder))
  hist=re.findall(r'^\s+(\d+)\s+(\d+)\s+(\d+)\s*$',(folder/'original/swap.log').read_text(),re.M);result['iterations']=sum(int(n)*int(c) for n,c,b in hist);result['headcalc_calls']=sum(int(c) for n,c,b in hist)
  if inst:
   words=[s.split()[1:] for s in (folder/'original/donor.stdout').read_text().splitlines() if s.startswith('PERF_CLOCK')];assert len(words)==1 and len(words[0])==17;values=list(map(int,words[0]));result['phases']={label:dict(calls=values[i],seconds=values[i+8]/values[16]) for i,label in enumerate(labels)};assert values[5]==result['headcalc_calls'] and values[6]+values[7]==result['iterations']
  results.append(result);(w/'RESULT.json').write_text(json.dumps(results,indent=2));print(json.dumps({k:v for k,v in result.items() if k not in ('budgets','folder')}),flush=True)
# One actual short cold worker per instrumented policy; counters never enter native state.
restarts=[]
for mode in ('control','candidate'):
 run=next(r for r in results if r['mode']==mode and r['instrumented']);folder=Path(run['folder']);b=builds[mode+'-clock'];binding={**meta['binding'],'private_cost03':dict(mode=mode,instrumented=True,source=h.sha(b.parent/'headcalc.f90'))};origin=w/('origin-'+mode);receipt=h.verify_checkpoint(folder/'accepted-column-1-day-109.zip',109,binding,origin);dest=w/('restart-'+mode);dest.mkdir()
 def resume():return h.run(b,h.executable(old,'day_kernel'),case,dest,111,checkpoint_day=109,origin=origin,origin_receipt=receipt,runtime=True,publish_day=111,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
 r,elapsed=bounded(15,resume);assert r['first_refusal'] is None;actual=rows(dest);check(actual);assert physical(actual)==physical(rows(folder)[109:111]);assert csvlines(dest/'original/result_output.csv')[-2:]==csvlines(folder/'original/result_output.csv')[111:113]
 with zipfile.ZipFile(dest/'accepted-column-1-day-111.zip') as x,zipfile.ZipFile(folder/'accepted-column-1-day-111.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 restarts.append(dict(mode=mode,exact_physical_csv_native=True,seconds=elapsed))
(w/'RESTART.json').write_text(json.dumps(restarts,indent=2));print('BOTH_SHORT_NATIVE_RESTARTS_EXACT')
