"""One real reduced-step inventory; reuses sealed native O0/O2 closures."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,time,zipfile

R=Path(__file__).resolve().parent
REPO=R.parents[1]
STATE02=R.parent/'swap431-macro-b1-state02'
OLD=Path('C:/Users/Veldh012/swap431-state02-work')
WORK=Path('C:/Users/Veldh012/swap431-inventory03-work')
AUDIT=OLD/'audit/build/swap-selected'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

def prepare():
    head=(R.parent/'swap431-macro-b1-accept01/V1/headcalc.f90').read_text(encoding='cp1252')
    head=head.replace('!        special case for macropores','         call inventory_solver()\n!        special case for macropores',1)
    routine='''
subroutine inventory_solver()
 integer :: u
 if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return
 open(newunit=u,file='solver.txt',status='replace')
 write(u,*) 'controls',t1900,dt,IDecMpRat,NN,numnod,CritDevBalCp,CritDevBalTot,CritDevPondDt
 write(u,*) 'residual',F(1:NN)
 write(u,*) 'sink',sink(1:NN)
 write(u,*) 'source',source(1:NN)
 write(u,*) 'qroot',qrot(1:NN)
 write(u,*) 'qexchange',QExcMpMtx(1:NN)
 write(u,*) 'kmean',kmean(1:NN+1)
 write(u,*) 'hgrad',hgrad(1:NN+1)
 write(u,*) 'h',h(1:NN)
 write(u,*) 'theta',theta(1:NN)
 write(u,*) 'thetm1',thetm1(1:NN)
 write(u,*) 'fraction',FrArMtrx(1:NN)
 write(u,*) 'dz',dz(1:NN)
 write(u,*) 'boundary',qtop,qbot,hsurf,merge(1,0,ftoph),pond,pondm1
 close(u)
end subroutine inventory_solver
'''
    head=head.replace('\ncontains\n','\ncontains\n'+routine,1)
    (R/'headcalc_inventory.f90').write_text(head,encoding='cp1252')
    soil=(AUDIT/'soilwater.f90').read_text(encoding='cp1252')
    soil=soil.replace('subroutine soilwater(task)','recursive subroutine soilwater(task)',1)
    soil=soil.replace('            call headcalc',"            call inventory_before()\n            call headcalc\n            call inventory_after()",1)
    routine='''
subroutine inventory_before()
 use variables, only:t1900,dt
 use MOD_swap_mp, only:IDecMpRat
 if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return
 if(abs(dt-0.0001414213562373095d0)>1d-14) return
 call inventory_dump('origin')
end subroutine inventory_before

subroutine inventory_after()
 use variables, only:t1900,dt,fldecdt
 use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
 if(IDecMpRat/=1.or.abs(t1900-35796.9513533331d0)>1d-9) return
 if(abs(dt-0.0001414213562373095d0)>1d-14) return
 call inventory_dump('trial')
 if(fldecdt.or.FlDecMpRat) error stop 'selected step not accepted'
 call SoilWater(3)
 call inventory_dump('committed')
 stop 0
end subroutine inventory_after

subroutine inventory_dump(label)
 use MOD_grid, only:numnod,dz
 use MOD_swap_base, only:swmacro
 use MOD_macropore, only:NumDm,WaSrMp,WaSrMpDm,WaUnMpDm,WaUnMpDmCp, &
 VlMpDmCp,ICpBtDm,QInTopLatDm,QInTopVrtDm,QExcMtxDmCp,QOutDrRapCp, &
 TimAbsCumDmCp,FlEndSrpEvt,ThtSrpRefDmCp,SorpDmCp,swmbf
 use MOD_swap_mp, only:FrArMtrx,QExcMpMtx,IDecMpRat,ArMpSs,QMpLatSs
 use MOD_drain, only:qdra,nrlevs
 use MOD_irrigation, only:qssdi,nird
 use MOD_meteo, only:nraidt
 use MOD_snow, only:melt
 use variables, only:t1900,dt,theta,thetm1,pond,pondm1,qtop,qbot,qrot,qimmob, &
 q,volact,volm1,runon,epd,reva,runots,fldecdt,swkimpl
 implicit none
 character(*),intent(in) :: label
 integer :: u
 open(newunit=u,file=label//'.txt',status='replace')
 write(u,*) 'controls',t1900,dt,IDecMpRat,numnod,NumDm,swmbf,swkimpl,merge(1,0,fldecdt)
 write(u,*) 'theta',theta(1:numnod)
 write(u,*) 'thetm1',thetm1(1:numnod)
 write(u,*) 'dz',dz(1:numnod)
 write(u,*) 'fraction',FrArMtrx(1:numnod)
 write(u,*) 'pond',pond,pondm1
 write(u,*) 'matrix_stored',volact,volm1
 write(u,*) 'macro_total',WaSrMp
 write(u,*) 'macro_sat',WaSrMpDm(1:NumDm)
 write(u,*) 'macro_domain',WaUnMpDm(1:NumDm)
 write(u,*) 'macro_compartment',WaUnMpDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_volume',VlMpDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_bottom',ICpBtDm(1:NumDm)
 write(u,*) 'macro_in_lat',QInTopLatDm(1:NumDm)
 write(u,*) 'macro_in_vert',QInTopVrtDm(1:NumDm)
 write(u,*) 'macro_exchange',QExcMtxDmCp(1:NumDm,1:numnod)
 write(u,*) 'macro_rapid',QOutDrRapCp(1:numnod)
 write(u,*) 'matrix_exchange',QExcMpMtx(1:numnod)
 write(u,*) 'matrix_drains',sum(qdra(1:nrlevs,1:numnod),dim=1)
 write(u,*) 'matrix_root',qrot(1:numnod)
 write(u,*) 'matrix_ssdi',qssdi(1:numnod)
 write(u,*) 'matrix_immob',qimmob(1:numnod)
 write(u,*) 'matrix_vertical',q(1:numnod+1)
 write(u,*) 'boundary_rates',qtop,qbot,nraidt,nird,melt,runon,epd,reva
 write(u,*) 'surface',runots,ArMpSs,QMpLatSs
 write(u,*) 'clock',TimAbsCumDmCp(1:NumDm,1:numnod)
 write(u,*) 'event',merge(1,0,FlEndSrpEvt(1:NumDm,1:numnod))
 write(u,*) 'reference',ThtSrpRefDmCp(1:NumDm,1:numnod)
 write(u,*) 'sorptivity',SorpDmCp(1:NumDm,1:numnod)
 close(u)
end subroutine inventory_dump
'''
    soil=soil.replace('end module MOD_SoilWater',routine+'\nend module MOD_SoilWater')
    (R/'soilwater_inventory.f90').write_text(soil,encoding='cp1252')

def build(opt):
    evidence=json.loads((STATE02/'EVIDENCE.json').read_text())
    archive=STATE02/evidence['file'];assert sha(archive)==evidence['sha256']
    WORK.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        manifest=json.loads(z.read('manifest.json'))
        for x in manifest:
            if not x['path'].startswith('native/'+opt+'/'):continue
            data=z.read(x['path']);assert hashlib.sha256(data).hexdigest()==x['sha256']
            p=WORK/x['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    out=WORK/'native'/opt;obj=out/'obj';logs=[]
    commands=[]
    for name in ['headcalc','soilwater']:
        commands.append(['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/(name+'_inventory.f90')),'-o',str(obj/(name+'.o'))])
    commands.append(['gfortran','-o',str(out/'inventory.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')])
    for cmd in commands:
        s=time.perf_counter();p=subprocess.run(cmd,cwd=obj,text=True,capture_output=True,timeout=60)
        logs.append(dict(command=cmd,returncode=p.returncode,seconds=time.perf_counter()-s,output=p.stdout+p.stderr))
        save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stdout+p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(compiler=subprocess.check_output(['gfortran','--version'],text=True),exe_sha256=sha(out/'inventory.exe'),inherited_closure_sha256=evidence['sha256'],source_sha256={p.name:sha(p) for p in R.glob('*.f90')},objects={p.name:sha(p) for p in obj.glob('*.o')}))

def run(opt):
    case=WORK/opt;case.mkdir(exist_ok=True)
    for item in json.loads((OLD/'audit/CASE_IDENTITY.json').read_text()):
        p=Path(item['path']);(case/p).parent.mkdir(exist_ok=True,parents=True);shutil.copy2(OLD/'phase/O2/V1/case'/p,case/p)
    for name in ['origin.txt','trial.txt','committed.txt','solver.txt']:
        if (case/name).exists():(case/name).unlink()
    cmd=[str(WORK/'native'/opt/'inventory.exe'),'./swap.swp'];s=time.perf_counter()
    try:
        p=subprocess.run(cmd,cwd=case,capture_output=True,text=True,timeout=20)
        record=dict(command=cmd,returncode=p.returncode,seconds=time.perf_counter()-s,censored=False,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired:
        record=dict(command=cmd,seconds=time.perf_counter()-s,censored=True)
    save(R/(opt+'_RUN.json'),record)
    for name in ['origin.txt','trial.txt','committed.txt','solver.txt']:
        if (case/name).exists():
            out=R/'data'/opt;out.mkdir(parents=True,exist_ok=True);shutil.copy2(case/name,out/name)
    print(json.dumps(record))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');a=p.parse_args()
    if a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':run(a.opt)
