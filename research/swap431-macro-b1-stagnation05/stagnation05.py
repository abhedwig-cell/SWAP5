"""Bounded trace of existing V1; optional existing V2 on the same V1 prefix."""
from pathlib import Path
import argparse,importlib.util,json,os,hashlib,shutil,subprocess,time,zipfile,sys
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent
PREV=R.parent/'swap431-macro-b1-unreduced04'
OLD=Path('C:/Users/Veldh012/swap431-state02-work')
WORK=Path('C:/Users/Veldh012/swap431-stagnation05-work')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
COLS='stage iteration backtrack factor max_F sum_F objective previous_objective frozen h45 q45 F45 dQdh45 h_entry ended_events45 top_saturated top_perched bottom_perched max_head_step max_newton_step nonconverged pond_nonconverged macro_flag local_failures head_failures unsat_out45 sat_out45 saturated_in45 perched_in45 wet_wall45 max_clock45'.split()

def instrument(head):
    head=head.replace('   implicit none', '''   logical :: diag_active
   integer :: diag_u
   integer,save :: diag_counter=0
   character(64) :: diag_name
   implicit none''',1) if False else head
    # Declarations must follow IMPLICIT NONE.
    head=head.replace('!  local\n','''!  diagnostic local storage only
   logical :: diag_active
   integer :: diag_u
   integer,save :: diag_counter=0
   character(64) :: diag_name
!  local
''',1)
    head=head.replace('!  reset some variables at the start of a new day','''   diag_active=.false.
   if(abs(t1900-35796.9513533331d0)<1d-9) inquire(file='active.marker',exist=diag_active)
   if(diag_active) then
    diag_counter=diag_counter+1
    write(diag_name,'(a,i0,a)') 'iterations_',diag_counter,'.txt'
    open(newunit=diag_u,file=trim(diag_name),status='replace')
   end if
!  reset some variables at the start of a new day''',1)
    head=head.replace('!  start iteration loop, MaxIt specified in the input','   call diag_log(0)\n!  start iteration loop, MaxIt specified in the input',1)
    head=head.replace('      call jacobian_F()','      call diag_log(1)\n      call jacobian_F()\n      call diag_log(2)',1)
    head=head.replace('!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor','         call diag_log(3)\n!        test for iteration progress, if Newton-step is too large: reduce dh by multiplication factor',1)
    head=head.replace('!     save sump voor next iteration','      call diag_log(4)\n!     save sump voor next iteration',1)
    if 'B1 EXPERIMENT V1' in head:
        marker='         flunsatok(1:3) = .FALSE.\n         call vector_F(1,hgrad)'
        assert marker in head
        head=head.replace(marker,'         call diag_log(5)\n'+marker+'\n         call diag_log(6)',1)
    helper='''
subroutine diag_log(stage)
 use MOD_grid, only:layer
 use MOD_macropore, only:NumDm,FlEndSrpEvt,ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 QOutMtxUnsDmCp,QOutMtxSatDmCp,QInMtxSatDmCp,QInIntSatDmCp,FrMpWalWet,TimAbsCumDmCp
 integer,intent(in)::stage
 if(.not.diag_active) return
 write(diag_u,*) stage,numbit,itry,factor,maxval(abs(F(1:NN))),sum(F(1:NN)), &
 .5d0*dot_product(F(1:NN),F(1:NN)),sumold,merge(1,0,flunsatok(3)), &
 h(45),QExcMpMtx(45),F(45),dFdhMp(45),cofgen(9,layer(45)), &
 count(FlEndSrpEvt(1:NumDm,45)),ICpTpSatZon,ICpTpPerZon,ICpBtPerZon, &
 maxval(abs(h(1:NN)-hold(1:NN))),maxval(abs(difh(1:NN))), &
 merge(1,0,flnonconv),merge(1,0,flnonconv3),merge(1,0,fldecMPmbf), &
 count(flnonconv1(1:NN)),count(flnonconv2(1:NN)),sum(QOutMtxUnsDmCp(1:NumDm,45)), &
 sum(QOutMtxSatDmCp(1:NumDm,45)),sum(QInMtxSatDmCp(1:NumDm,45)), &
 sum(QInIntSatDmCp(1:NumDm,45)),sum(FrMpWalWet(1:NumDm,45)),maxval(TimAbsCumDmCp(1:NumDm,45))
end subroutine diag_log
'''
    main,internal=head.split('\ncontains\n',1)
    import re
    main=re.sub(r'(?m)^(\s*)return\s*$',r'\1if(diag_active) close(diag_u)\n\1return',main)
    return main+'\n   if(diag_active) close(diag_u)\ncontains\n'+helper+internal

