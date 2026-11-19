"""One sequential exact-input original/current timing and native phase discriminator."""
from pathlib import Path
import argparse,contextlib,ctypes as c,inspect,json,re,resource,shutil,subprocess,sys,textwrap,time,zipfile
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/solute')]
import daily_host as h
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check,csvlines
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);a=p.parse_args();W=a.work.resolve();REF=W/'provider';B=W/'qualified-O2';meta,case=validate_bundle(B,REF,h.SALTFARM)
LABELS=['root','water','water_update','heat','solute','integral_reset','meteo','time_prepare','bottom','drain','integral_update','advance','output','conductivity','capacity','jacobian','tridiagonal','water_content','vector','convergence','newton_bodies','residual','strict_mass','dynamic','whole_capacity_same_head','whole_water_content_same_head']
result=dict(status='RUNNING',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),baseline='b28706d8b16661d8a9e85339d317256eaca51206',runs=[],profiles={},selection='One isolated Ubuntu26.04 runner; all builds and model calls sequential, unchanged GNU/x86_64 separate-ops flags, original input bytes.15s short/35s full caps. No laptop models launched.')
assert not subprocess.check_output(['git','diff',result['baseline'],'HEAD','--','app','src','reference','tools'],cwd=ROOT)
def save():(W/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
def run(cmd,cwd,cap=45):
 r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=cap);assert r.returncode==0,r.stderr.decode(errors='replace');return r
def original(exe,dest,cap=35):
 # Exactly the existing public output-only preparation, shared with the donor.
 # Literal INLIST_CSV contains the already recorded unsupported S_CONC group.
 h.prepare_column(case,dest,h.ColumnStart('original',0,None,None),True,True,h.SALTFARM)
 start=time.perf_counter();cpu=resource.getrusage(resource.RUSAGE_CHILDREN)
 with (dest/'stdout').open('w') as out,(dest/'stderr').open('w') as err:r=subprocess.run([str(exe),'./swap.swp'],cwd=dest,stdout=out,stderr=err,timeout=cap)
 elapsed=time.perf_counter()-start;after=resource.getrusage(resource.RUSAGE_CHILDREN);assert r.returncode==100,(r.returncode,(dest/'stderr').read_text())
 return dict(seconds=elapsed,child_user=after.ru_utime-cpu.ru_utime,child_system=after.ru_stime-cpu.ru_stime)
