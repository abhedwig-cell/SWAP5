"""Bounded real-context retry and native own-file restart qualification."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time,zipfile,re,sys
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent
PREV=R.parent/'swap431-macro-b1-contract06'
OLD=Path('C:/Users/Veldh012/swap431-state02-work')
WORK=Path('C:/Users/Veldh012/swap431-retry07-work')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

def prepare():
    original=(OLD/'audit/build/swap-selected/soilwater.f90').read_text(encoding='cp1252')
    soil=original.replace('   public :: soilwater, soilwaterstatevar','''   public :: soilwater, soilwaterstatevar,retry07_checkpoint
   logical,save :: checkpoint_pending=.false.,followup_pending=.false.,restart_pending=.false.
   integer,save :: checkpoint_phase=0
   character(64),save :: qualification_outcome=''
''',1)
    soil=soil.replace('subroutine soilwater(task)','recursive subroutine soilwater(task)',1)
    soil=soil.replace('            call headcalc','            if(.not.retry07_driver()) call headcalc',1)
    prev=(PREV/'soilwater_contract.f90').read_text(encoding='cp1252')
    dump=prev[prev.index('subroutine inventory_dump(label)'):prev.index('end subroutine inventory_dump')+len('end subroutine inventory_dump')]
    dump=dump.replace('use variables, only:t1900,dt,theta,thetm1','use variables, only:t1900,dt,h,hm1,theta,thetm1')
    dump=dump.replace('SorpDmCp,swmbf,FrReduQ','SorpDmCp,swmbf,FrReduQ,FrMpWalWet,FrMpWalWetOld')
    dump=dump.replace(" write(u,*) 'theta'", " write(u,*) 'h',h(1:numnod)\n write(u,*) 'hm1',hm1(1:numnod)\n write(u,*) 'wet_wall',FrMpWalWet(1:NumDm,1:numnod)\n write(u,*) 'wet_wall_old',FrMpWalWetOld(1:NumDm,1:numnod)\n write(u,*) 'theta'",1)
    driver='''
logical function retry07_driver() result(handled)
 use CONTRACT06_CONTROL, only:use_patch,trace_on
 use variables, only:t1900,dt,dtmin,fldecdt
 use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
 use MOD_macropore, only:MacroStateVar
 use MOD_swap_base, only:swdra,swfrost
 use MOD_drain, only:drain
 implicit none
 character(64),save :: mode='',context=''
 character(64) :: name
 integer :: u,attempt
 handled=.false.
 if(len_trim(mode)==0) then
  call get_environment_variable('RETRY07_MODE',mode)
  call get_environment_variable('RETRY07_CONTEXT',context)
 end if
 if(trim(mode)=='RESTART') then
  use_patch=.true.;trace_on=.false.
  call inventory_dump('restart_initialized')
  open(newunit=u,file='active.marker',status='replace');close(u)
  call headcalc
  call inventory_dump('restart_solver_return')
  if(fldecdt.or.FlDecMpRat) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'NATIVE_RESTART_FIRST_STEP_REJECTED'
   close(u);stop 0
  end if
  restart_pending=.true.;checkpoint_pending=.true.;handled=.true.
  return
 end if
 if(followup_pending) then
  followup_pending=.false.
  call inventory_dump('continuous_next_begin')
  call headcalc
  call inventory_dump('continuous_next_return')
  if(fldecdt.or.FlDecMpRat) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'CONTINUOUS_NEXT_STEP_REJECTED'
   close(u);stop 0
  end if
  checkpoint_pending=.true.;handled=.true.
  return
 end if
 if(checkpoint_phase/=0) return
 if(trim(context)=='A') then
  if(abs(t1900-35796.92d0)>1d-8.or.abs(dt-.002d0)>1d-12) return
 else if(trim(context)=='B') then
  if(abs(t1900-35796.9513533331d0)>1d-9.or.abs(dt-2d-5)>1d-14) return
 else
  return
 end if
 if(swdra/=1.or.swfrost/=0.or.IDecMpRat/=0) error stop 'scope mismatch'
 call inventory_dump('origin')
 use_patch=.true.;trace_on=.false.
 open(newunit=u,file='active.marker',status='replace');close(u)
 if(trim(mode)=='DIRECT') then
  fldecdt=.true.
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
  qualification_outcome='DIRECT_SMALL'
 else
  qualification_outcome='PATCH_LARGE'
 end if
 do attempt=1,4
  write(name,'(a,i0)') 'begin_',attempt
  call inventory_dump(trim(name))
  call headcalc
  write(name,'(a,i0)') 'returned_',attempt
  call inventory_dump(trim(name))
  if(.not.fldecdt.and..not.FlDecMpRat) then
   if(IDecMpRat/=0) error stop 'scaled acceptance excluded'
   if(attempt>1) qualification_outcome='REAL_REJECT_SMALL_RETRY'
   call inventory_dump('accepted_solver_return')
   checkpoint_pending=.true.;handled=.true.
   return
  end if
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(name,'(a,i0)') 'rollback_',attempt
  call inventory_dump(trim(name))
  if(FlDecMpRat.or.IDecMpRat/=0.or.attempt==4) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'NO_UNSCALED_RETRY_WITHIN_BOUND',attempt,dt
   close(u);stop 0
  end if
  if(.not.fldecdt) error stop 'unclassified refusal'
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
end function retry07_driver

subroutine retry07_checkpoint()
 use variables, only:t1900,dt,outfil
 use MOD_swap_base, only:fl_initialize,sw_end,sw_endtype,sw_endfilter
 implicit none
 integer :: u,old_end,old_type,old_filter
 character(80) :: token,old_outfil
 if(.not.checkpoint_pending) return
 checkpoint_pending=.false.
 if(restart_pending) then
  call inventory_dump('restart_after_step')
  open(newunit=u,file='outcome.txt',status='replace')
  write(u,*) 'NATIVE_RESTART_ONE_STEP_EXECUTED'
  close(u);stop 0
 end if
 if(checkpoint_phase==1) then
  call inventory_dump('continuous_after_step')
  open(newunit=u,file='outcome.txt',status='replace')
  write(u,*) trim(qualification_outcome),'_AND_CONTINUED'
  close(u);stop 0
 end if
 checkpoint_phase=1
 call inventory_dump('checkpoint')
 ! Genuine native writer after the actual host has advanced water, integral,
 ! heat/solute and TimeControl(3). No custom macro state is serialized.
 old_outfil=outfil;old_end=sw_end;old_type=sw_endtype;old_filter=sw_endfilter
 sw_end=1;sw_endfilter=0;fl_initialize=.false.
 outfil='candidate';sw_endtype=2
 call inoutend(1)
 outfil='candidate_text';sw_endtype=1
 call inoutend(1)
 outfil=old_outfil;sw_end=old_end;sw_endtype=old_type;sw_endfilter=old_filter
 call inventory_dump('checkpoint_after_io')
 open(newunit=u,file='restart_dates.txt',status='replace')
 call dtdpst('YEAR-MONTHST-DAY_HOUR:MINUTE:SECONDS.FSECONDS',t1900,token)
 write(u,'(a,a)') 'TSTART = ',trim(token)
 call dtdpst('YEAR-MONTHST-DAY_HOUR:MINUTE:SECONDS.FSECONDS',t1900+2d0*dt,token)
 write(u,'(a,a)') 'TEND = ',trim(token)
 close(u)
 open(newunit=u,file='checkpoint_outcome.txt',status='replace')
 write(u,*) trim(qualification_outcome)
 close(u)
 followup_pending=.true.
end subroutine retry07_checkpoint
'''
    soil=soil.replace('end module MOD_SoilWater',driver+'\n'+dump+'\nend module MOD_SoilWater')
    (R/'soilwater_retry.f90').write_text(soil,encoding='cp1252')
    swap=(OLD/'audit/build/swap-selected/swap.f90').read_text(encoding='cp1252')
    swap=swap.replace('use MOD_SoilWater,       only: soilwater, soilwaterstatevar','use MOD_SoilWater,       only: soilwater, soilwaterstatevar,retry07_checkpoint',1)
    swap=swap.replace('      call TimeControl(3)','      call TimeControl(3)\n      call retry07_checkpoint()',1)
    (R/'swap_checkpoint.f90').write_text(swap,encoding='cp1252')

def build(opt):
    for folder in [R.parent/'swap431-macro-b1-state02',R.parent/'swap431-macro-b1-stagnation05',PREV]:
        meta=json.loads((folder/'EVIDENCE.json').read_text());arc=folder/meta['file'];assert sha(arc)==meta['sha256']
        with zipfile.ZipFile(arc) as z:
            for x in json.loads(z.read('manifest.json')):
                if x['path'].startswith('native/'+opt+'/'):
                    data=z.read(x['path']);assert hashlib.sha256(data).hexdigest()==x['sha256'];p=WORK/x['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    out=WORK/'native'/opt;obj=out/'obj';logs=[]
    commands=[]
    for src,dest in [('soilwater_retry.f90','soilwater.o'),('swap_checkpoint.f90','swap.o')]:
        commands.append(['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/src),'-o',str(obj/dest)])
    commands.append(['gfortran','-o',str(out/'retry07.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')])
    for cmd in commands:
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,returncode=p.returncode,seconds=time.perf_counter()-t,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(compiler=subprocess.check_output(['gfortran','--version'],text=True),exe_sha256=sha(out/'retry07.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},contract06_evidence_sha256=json.loads((PREV/'EVIDENCE.json').read_text())['sha256']))

def run(opt,context,mode,checkpoint):
    profile=context+'_'+mode;case=WORK/(opt+'-'+profile);case.mkdir(exist_ok=True);assert not list(case.glob('*.txt'))
    for x in json.loads((OLD/'audit/CASE_IDENTITY.json').read_text()):
        p=Path(x['path']);(case/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OLD/'phase/O2/V1/case'/p,case/p)
    if mode=='RESTART':
        source=R/'data'/opt/checkpoint
        shutil.copy2(source/'candidate.end',case/'own.end')
        p=case/'swap.swp';s=p.read_text(encoding='cp1252')
        for line in (source/'restart_dates.txt').read_text().splitlines():
            key=line.split('=')[0].strip();s=re.sub(r'(?mi)^\s*'+key+r'\s*=.*$',line,s,count=1)
        s=re.sub(r'(?mi)^(\s*SWINCO\s*=\s*)2\b',r'\g<1>3',s,count=1)
        s+='\n INIFIL = \'own.end\'\n SWINITYPE = 2\n'
        p.write_text(s,encoding='cp1252')
        save(R/(opt+'_'+profile+'_INPUT.json'),dict(own_end_sha256=sha(case/'own.end'),input_sha256=sha(p),checkpoint_profile=checkpoint,date_lines=(source/'restart_dates.txt').read_text(),modifications='Native SWINCO3 own binary file; native time formatting for same checkpoint, short end bound; no added macro serializer.'))
    env=os.environ.copy();env.update(RETRY07_MODE=mode,RETRY07_CONTEXT=context);env.pop('STAG05_PROBE_SIDE',None);env.pop('UNRED04_DIRECT_DT',None)
    cmd=[str(WORK/'native'/opt/'retry07.exe'),'./swap.swp'];t=time.perf_counter()
    try:
        p=subprocess.run(cmd,cwd=case,env=env,capture_output=True,text=True,timeout=20);q=dict(command=cmd,context=context,mode=mode,returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired:q=dict(command=cmd,context=context,mode=mode,censored=True,seconds=time.perf_counter()-t)
    save(R/(opt+'_'+profile+'_RUN.json'),q);d=R/'data'/opt/profile;d.mkdir(parents=True,exist_ok=True)
    for p in list(case.glob('*.txt'))+list(case.glob('*.end'))+[case/'swap.swp',case/'swap.wrn',case/'swap.err',case/'swap.log']:
        if p.is_file():shutil.copy2(p,d/p.name)
    print(json.dumps(q),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--context',default='A');p.add_argument('--mode',default='TRIAL');p.add_argument('--checkpoint',default='A_TRIAL');a=p.parse_args()
    if a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':run(a.opt,a.context,a.mode,a.checkpoint)
