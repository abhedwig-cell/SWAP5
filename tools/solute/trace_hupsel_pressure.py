"""Private pressure/iteration observation or EOD proposal experiment; never a supported build or restart."""
import argparse,hashlib,json,math,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--reference',type=Path);p.add_argument('--bundle',type=Path);p.add_argument('--full',type=Path)
p.add_argument('--last',type=int,default=567);p.add_argument('--first-trace',type=int,default=547)
p.add_argument('--preserve-eod-proposal',action='store_true');p.add_argument('--reset-daily-proposal',action='store_true');p.add_argument('--activate-day',type=int,default=562)
a=p.parse_args();assert not(a.preserve_eod_proposal and a.reset_daily_proposal);a.output=a.output.resolve();a.output.mkdir();events=[]
def call(label,command,timeout=60,**kw):
    t=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=kw.pop('cwd',ROOT),capture_output=True,text=True,timeout=timeout,**kw)
    (a.output/(label+'.log')).write_text(r.stdout+r.stderr,encoding='utf8')
    events.append(dict(label=label,command=list(map(str,command)),seconds=time.perf_counter()-t,returncode=r.returncode))
    (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert r.returncode==0,(label,r.stderr)
cli=[sys.executable,'-B',ROOT/'tools/solute/run_water.py','--no-macro-release']
reference=(a.reference or a.output/'provider').resolve()
if not a.reference:call('prepare',cli+['--prepare-sources','--reference-work',reference],240)
bundle=(a.bundle or a.output/'bundle').resolve();base=cli+['--reference-work',reference,'--model',h.HUPSEL.model]
if not a.bundle:call('build',base+['--build-only','--output',bundle],120)
full=(a.full or a.output/'cold-input').resolve()
if not a.full:call('cold-input',base+['--build-bundle',bundle,'--output',full,'--days',1])
meta=json.loads((bundle/'BUILD.json').read_text());assert meta['identity']['compiler_sha256']==h.sha(Path(shutil.which('gfortran'))), 'Different compiler/provider cohort';assert meta['identity']['floating_point_profile']==h.no_macro_fp_profile()
# The donor is intentionally private. Its changed bytes are not written into a
# production BUILD identity and no foreign native checkpoint is loaded.
private=a.output/'observer';private.mkdir();source=(bundle/'headcalc.f90').read_text(encoding='cp1252')
start=h.HUPSEL.start_clock+a.first_trace-1;stop=h.HUPSEL.start_clock+a.last
condition=f'(t1900>={start}d0.and.t1900<{stop}d0)'
anchor='      if (budget_enabled .and. .not.flnonconv) then';assert source.count(anchor)==1
source=source.replace(anchor,f'''      if {condition} write(*,'(a,2(1x,es25.17e3),1x,i0,1x,l1,4(1x,es25.17e3))') &
        'PS_ORIGINAL',t1900,dt,numbit,flnonconv,Fmax,sum1,h(8),theta(8)
'''+anchor)
anchor='      if (.NOT.flnonconv) then      ! convergence has been reached';assert source.count(anchor)==1
source=source.replace(anchor,f'''      if {condition} write(*,'(a,2(1x,es25.17e3),2(1x,i0),1x,l1,2(1x,es25.17e3))') &
        'PS_DECISION',t1900,dt,numbit,mass_polish_at,flnonconv,budget_step,budget_total
'''+anchor)
anchor='         itnumb(min(100,numbit),1)';assert source.count(anchor)==1
source=source.replace(anchor,f'''         if {condition} write(*,'(a,2(1x,es25.17e3),2(1x,i0),2(1x,es25.17e3))') &
           'PS_ACCEPT',t1900,dt,numbit,mass_polish_at,h(8),theta(8)
'''+anchor)
(private/'headcalc.f90').write_text(source,encoding='cp1252')
csv=(bundle/'swap_csv_output.f90').read_text(encoding='cp1252');anchor='   subroutine set_values_scalar()';assert csv.count(anchor)==1
csv=csv.replace(anchor,anchor+'\n   use variables, only: ps_h=>h,ps_theta=>theta,itnumb')
anchor='   dstor_1    = wasrdm1 - iwasrdm1beg';assert csv.count(anchor)==1
csv=csv.replace(anchor,"   write(*,'(a,*(1x,es25.17e3))') 'PS_HEAD',ps_h(1:numnod)\n   write(*,'(a,*(1x,es25.17e3))') 'PS_THETA',ps_theta(1:numnod)\n   write(*,'(a,*(1x,i0))') 'PS_HIST',itnumb(:,1)\n"+anchor)
(private/'swap_csv_output.f90').write_text(csv,encoding='cp1252')
names=['headcalc','swap_csv_output']
if a.reset_daily_proposal:
    timer=(reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    anchor='         dt = max(dt, dsqrt(dtmin*dtmax))';assert timer.count(anchor)==1
    active=h.HUPSEL.start_clock+a.activate_day-1
    timer=timer.replace(anchor,f"""         if (t1900>={active}d0) then
            dt=dtmax
         else
{anchor}
         end if""")
    (private/'timecontrol.f90').write_text(timer,encoding='cp1252');names.insert(0,'timecontrol')

if a.preserve_eod_proposal:
    timer=(reference/'build/swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    timer=timer.replace('   real(8), save :: tcumold','   real(8), save :: tcumold\n   real(8), save :: ps_proposed_dt=0d0\n   logical, save :: ps_eod_clipped=.false.')
    anchor='   case (1)';assert timer.count(anchor)>=1
    timer=timer.replace(anchor,anchor+'\n      ps_proposed_dt=0d0\n      ps_eod_clipped=.false.',1)
    active=h.HUPSEL.start_clock+a.activate_day-1
    anchor='! 2.9 determine next time step, based on numerical performance';assert timer.count(anchor)==1
    timer=timer.replace(anchor,f"""      if (t1900>={active}d0.and.fldayend.and.ps_eod_clipped) then
         dt=ps_proposed_dt
         ps_eod_clipped=.false.
      end if
"""+anchor)
    # Only the EOD event cut is separated from the controller proposal.
    # The original iteration feedback, event restrictions and flux integration stay.
    marker='      dtEvent = get_dtevent()';pos=timer.index('! 2.7  maximum size of time interval (dtEvent)');a1,b1=timer[:pos],timer[pos:]
    assert b1.count(marker)==1
    b1=b1.replace(marker,marker+f"""
      if (t1900>={active}d0) then
         ps_proposed_dt=dt
         ps_eod_clipped=(tcum+dtCrit<1d0.and.dtEvent==1d0-tcum.and.dt>dtEvent)
      end if""",1);timer=a1+b1
    (private/'timecontrol.f90').write_text(timer,encoding='cp1252');names.insert(0,'timecontrol')
for name in names:
    call(name+'-compile',['gfortran',*meta['identity']['donor_flags'],'-I',private,'-I',bundle,'-I',reference/'build/swap-obj','-I',reference/'build/ttutil-obj','-c',name+'.f90'],cwd=private)
objects=[]
for original in sorted((reference/'build/swap-obj').glob('*.o')):
    objects.append(next(q for q in (private/original.name,bundle/original.name,original) if q.exists()))
exe=private/('diagnostic.exe' if sys.platform=='win32' else 'diagnostic')
call('link',['gfortran','-o',exe,*objects,bundle/'hybrid_step_budget.o',reference/'build/ttutil-obj/libttutil.a'])
case=private/'case';case.mkdir()
for name in meta['inputs']:
    (case/name).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(full/'original'/name,case/name)
payload=''.join(f'{day} -1\n' for day in range(1,a.last+1))+'0 -1\n';beg=time.perf_counter()
with (private/'stdout').open('wb') as stdout,(private/'stderr').open('wb') as stderr:
    r=subprocess.run([str(exe),'./swap.swp'],cwd=case,input=payload.encode(),stdout=stdout,stderr=stderr,timeout=60)
seconds=time.perf_counter()-beg;assert r.returncode==100,r.returncode
frames={};traces=[]
for line in (private/'stdout').read_text(encoding='cp1252').splitlines():
    tag,*v=line.split() if line.strip() else ['']
    if tag in ('PS_HEAD','PS_THETA','PS_HIST','HYBRID_STOCK_FLUX','HYBRID_EXTERNAL_FLUX','HYBRID_SOLUTE_LEDGER','HYBRID_UPTAKE'):
        frames.setdefault(tag,[]).append(list(map(float,v)))
    if tag in ('PS_ORIGINAL','PS_DECISION','PS_ACCEPT'):traces.append(line)
assert all(len(v)==a.last+1 for v in frames.values())
maxwater=maxsolute=0.
for day in range(1,a.last+1):
    s=frames['HYBRID_STOCK_FLUX'][day];q=frames['HYBRID_EXTERNAL_FLUX'][day];v=frames['HYBRID_SOLUTE_LEDGER'][day]
    water=math.fsum([*q[:7],*(-x for x in q[7:]),*s[6:],*(-x for x in s[:6])]);end,delta,rain,irrig,bottom,drain,decay,root,reported=v
    solute=math.fsum([end,-frames['HYBRID_SOLUTE_LEDGER'][day-1][0],-rain,-irrig,-bottom,drain,decay,root])
    maxwater=max(maxwater,abs(water));maxsolute=max(maxsolute,abs(solute),abs(reported))
    if maxwater>1e-10 or maxsolute>1e-10:
        (a.output/'FRAMES.json').write_text(json.dumps(frames)+'\n');(a.output/'TRACE.txt').write_text('\n'.join(traces)+'\n')
        (a.output/'RESULT.json').write_text(json.dumps(dict(status='REJECTED_UNCHANGED_GUARD',day=day,maximum_water_cm=maxwater,maximum_solute_mg_cm2=maxsolute,model_seconds=seconds,private_eod_proposal=a.preserve_eod_proposal,private_daily_proposal=a.reset_daily_proposal),indent=2)+'\n')
        raise AssertionError(('unchanged guard',day,maxwater,maxsolute))
preservation='NOT_TESTED_NO_PUBLIC_PREFIX_GIVEN'
if (full/'daily.jsonl').exists():
    prior=[json.loads(s) for s in (full/'daily.jsonl').read_text().splitlines()]
    if len(prior)>=a.last:
        for day,row in enumerate(prior[:min(a.last,a.activate_day-1) if (a.preserve_eod_proposal or a.reset_daily_proposal) else a.last],1):
            assert frames['PS_HEAD'][day]==row['pressure_head_cm'],('observer_changed_head',day)
            assert frames['HYBRID_STOCK_FLUX'][day][:6]==row['stock_end_cm'],('observer_changed_stock',day)
            assert frames['HYBRID_EXTERNAL_FLUX'][day]==row['external_flux_cm'],('observer_changed_flow',day)
            assert frames['HYBRID_UPTAKE'][day]==row['uptake_terms_cm'],('observer_changed_uptake',day)
        preservation=('NO_PREACTIVATION_DAYS' if a.activate_day==1 else 'PRE_ACTIVATION_PUBLIC_PREFIX_EXACT') if (a.preserve_eod_proposal or a.reset_daily_proposal) else 'ALL_PUBLIC_PREFIX_HEAD_STOCK_FLOW_UPTAKE_EXACT'
(a.output/'FRAMES.json').write_text(json.dumps(frames)+'\n');(a.output/'TRACE.txt').write_text('\n'.join(traces)+'\n')
result=dict(status='PRIVATE_DAILY_NOMINAL_POLICY_NOT_ADMITTED' if a.reset_daily_proposal else 'PRIVATE_EOD_PROPOSAL_POLICY_NOT_ADMITTED' if a.preserve_eod_proposal else 'PRIVATE_READ_ONLY_PRESSURE_OBSERVATION_NOT_PRODUCTION_QUALIFICATION',private_eod_proposal=a.preserve_eod_proposal,private_daily_proposal=a.reset_daily_proposal,activation_day=a.activate_day if (a.preserve_eod_proposal or a.reset_daily_proposal) else None,source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),days=a.last,first_trace=a.first_trace,model_seconds=seconds,maximum_water_cm=maxwater,maximum_solute_mg_cm2=maxsolute,public_prefix=preservation,profile=meta['identity']['floating_point_profile'],compiler_sha256=meta['identity']['compiler_sha256'],private_executable_sha256=h.sha(exe),base_identity=meta['identity'],events=events)
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:result[k] for k in ('status','days','model_seconds','public_prefix','maximum_water_cm')}),flush=True)