def modern(exe,dest,days=1461):
 dest.mkdir();data=[];binding={**meta['binding'],'private_isolated07':dict(donor_sha256=h.sha(exe))}
 def trial():
  with contextlib.ExitStack() as stack:
   host=h.DailyHost(stack,exe,h.executable(B,'day_kernel'),case,dest,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
   with (dest/'daily.jsonl').open('w') as journal:
    for day in range(1,days+1):
     row=host.step(1,checkpoint=day in (109,111,365,367,453,455,1460,1461));assert row['committed'];data.append(row);journal.write(json.dumps(row)+'\n')
   host.close()
 start_cpu=time.process_time();before=resource.getrusage(resource.RUSAGE_CHILDREN);_,seconds=bounded(35 if days==1461 else 15,trial);after=resource.getrusage(resource.RUSAGE_CHILDREN)
 return dict(seconds=seconds,parent_cpu=time.process_time()-start_cpu,child_user=after.ru_utime-before.ru_utime,child_system=after.ru_stime-before.ru_stime,budgets=check(data))
save()
for i,mode in enumerate(('original','canonical','canonical','original')):
 dest=W/f'full{i}-{mode}';item=original(REF/'build/swap_b0_gfortran',dest) if mode=='original' else modern(h.executable(B,'day_donor'),dest)
 if i==2:assert physical(rows(dest))==physical(rows(W/'full1-canonical')) and csvlines(dest/'original/result_output.csv')==csvlines(W/'full1-canonical/original/result_output.csv')
 if i==3:assert csvlines(dest/'result_output.csv')==csvlines(W/'full0-original/result_output.csv')
 if i in (1,2):
  for name in meta['inputs']:assert h.sha(dest/'original'/name)==h.sha(W/'full0-original'/name),name
 result['runs'].append(dict(mode=mode,**item));save();print(result['runs'][-1],flush=True)
MODULE='''module perf07
implicit none
integer(8)::pc(26)=0,pt(26)=0,bt(26)=0,rate=0,now
contains
subroutine tick(i)
integer::i
call system_clock(bt(i),rate)
end subroutine
subroutine tock(i)
integer::i
call system_clock(now)
pc(i)=pc(i)+1;pt(i)=pt(i)+now-bt(i)
end subroutine
end module
'''
commands=[]
def wrap(s,needle,slot):
 assert s.count(needle)==1,(slot,needle);return s.replace(needle,f'call tick({slot})\n'+needle+f'\ncall tock({slot})',1)
def build_profile(mode):
 b=W/('profile-build-'+mode);b.mkdir();selected=REF/'build/swap-selected';source=B if mode=='canonical' else selected
 if mode=='canonical':
  for f in B.iterdir():
   if f.is_file():shutil.copyfile(f,b/f.name)
 (b/'perf07.f90').write_text(MODULE)
 s=(source/'swap.f90').read_text(encoding='cp1252');anchor='use hybrid_day_window, only: return_at_day_end, budget_step, budget_total, checkpoint_clock' if mode=='canonical' else 'use MOD_swap_base,       only: pathwork,';assert s.count(anchor)==1;s=s.replace(anchor,'use perf07\n'+anchor,1)
 lines=['      if (swcrop == 1) call RootExtraction(2)','         if (.NOT.fldecdt) call SoilWater(2)','      call SoilWater(3)','      if (swhea > 0) call SoilTemperature(2)','      if (swsolu > 0) call Solute(2)','      call integral(2)','         call Meteo(3)','         call TimeControl(4)','      call BoundBottom','         if (swdra > 0)    call drain(2)','      call integral(3)','      call TimeControl(3)']
 for i,line in enumerate(lines,1):s=wrap(s,line,i)
 anchor='      if (flOutput) then';assert s.count(anchor)==1;s=s.replace(anchor,'call tick(13)\n'+anchor,1)
 anchor='      if (flDayEnd) then\n         if (swcropsnm == 1) call Soilmanagement(6)';assert s.count(anchor)==1;s=s.replace(anchor,'call tock(13)\n'+anchor,1)
 if mode=='original':
  anchor='   end do\n\n!  Specific for exchange when called as DLL';assert s.count(anchor)==1;s=s.replace(anchor,f'      if(flDayEnd.and.t1900=={int(h.SALTFARM.start_clock+365)}d0)return\n'+anchor,1)
 (b/'swap.f90').write_text(s,encoding='cp1252')
 s=(source/'headcalc.f90').read_text(encoding='cp1252');s,n=re.subn(r'(?m)^subroutine headcalc[^\n]*$',lambda m:m[0]+'\nuse perf07',s,count=1);assert n==1
 def segment(s,start,end,slot):
  assert s.count(start)==s.count(end)==1;(lo,hi)=(s.index(start),s.index(end));assert lo<hi;return s[:lo]+f'call tick({slot})\n'+s[lo:hi]+f'call tock({slot})\n'+s[hi:]
 s=segment(s,'!  reset conductivities (k, kmean) to time level t','!  lower and upper diagnal elements',14)
 s=segment(s,'!     store hold and get moiscap','!     special case: SwKimpl = 1',15)
 s=s.replace('!     store hold and get moiscap','if(numbit>1)then\nif(all(h(1:NN)==hold(1:NN)))pc(25)=pc(25)+1\nend if\n!     store hold and get moiscap',1)
 s=wrap(s,'      call jacobian_F()',16);s=wrap(s,'      call tridag(NN, dFdhU, dFdhM, dFdhL, F, difh, ierror)',17)
 s=segment(s,'!        update theta','!        update gradient in h',18);s=wrap(s,'         call vector_F(2, hgrad)',19)
 s=s.replace('!        update theta','if(all(h(1:NN)==hold(1:NN)))pc(26)=pc(26)+1\n!        update theta',1)
 s=s.replace('   do numbit = 1, MaxIt1','   do numbit = 1, MaxIt1\npc(21)=pc(21)+1',1)
 if mode=='canonical':
  for needle in ('         budget_step=projected_water_residual()','            budget_step = projected_water_residual()'):s=wrap(s,needle,23 if 'budget_step=' in needle else 22)
 (b/'headcalc.f90').write_text(s,encoding='cp1252')
 s=(source/'swap_main.f90').read_text(encoding='cp1252');s=s.replace('program swap_main\n','program swap_main\nuse perf07\n',1)
 anchor='      call swap(iCaller, iTask, tstart_in, tend_in)' if mode=='canonical' else '   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)'
 if mode=='canonical':s=wrap(s,anchor,24)
 else:
  needle='   iTask = 2\n'+anchor;assert s.count(needle)==1;s=s.replace(needle,'   iTask = 2\ncall tick(24)\n'+anchor+'\ncall tock(24)',1)
 anchor='   call IterTime(3)';assert s.count(anchor)==1;s=s.replace(anchor,anchor+"\nwrite(*,'(a,*(1x,i0))')'PERF07',pc,pt,rate",1);(b/'swap_main.f90').write_text(s,encoding='cp1252')
 flags=meta['identity']['donor_flags'];common=['gfortran',*flags,'-I',str(b),'-I',str(REF/'build/swap-obj'),'-I',str(REF/'build/ttutil-obj')]
 for name in ('perf07','swap','headcalc','swap_main'):
  cmd=[*common,'-c',name+'.f90'];commands.append(cmd);run(cmd,b)
 objects=[b/f.name if (b/f.name).exists() else f for f in sorted((REF/'build/swap-obj').glob('*.o'))];exe=b/'diagnostic';cmd=['gfortran','-o',exe,*objects,b/'perf07.o',*([b/'hybrid_step_budget.o'] if mode=='canonical' else []),REF/'build/ttutil-obj/libttutil.a'];commands.append(list(map(str,cmd)));run(cmd,b);return exe
for mode in ('original','canonical'):
 exe=build_profile(mode);dest=W/('profile-'+mode);item=original(exe,dest,15) if mode=='original' else modern(exe,dest,365)
 if mode=='original':assert csvlines(dest/'result_output.csv')==csvlines(W/'full0-original/result_output.csv')[:367]
 else:assert physical(rows(dest))==physical(rows(W/'full1-canonical')[:365]) and csvlines(dest/'original/result_output.csv')==csvlines(W/'full1-canonical/original/result_output.csv')[:367]
 stdout=dest/('stdout' if mode=='original' else 'original/donor.stdout');v=list(map(int,next(x for x in stdout.read_text().splitlines() if x.startswith('PERF07')).split()[1:]));assert len(v)==53
 item['phases']={n:dict(calls=v[i],seconds=v[i+26]/v[52]) for i,n in enumerate(LABELS)};result['profiles'][mode]=item;save();print(mode,item,flush=True)
result.update(status='ISOLATED_ORIGINAL_CURRENT_FULL_AND_NATIVE_PHASES_EXACT',commands=commands);save()
# Revisit the previously inconclusive typed-reply candidate only after the
# changed discriminator: one isolated runner, paired actual process CPU.
from direct_day_kernel import NativeDayKernel
original_step=h.DailyHost.step
def typed_reply(process,values):
 if not isinstance(process,NativeDayKernel):return h.send(process,' '.join(map(str,values)))
 if process.cancelled:raise TimeoutError('Direct day kernel cancelled')
 if process.done or process.stage!=4:raise ValueError('Invalid typed reply lifecycle')
 if len(values)!=process.nodes+12:raise ValueError('Incomplete typed reply')
 reply=(c.c_double*len(values))(*values);out,status=(c.c_double*4)(),c.c_int()
 process.lib.dk_apply(process.handle,process.column,process.day,len(values),reply,out,c.byref(status));process.checked(status,(0,1));key='DAILY_ACCEPTED' if status.value==1 else 'DAILY_REFUSED'
 process.queue.append((key,list(map(str,[process.column,process.day,int(out[0]),out[1],out[2]]))));process.stage=3
namespace=dict(h.__dict__,typed_reply=typed_reply);source=textwrap.dedent(inspect.getsource(original_step));needle='send(self.host, " ".join(map(str, reply)))';assert source.count(needle)==1;exec(source.replace(needle,'typed_reply(self.host,reply)'),namespace);candidate_step=namespace['step']
result['candidate']=[];save()
for i,mode in enumerate(('canonical','typed','typed','canonical')):
 h.DailyHost.step=candidate_step if mode=='typed' else original_step
 short=W/f'candidate-short{i}-{mode}';item=modern(h.executable(B,'day_donor'),short,35);assert physical(rows(short))==physical(rows(W/'full1-canonical')[:35]);assert csvlines(short/'original/result_output.csv')==csvlines(W/'full1-canonical/original/result_output.csv')[:37]
 dest=W/f'candidate-full{i}-{mode}';item=modern(h.executable(B,'day_donor'),dest);assert physical(rows(dest))==physical(rows(W/'full1-canonical'));assert csvlines(dest/'original/result_output.csv')==csvlines(W/'full1-canonical/original/result_output.csv')
 for day in (109,111,365,367,453,455,1460,1461):
  with zipfile.ZipFile(dest/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(W/f'full1-canonical/accepted-column-1-day-{day}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 result['candidate'].append(dict(mode=mode,**item));save();print('CANDIDATE',result['candidate'][-1],flush=True)
h.DailyHost.step=candidate_step;result['candidate_cold']=[]
for low,high in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
 warm=W/'candidate-full1-typed';checkpoint=warm/f'accepted-column-1-day-{low}.zip';digest=h.sha(checkpoint);binding={**meta['binding'],'private_isolated07':dict(donor_sha256=h.sha(h.executable(B,'day_donor')))};origin=W/f'candidate-origin{low}-{high}';receipt=h.verify_checkpoint(checkpoint,low,binding,origin);dest=W/f'candidate-cold{low}-{high}';dest.mkdir()
 def resume():return h.run(h.executable(B,'day_donor'),h.executable(B,'day_kernel'),case,dest,high,checkpoint_day=low,origin=origin,origin_receipt=receipt,runtime=True,publish_day=high,checkpoint_binding=binding,model=h.SALTFARM.model,project=h.SALTFARM)
 item,seconds=bounded(35,resume);assert item['first_refusal'] is None;assert physical(rows(dest))==physical(rows(warm)[low:high]);check(rows(dest));assert csvlines(dest/'original/result_output.csv')[-(high-low):]==csvlines(warm/'original/result_output.csv')[low+2:high+2];assert h.sha(checkpoint)==digest
 with zipfile.ZipFile(dest/f'accepted-column-1-day-{high}.zip') as x,zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as y:assert all(x.read(n)==y.read(n) for n in ('result.end','macro.bin'))
 result['candidate_cold'].append(dict(start=low,end=high,seconds=seconds,exact_native_physical_csv=True,origin_unchanged=True));save()
h.DailyHost.step=original_step;result['status']='ISOLATED_COMPARISON_AND_TYPED_FULL_COLD_EXACT';save()
