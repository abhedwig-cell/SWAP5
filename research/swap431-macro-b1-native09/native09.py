"""Bounded native accepted-state extension; original B, no replay or general serializer."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time,zipfile,sys
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;BASE=R.parent/'swap431-macro-b1-retry07'
SRC=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected')
WORK=Path('C:/Users/Veldh012/swap431-native09-work')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')

# Explicit field schema for this native format. Caches are intentionally retained
# rather than introducing a second physical geometry reconstruction algorithm.
groups=[
 ('MOD_macropore','macro',{
 'real(8)':{'WaSrMpDm':'madm','WaUnMpDm':'madm','WaUnMpDmCp':'madm,macp','WaSrMp':'',
 'TimAbsCumDmCp':'madm,macp','ThtSrpRefDmCp':'madm,macp','SorpDmCp':'madm,macp',
 'VlMpDmCp':'madm,macp','VlMpDm':'madm','VlMp':'','ZBtDm':'madm','ZWaLevDm':'madm',
 'FrMpWalWet':'madm,macp','FrMpWalWetOld':'madm,macp','FrReduQ':'','AwlCorFac':'macp','ArMpTp':'','ArMpTpDm':'madm'},
 'integer':{'ICpBtDm':'madm','ICpTpWaSrDm':'madm'}}),
 ('MOD_swap_mp','macro',{'real(8)':{'VlMpDyCp':'macp','SubsidCp':'macp','ArMpSs':'','KsMpSs':''}}),
 ('variables','host',{'real(8)':{'t1900':'','tstart':'','t':'','tcum':'','timjan1':'','dt':'','dtold':'','volact':'','volm1':''},
 'integer':{'daynr':'','daycum':'','iyear':'','imonth':'','isteps':''},
 'logical':{'fldaystart':'','fldayend':'','fldtmin':'','flzerointr':'','flzerocumu':''}}),
 ('MOD_meteo','host',{'real(8)':{'tmn':'','tmx':'','tavd':'','hum':'','win':'','etr':'','grai':'','fprecnosnow':'','epond':'','peva':'','ptra_dry':'','ptra_wet':'','eintc':'','aintc':'','wfrac':''},
 'integer':{'meteo_rec':'','rain_rec':'','i_metdetail':''},'logical':{'fl_update_meteo':''}}),
 ('atmosphere_interface','host',{'real(8)':{'tav':'','rad':''}}),
 ('plant_interface','host',{'real(8)':{'lai':'','rd':'','vcover':'','siccap':'','sicact':'','cf':'','fco2tra':'','dt_interc_event':'','crsflx_in':'','crsflx_out':'','hlim3l':'','hlim3h':'','hlim4':'','dvs':'','tsum':''},'integer':{'noddrz':''},'logical':{'fl_cropemergence':'','fl_cropharvest':''}}),
 ('MOD_cropdevelopment','host',{'real(8)':{'cumdens_top':'macp'}}),
]

def prepare():
 fields=[dict(module=m,phase=p,type=t,name=n,shape=s) for m,p,g in groups for t,vs in g.items() for n,s in vs.items()]
 save(R/'FIELDS.json',fields)
 # Fingerprint binds original full input set plus the already sealed physical patch.
 sig=hashlib.sha256((Path('C:/Users/Veldh012/swap431-state02-work/audit/CASE_IDENTITY.json').read_bytes()+
       (R.parent/'swap431-macro-b1-contract06/minimal_contract.patch').read_bytes())).hexdigest()
 use='\n'.join('use '+m+', only:'+','.join(n for vs in g.values() for n in vs) for m,p,g in groups)
 decl='\n'.join(f"{f['type']},save :: b_{f['name']}"+(f"({f['shape']})" if f['shape'] else '') for f in fields)
 def section(f,n='numnod',nd='NumDm'):
  if f['name']=='cumdens_top':return '(1:'+n+'+1)'
  return {'':'','madm':'(1:'+nd+')','macp':'(1:'+n+')','madm,macp':'(1:'+nd+',1:'+n+')'}[f['shape']]
 code=f'''module MOD_native09
use MOD_arrays, only:macp,madm
use MOD_grid, only:numnod
use MOD_macropore, only:NumDm,swmbf,swabs
use MOD_swap_base, only:swmacro,swhyst,swfrost,swdra,swsolu,swhea,swcrop,fl_initialize
use MOD_swap_mp, only:IDecMpRat,FlDecMpRat
use variables, only:fldecdt,flrunend
use variables, only:h,theta,k,kmean
use MOD_SoilTemperature, only:tsoil
use plant_interface, only:sw_inter,sw_drought,sw_oxygen
use MOD_cropdevelopment, only:hlim1,hlim2u,hlim2l,rdm,sw_compensate,sw_stressor
use, intrinsic :: ieee_arithmetic, only:ieee_is_finite
{use}
implicit none
logical,save :: pending=.false.,macro_done=.false.
integer,save :: saved_n,saved_nd
character(64),parameter :: signature='{sig}'
{decl}
contains
subroutine io(u,rw)
integer,intent(in)::u,rw
integer::ios,n,nd,v
character(32)::tag
character(64)::sig
if(swmacro/=1) return
if(rw==2) then
 if(swmbf/=1.or.swabs/=1.or.IDecMpRat/=0.or.FlDecMpRat.or.fldecdt) error stop 'NATIVE09 unsupported boundary'
 tag='SWAP431_MACRO_RESTART_V1'
 write(u) tag,1,numnod,NumDm,signature
'''
 for f in fields:code+=f" write(u) {f['name']}{section(f)}\n"
 code+=''' tag='NATIVE09_COMPLETE'
 write(u) tag
 return
end if
read(u,iostat=ios) tag,v,n,nd,sig
if(ios/=0) error stop 'NATIVE09 missing trailer'
if(tag/='SWAP431_MACRO_RESTART_V1'.or.v/=1.or.sig/=signature) error stop 'NATIVE09 version or identity mismatch'
if(n/=numnod.or.n<1.or.nd<1.or.nd>madm) error stop 'NATIVE09 dimensions mismatch'
saved_n=n;saved_nd=nd
'''
 for f in fields:
  code+=f"read(u,iostat=ios) b_{f['name']}{section(f,'n','nd')}\nif(ios/=0) error stop 'NATIVE09 incomplete {f['name']}'\n"
  if f['type']=='real(8)':
   test=f"ieee_is_finite(b_{f['name']}{section(f,'n','nd')})";test='all('+test+')' if f['shape'] else test
   code+=f"if(.not.{test}) error stop 'NATIVE09 nonfinite {f['name']}'\n"
 code+='''read(u,iostat=ios) tag
if(ios/=0.or.tag/='NATIVE09_COMPLETE') error stop 'NATIVE09 incomplete trailer'
if(b_tstart/=tstart.or.b_dt<=0.or.b_dtold<=0) error stop 'NATIVE09 time/origin mismatch'
if(b_fldaystart.or.b_fldayend) error stop 'NATIVE09 only accepted subday supported'
if(any(b_WaSrMpDm(1:nd)<0).or.any(b_TimAbsCumDmCp(1:nd,1:n)<0)) error stop 'NATIVE09 invalid inventory/history'
if(any(b_VlMpDmCp(1:nd,1:n)<0).or.any(b_WaUnMpDmCp(1:nd,1:n)<0)) error stop 'NATIVE09 invalid geometry'
if(any(b_ICpBtDm(1:nd)<1).or.any(b_ICpBtDm(1:nd)>n)) error stop 'NATIVE09 bottom index'
if(abs(sum(b_WaUnMpDm(1:nd))-b_WaSrMp)>1d-12) error stop 'NATIVE09 total inventory mismatch'
do v=1,nd
 if(abs(sum(b_WaUnMpDmCp(v,1:n))-b_WaUnMpDm(v))>1d-12) error stop 'NATIVE09 compartment inventory mismatch'
 if(abs(b_WaUnMpDm(v)-b_WaSrMpDm(v))>1d-12) error stop 'NATIVE09 bypass inventory mismatch'
end do
pending=.true.
end subroutine
subroutine install_macro()
if(.not.pending) return
if(NumDm/=saved_nd.or.numnod/=saved_n.or.swmbf/=1.or.swabs/=1.or.swhyst/=0.or.swfrost/=0.or.swdra/=1.or.swsolu/=0.or.swhea/=1.or.swcrop/=1) error stop 'NATIVE09 incompatible mode'
'''
 for f in fields:
  if f['phase']=='macro':code+=f"{f['name']}{section(f)}=b_{f['name']}{section(f)}\n"
 code+='''macro_done=.true.
end subroutine
subroutine install_host()
if(.not.pending) return
if(.not.macro_done) error stop 'NATIVE09 macro install order'
'''
 for f in fields:
  if f['phase']=='host':code+=f"{f['name']}{section(f)}=b_{f['name']}{section(f)}\n"
 code+='''fldecdt=.false.;FlDecMpRat=.false.;IDecMpRat=0
flrunend=.false.;fl_initialize=.false.
pending=.false.
end subroutine
subroutine dump(label)
character(*),intent(in)::label
integer::u
open(newunit=u,file=label//'.txt',status='replace')
'''
 for f in fields:
  val=f['name']+section(f)
  if f['type']=='logical':val='merge(1,0,'+val+')'
  code+=f"write(u,*) '{f['name']}',{val}\n"
 code+='''write(u,*) 'tsoil',tsoil(1:numnod)
write(u,*) 'hydraulic_k',k(1:numnod)
write(u,*) 'hydraulic_kmean',kmean(1:numnod+1)
write(u,*) 'crop_switches',sw_inter,sw_drought,sw_oxygen,sw_compensate,sw_stressor
write(u,*) 'root_constants',hlim1,hlim2u,hlim2l,rdm
close(u)
end subroutine
end module MOD_native09
subroutine native09_io(u,rw)
use MOD_native09, only:io
integer::u,rw
call io(u,rw)
end subroutine
logical function native09_pending()
use MOD_native09, only:pending
native09_pending=pending
end function
subroutine native09_macro()
use MOD_native09, only:install_macro
call install_macro()
end subroutine
subroutine native09_host()
use MOD_native09, only:pending,install_host,dump
use MOD_SoilWater, only:soilwater
use MOD_cropdevelopment, only:cropdevelopment
use MOD_swap_base, only:pathcrop,iun_min2,iun_max2
use plant_interface, only:crpfilnam,cropfil,icrop,unit_crp,croptype
integer,external :: getun2
if(.not.pending) return
if(croptype(icrop)/=1) error stop 'NATIVE09 only simple crop supported'
! Read the same crop constants without cropdevelopment2/3 or daystart.
! Rutter's parameter reader resets SICACT; accepted host installation below
! restores that native reservoir and the saved daily geometry afterwards.
crpfilnam=trim(pathcrop)//trim(cropfil(icrop))//'.crp'
unit_crp=getun2(iun_min2,iun_max2,2)
call cropdevelopment(1)
! Refresh matrix hydraulic caches against restored H and initialized FrArMtrx;
! SoilWater1 does not integrate water or sorption for SWINCO3/SWHYST0.
call soilwater(1)
call install_host()
call dump('native_installed')
end subroutine
subroutine native09_dump(label)
use MOD_native09, only:dump
character(*)::label
call dump(label)
end subroutine
'''
 (R/'native_state.f90').write_text(code)
 # Expose only the one private ET context scalar used by the bounded payload.
 s=(SRC/'MOD_meteo.f90').read_text(encoding='cp1252').replace('public :: meteo','public :: eintc\npublic :: meteo',1)
 (R/'meteo_native.f90').write_text(s,encoding='cp1252')
 s=(SRC/'macropore.f90').read_text(encoding='cp1252')
 start=s.index('      subroutine macropore',0) if '      subroutine macropore' in s else s.lower().index('      subroutine macropore')
 # Original casing varies; insert explicit external predicate declarations.
 for sub in ['macropore','macroinit']:
  i=s.lower().index('subroutine '+sub+' ' if sub=='macroinit' else 'subroutine '+sub+'(') if False else s.lower().index('subroutine '+sub)
  j=s.lower().index('implicit none',i)+len('implicit none');s=s[:j]+'\n      logical,external :: native09_pending'+s[j:]
 s=s.replace('      call MACROSTATE ()\n      \n      FrMpWalWetOld', '      if (.not.native09_pending()) then\n      call MACROSTATE ()\n      \n      FrMpWalWetOld',1)
 needle='FrMpWalWet(1:numdm,IcTopMp:NumNod)'
 i=s.index(needle,s.index('if (.not.native09_pending())'))+len(needle)
 s=s[:i]+'\n      end if\n      call native09_macro()'+s[i:]
 a=s.index('      ICpBtDm(1:NumDm)     = NumNod');b=s.index('!- B. DETERMINING NnCrAr',a)
 s=s[:a]+'      if (.not.native09_pending()) then\n'+s[a:b]+'      end if\n'+s[b:]
 s=s.replace('      call MPVOLUME (1)\n      \n      return\n      end subroutine MacroInit','      if (.not.native09_pending()) call MPVOLUME (1)\n      \n      return\n      end subroutine MacroInit',1)
 (R/'macropore_native.f90').write_text(s,encoding='cp1252')
 s=(SRC/'swapoutput.f90').read_text(encoding='cp1252')
 i=s.index('   subroutine inoutend (task)');j=s.index('      implicit none',i)
 s=s[:j]+'      use MOD_swap_base, only:swmacro\n'+s[j:]
 s=s.replace('               ! crop section','               ! Native accepted-state resume must consume crop state even when\n               ! the unchanged original loading origin equals crop emergence.\n               if(rw==1.and.sw_initype==2.and.swmacro==1) fl_start_croprotation=.false.\n               ! crop section',1)
 # Native trailer follows crop records, inside each full record before close.
 needle='         \n            end do\n               \n            ! close unit'
 assert needle in s
 s=s.replace(needle,"         \n               if (sw_endfilter == 0) then\n                  if ((rw==1.and.sw_initype==2).or.(rw==2.and.sw_endtype==2)) call native09_io(unit_ini,rw)\n               end if\n            end do\n               \n            ! close unit",1)
 (R/'swapoutput_native.f90').write_text(s,encoding='cp1252')
 s=(BASE/'soilwater_retry.f90').read_text(encoding='cp1252')
 for name in ['checkpoint','checkpoint_after_io','continuous_next_begin','continuous_next_return','continuous_after_step','restart_initialized','restart_after_step']:
  s=s.replace("call inventory_dump('"+name+"')","call inventory_dump('"+name+"')\n call native09_dump('extended_"+name+"')")
 (R/'soilwater_native.f90').write_text(s,encoding='cp1252')
 s=(BASE/'swap_checkpoint.f90').read_text(encoding='cp1252')
 s=s.replace('if (iTask == 2) then','if (iTask == 2) then\n   call native09_host()',1)
 (R/'swap_native.f90').write_text(s,encoding='cp1252')

def build(opt):
 for folder in [R.parent/'swap431-macro-b1-state02',R.parent/'swap431-macro-b1-stagnation05',R.parent/'swap431-macro-b1-contract06',BASE]:
  m=json.loads((folder/'EVIDENCE.json').read_text());arc=folder/m['file'];assert sha(arc)==m['sha256']
  with zipfile.ZipFile(arc) as z:
   for x in json.loads(z.read('manifest.json')):
    if x['path'].startswith('native/'+opt+'/'):
     b=z.read(x['path']);assert hashlib.sha256(b).hexdigest()==x['sha256'];p=WORK/x['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 obj=WORK/'native'/opt/'obj';out=obj.parent;logs=[]
 for name,dest in [('meteo_native','mod_meteo'),('macropore_native','macropore'),('native_state','native09'),('swapoutput_native','swapoutput'),('soilwater_native','soilwater'),('swap_native','swap')]:
  cmd=['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/(name+'.f90')),'-o',str(obj/(dest+'.o'))]
  t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
 cmd=['gfortran','-o',str(out/'native09.exe'),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')]
 t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
 save(R/(opt+'_IDENTITY.json'),dict(exe_sha256=sha(out/'native09.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},compiler=subprocess.check_output(['gfortran','--version'],text=True)))

def run(opt,mode,label=''):
 profile='B_'+mode+('_'+label if label else '');case=WORK/(opt+'-'+profile+'-FINAL3');case.mkdir(exist_ok=True);assert not list(case.glob('*.txt'))
 for x in json.loads((R/'CASE_IDENTITY.json').read_text()):
  p=Path(x['path']);(case/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(Path('C:/Users/Veldh012/swap431-state02-work/phase/O2/V1/case')/p,case/p)
  assert sha(case/p)==x['sha256'],str(p)
 if mode=='RESTART':
  import re
  source=R/'data'/opt/'B_TRIAL'/'candidate.end';shutil.copy2(source,case/'own.end')
  if label=='MISSING':shutil.copy2(BASE/'data'/opt/'B_TRIAL/candidate.end',case/'own.end')
  if label=='VERSION':
   p=case/'own.end';b=p.read_bytes();i=b.index(b'SWAP431_MACRO_RESTART_V1');b=b[:i]+b[i:].replace(b'SWAP431_MACRO_RESTART_V1',b'SWAP431_MACRO_RESTART_V9',1);p.write_bytes(b)
  if label in ['IDENTITY','DIMENSION','NONFINITE','INVENTORY','TRUNCATED']:
   import struct
   p=case/'own.end';b=bytearray(p.read_bytes());i=b.index(b'SWAP431_MACRO_RESTART_V1');size=struct.unpack_from('<i',b,i-4)[0]
   if label=='IDENTITY':b[i+44]=ord('x')
   elif label=='DIMENSION':struct.pack_into('<i',b,i+36,111)
   elif label=='NONFINITE':struct.pack_into('<d',b,i+size+8,float('nan'))
   elif label=='INVENTORY':struct.pack_into('<d',b,i+size+8,-1.)
   elif label=='TRUNCATED':b=b[:-40]
   p.write_bytes(b)
  s=(case/'swap.swp').read_text(encoding='cp1252');s=re.sub(r'(?mi)^(\s*SWINCO\s*=\s*)2\b',r'\g<1>3',s,count=1)
  s+="\n INIFIL = 'own.end'\n SWINITYPE = 2\n SWENDTYPE = 2\n"
  (case/'swap.swp').write_text(s,encoding='cp1252')
  save(R/(opt+'_'+profile+'_INPUT.json'),dict(own_end_sha256=sha(case/'own.end'),source_sha256=sha(source),original_calendar_loading_window_preserved=True))
 env=os.environ.copy();env.update(RETRY07_MODE=mode,RETRY07_CONTEXT='B')
 cmd=[str(WORK/'native'/opt/'native09.exe'),'./swap.swp'];t=time.perf_counter()
 try:
  p=subprocess.run(cmd,cwd=case,env=env,capture_output=True,text=True,timeout=20);q=dict(command=cmd,returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
 except subprocess.TimeoutExpired:q=dict(command=cmd,censored=True,seconds=time.perf_counter()-t)
 save(R/(opt+'_'+profile+'_RUN.json'),q);d=R/'data'/opt/profile;d.mkdir(parents=True,exist_ok=True)
 for p in list(case.glob('*.txt'))+list(case.glob('*.end'))+[case/'swap.swp',case/'swap.wrn',case/'swap.err',case/'swap.log']:
  if p.is_file():shutil.copy2(p,d/p.name)
 print(json.dumps(q),flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--mode',default='TRIAL');p.add_argument('--label',default='');a=p.parse_args()
 if a.action=='prepare':prepare()
 elif a.action=='build':build(a.opt)
 elif a.action=='run':run(a.opt,a.mode,a.label)
