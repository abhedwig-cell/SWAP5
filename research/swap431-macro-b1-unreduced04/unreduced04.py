"""Single-context, unscaled V1 solve/reject experiment. No reference promotion."""
from pathlib import Path
import argparse,importlib.util,json,os,shutil,subprocess,time,hashlib

R=Path(__file__).resolve().parent
PREV=R.parent/'swap431-macro-b1-inventory03'
WORK=Path('C:/Users/Veldh012/swap431-unreduced04-work')
OLD=Path('C:/Users/Veldh012/swap431-state02-work')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

def prepare():
    head=(PREV/'headcalc_inventory.f90').read_text(encoding='cp1252')
    head=head.replace('call inventory_solver()','call unreduced_trace(0)',1)
    head=head.replace('!  Convergence could not been reached','   call unreduced_trace(4)\n!  Convergence could not been reached',1)
    head=head.replace('subroutine inventory_solver()','subroutine unreduced_trace(kind)',1)
    head=head.replace(' integer :: u\n if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return\n open(newunit=u,file=\'solver.txt\',status=\'replace\')',
''' use MOD_macropore, only:FrReduQ
 integer,intent(in) :: kind
 integer :: u
 integer,save :: counter=0
 logical :: active
 character(40) :: name
 inquire(file='active.marker',exist=active)
 if(.not.active) return
 counter=counter+1
 write(name,'(a,i0,a)') 'solver_',counter,'.txt'
 open(newunit=u,file=trim(name),status='replace')
 write(u,*) 'outcome',kind,numbit,FrReduQ
''',1)
    head=head.replace('end subroutine inventory_solver','end subroutine unreduced_trace',1)
    (R/'headcalc_inventory.f90').write_text(head,encoding='cp1252')
    soil=(OLD/'audit/build/swap-selected/soilwater.f90').read_text(encoding='cp1252')
    soil=soil.replace('subroutine soilwater(task)','recursive subroutine soilwater(task)',1)
    soil=soil.replace('            call headcalc','            call unreduced_driver()\n            call headcalc',1)
    # Retain the measured primitive inventory dump, not a copied physics routine.
    previous=(PREV/'soilwater_inventory.f90').read_text(encoding='cp1252')
    dump=previous[previous.index('subroutine inventory_dump(label)'):previous.index('end subroutine inventory_dump')+len('end subroutine inventory_dump')]
    dump=dump.replace('SorpDmCp,swmbf','SorpDmCp,swmbf,FrReduQ')
    dump=dump.replace('IDecMpRat,ArMpSs,QMpLatSs','IDecMpRat,ArMpSs,QMpLatSs,FlDecMpRat')
    dump=dump.replace('fldecdt,swkimpl','fldecdt,swkimpl,fldtmin')
    dump=dump.replace(" write(u,*) 'theta'", " write(u,*) 'policy',FrReduQ,merge(1,0,FlDecMpRat),merge(1,0,fldtmin)\n write(u,*) 'theta'",1)
    driver='''
subroutine unreduced_driver()
 use variables, only:t1900,dt,dtmin,fldecdt,fldtmin
 use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
 use MOD_swap_base, only:swdra,swfrost
 use MOD_macropore, only:MacroStateVar
 use MOD_drain, only:drain
 implicit none
 integer :: attempt,u,ios,status
 character(64) :: direct,name
 real(8) :: target
 if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return
 if(abs(dt-0.0001414213562373095d0)>1d-14) return
 if(swdra/=1.or.swfrost/=0) error stop 'unreduced scope mismatch'
 call inventory_dump('origin')
 open(newunit=u,file='active.marker',status='replace')
 write(u,*) 'Selected same-origin unscaled experiment, never a reference run.'
 close(u)
 ! Explicit experimental choice at this ONE live origin. The original
 ! MACRORATE reduction law and all HEADCALC equations/criteria stay intact.
 IDecMpRat=0
 ! Preserve the origin's existing retry flag: original HEADCALC uses it
 ! to select its doubled iteration budget. Do not shorten that budget.
 call get_environment_variable('UNRED04_DIRECT_DT',direct,status=status)
 if(status==0.and.len_trim(direct)>0) then
  read(direct,*,iostat=ios) target
  if(ios/=0.or.target<dtmin.or.target>dt) error stop 'invalid direct dt'
  do while(dt>target+1d-14)
   fldecdt=.true.
   call TimeControl(5)
  end do
  if(abs(dt-target)>1d-14) error stop 'direct dt not original retry size'
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end if
 do attempt=1,4
  write(name,'(a,i0)') 'begin_',attempt
  call inventory_dump(trim(name))
  call headcalc
  write(name,'(a,i0)') 'returned_',attempt
  call inventory_dump(trim(name))
  if(.not.fldecdt.and..not.FlDecMpRat.and.IDecMpRat==0) then
   call inventory_dump('trial')
   call SoilWater(3)
   call inventory_dump('committed')
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'ACCEPTED_UNREDUCED',attempt,dt
   close(u)
   stop 0
  end if
  ! Perform actual original rollback before classifying a failed attempt.
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
  write(name,'(a,i0)') 'rollback_',attempt
  call inventory_dump(trim(name))
  if(IDecMpRat/=0) then
   open(newunit=u,file='outcome.txt',status='replace')
   write(u,*) 'ORIGINAL_REDUCTION_REQUIRED',attempt,dt
   close(u)
   stop 0
  end if
  if(.not.fldecdt) error stop 'unclassified original outcome'
  if(attempt==4) exit
  call TimeControl(5)
  call drain(2)
  call SoilWaterStateVar(1)
  call MacroStateVar(1)
 end do
 open(newunit=u,file='outcome.txt',status='replace')
 write(u,*) 'FOUR_ATTEMPT_BOUND',attempt,dt
 close(u)
 stop 0
end subroutine unreduced_driver
'''
    soil=soil.replace('end module MOD_SoilWater',driver+'\n'+dump+'\nend module MOD_SoilWater')
    (R/'soilwater_inventory.f90').write_text(soil,encoding='cp1252')