def prepare():
    # Regenerate the exact final UNREDUCED04 probe first, then add read-only logs.
    spec=importlib.util.spec_from_file_location('u04',PREV/'unreduced04.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    m.R=R;m.prepare()
    v1=(R/'headcalc_inventory.f90').read_text(encoding='cp1252')
    (R/'headcalc_inventory.f90').write_text(instrument(v1),encoding='cp1252')
    v2=(R.parent/'swap431-macro-b1-accept01/V2/headcalc.f90').read_text(encoding='cp1252')
    v2=v2.replace('subroutine headcalc','subroutine headcalc_v2',1)
    # This source uses an unqualified END SUBROUTINE name only at the end.
    v2=v2.replace('end subroutine headcalc','end subroutine headcalc_v2')
    v2=v2.replace('!        special case for macropores','         call unreduced_trace(0)\n!        special case for macropores',1)
    v2=v2.replace('!  Convergence could not been reached','   call unreduced_trace(4)\n!  Convergence could not been reached',1)
    trace=v1[v1.index('subroutine unreduced_trace(kind)'):v1.index('end subroutine unreduced_trace')+len('end subroutine unreduced_trace')]
    v2=v2.replace('\ncontains\n','\ncontains\n'+trace+'\n',1)
    (R/'headcalc_v2.f90').write_text(instrument(v2),encoding='cp1252')
    soil=(R/'soilwater_inventory.f90').read_text(encoding='cp1252')
    soil=soil.replace('character(64) :: direct,name','character(64) :: direct,name,variant',1)
    soil=soil.replace(' do attempt=1,4'," call get_environment_variable('STAG05_VARIANT',variant)\n do attempt=1,1",1)
    soil=soil.replace('  call headcalc',"  if(trim(variant)=='V2') then\n   call headcalc_v2\n  else\n   call headcalc\n  end if",1)
    soil=soil.replace('if(attempt==4) exit','if(attempt==1) exit',1)
    soil=soil.replace("'FOUR_ATTEMPT_BOUND',attempt,dt","'ONE_ATTEMPT_DIAGNOSTIC_BOUND',1,dt",1)
    (R/'soilwater_inventory.f90').write_text(soil,encoding='cp1252')
    save(R/'TRACE_COLUMNS.json',COLS)

def build(opt):
    state02=R.parent/'swap431-macro-b1-state02';meta=json.loads((state02/'EVIDENCE.json').read_text());arc=state02/meta['file'];assert sha(arc)==meta['sha256']
    WORK.mkdir(exist_ok=True)
    with zipfile.ZipFile(arc) as z:
        for x in json.loads(z.read('manifest.json')):
            if x['path'].startswith('native/'+opt+'/'):
                data=z.read(x['path']);assert hashlib.sha256(data).hexdigest()==x['sha256'];p=WORK/x['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    out=WORK/'native'/opt;obj=out/'obj';logs=[]
    for source,target in [('headcalc_inventory.f90','headcalc.o'),('soilwater_inventory.f90','soilwater.o'),('headcalc_v2.f90','headcalc_v2.o')]:
        cmd=['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/source),'-o',str(obj/target)]
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    cmd=['gfortran','-o',str(out/'diagnosis.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')]
    t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(exe_sha256=sha(out/'diagnosis.exe'),compiler=subprocess.check_output(['gfortran','--version'],text=True),sources={p.name:sha(p) for p in R.glob('*.f90')},inherited_closure=meta['sha256']))

def run(opt,variant):
    case=WORK/(opt+'-'+variant);case.mkdir(exist_ok=True);assert not list(case.glob('*.txt'))
    for x in json.loads((OLD/'audit/CASE_IDENTITY.json').read_text()):
        p=Path(x['path']);(case/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OLD/'phase/O2/V1/case'/p,case/p)
    env=os.environ.copy();env['STAG05_VARIANT']=variant;env.pop('UNRED04_DIRECT_DT',None)
    cmd=[str(WORK/'native'/opt/'diagnosis.exe'),'./swap.swp'];t=time.perf_counter()
    try:
        p=subprocess.run(cmd,cwd=case,env=env,capture_output=True,text=True,timeout=20);q=dict(command=cmd,variant=variant,returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired:q=dict(command=cmd,variant=variant,censored=True,seconds=time.perf_counter()-t)
    save(R/(opt+'_'+variant+'_RUN.json'),q);out=R/'data'/opt/variant;out.mkdir(parents=True,exist_ok=True)
    for p in case.glob('*.txt'):shutil.copy2(p,out/p.name)
    print(json.dumps(q),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--variant',default='V1');a=p.parse_args()
    if a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':run(a.opt,a.variant)