def build(opt):
    spec=importlib.util.spec_from_file_location('inventory03_builder',PREV/'inventory03.py')
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    m.R=R;m.WORK=WORK
    m.build(opt)

def run(opt,mode,direct):
    case=WORK/(opt+'-'+mode);case.mkdir(exist_ok=True)
    assert not list(case.glob('*.txt')) and not (case/'active.marker').exists(),'Use a fresh case to preserve evidence'
    for item in json.loads((OLD/'audit/CASE_IDENTITY.json').read_text()):
        p=Path(item['path']);(case/p).parent.mkdir(exist_ok=True,parents=True);shutil.copy2(OLD/'phase/O2/V1/case'/p,case/p)
    env=os.environ.copy();env.pop('UNRED04_DIRECT_DT',None)
    if direct is not None:env['UNRED04_DIRECT_DT']=direct
    command=[str(WORK/'native'/opt/'inventory.exe'),'./swap.swp'];start=time.perf_counter()
    try:
        p=subprocess.run(command,cwd=case,env=env,capture_output=True,text=True,timeout=20)
        q=dict(command=command,mode=mode,direct_dt=direct,returncode=p.returncode,seconds=time.perf_counter()-start,censored=False,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired:
        q=dict(command=command,mode=mode,direct_dt=direct,seconds=time.perf_counter()-start,censored=True)
    save(R/(opt+'_'+mode+'_RUN.json'),q)
    out=R/'data'/opt/mode;out.mkdir(parents=True,exist_ok=True)
    for p in case.glob('*.txt'):shutil.copy2(p,out/p.name)
    print(json.dumps(q),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--mode',default='chain');p.add_argument('--direct-dt');a=p.parse_args()
    if a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':run(a.opt,a.mode,a.direct_dt)
