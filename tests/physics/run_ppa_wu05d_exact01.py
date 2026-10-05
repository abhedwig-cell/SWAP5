#!/usr/bin/env python3
"""Literal B1.11 algebra and dispatch evidence; no MICRO physics admission."""
import hashlib,json,os,pathlib,re,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
REF=ROOT/'reference/swap-4.3.1/b1_11_frost_source/SWAP/rootextraction.f90'
raw=REF.read_bytes();assert hashlib.sha256(raw).hexdigest()=='8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5'
s=raw.decode();micro=s[s.index('subroutine RootExtraction_MICRO('):s.index('end subroutine RootExtraction_MICRO')]
macro=s[s.index('subroutine RootExtraction_MACRO('):s.index('end subroutine RootExtraction_MACRO')]
assert 'sw_compensate' not in micro and not re.search(r'call\s+RootExtraction_MACRO',micro,re.I)
assert s.count('if (sw_compensate > 0)')==1 and 'alptot >= vsmall' in macro
assert re.search(r'vsmall\s*=\s*1\.0d-14',macro,re.I)
block=macro[macro.index('   if (sw_compensate > 0)'):macro.index('case default')]
wrapper=s[s.index('subroutine RootExtraction(iTask)'):s.index('end subroutine RootExtraction\r\n')+len('end subroutine RootExtraction')]
sources=['src/solver/mod_process_hydraulic_view.f90','src/process/mod_root_water_uptake_process.f90',
 'src/process/mod_root_uptake_compensation.f90','src/runtime/mod_root_uptake_compensation_execution.f90',
 'tests/physics/test_ppa_wu05d_exact01_cutoff.f90']
record={'work_unit':'PPA-WU05-D-EXACT01','tested_postimage':os.environ.get('C3A_TESTED_SHA','not-specified'),
 'reference_sha256':hashlib.sha256(raw).hexdigest(),'literal_compensation_block_sha256':hashlib.sha256(block.encode()).hexdigest(),
 'literal_dispatch_sha256':hashlib.sha256(wrapper.encode()).hexdigest(),'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sources},'runs':{}}
for p in [str(REF.relative_to(ROOT)),str(pathlib.Path(__file__).relative_to(ROOT)),'reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90']:
 record['source_sha256'][p]=hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='ppa-exact01-') as folder:
 folder=pathlib.Path(folder)
 (folder/'state.f90').write_text('''module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 type::soil_water_physical_state_t
 integer::active_nodes=0
 real(real64),allocatable::pressure_head(:),water_content(:)
 real(real64)::ponding_depth=0,groundwater_level=0
 end type
end module
''')
 (folder/'reference.f90').write_text('''module exact_reference_compensation
 use iso_fortran_env,only:real64
 contains
 subroutine legacy_compensation(qrot,ptra,losses,sw_compensate,sw_stressor,alphacrit)
 real(real64),intent(inout)::qrot(4),losses(4),alphacrit
 real(real64),intent(in)::ptra
 integer,intent(in)::sw_compensate,sw_stressor
 real(real64),parameter::vsmall=1.e-14_real64
 real(real64)::qrosum,qred,qreddrysum,qredwetsum,qredsolsum,qredfrssum
 real(real64)::alptot,alptotcom,alpdry,alpwet,alpsol,alpfrs,alpdrycom,alpwetcom,alpsolcom,alpfrscom,redtot
 real(real64)::dcritrtz,rdm,rd_noddrz
 integer::node,noddrz
 noddrz=4;dcritrtz=.5_real64;rdm=5._real64;rd_noddrz=2._real64
 qrosum=sum(qrot);qreddrysum=losses(1);qredwetsum=losses(2);qredsolsum=losses(3);qredfrssum=losses(4)
'''+block+''' losses=[qreddrysum,qredwetsum,qredsolsum,qredfrssum]
 end subroutine
 end module
''')
 # Only the actual unchanged dispatcher is compiled; its callees count entry.
 (folder/'dispatch.f90').write_text('''module plant_interface
 integer::sw_drought=1
 logical::fl_cropemergence=.true.
 end module
 module variables
 real(8)::qrot(4)=1
 end module
 module MOD_re_global
 real(8)::qpotrot(4)=1,qredwetsum=1,qreddrysum=1,qredsolsum=1,qredfrssum=1,qrosum=1
 end module
 module dispatch_counts
 integer::mac(2)=0,mic(2)=0
 end module
 module MOD_rootextraction
 contains
'''+wrapper+'''
 subroutine RootExtraction_MACRO(task)
 use dispatch_counts
 integer,intent(in)::task
 mac(task)=mac(task)+1
 end subroutine
 subroutine RootExtraction_MICRO(task)
 use dispatch_counts
 integer,intent(in)::task
 mic(task)=mic(task)+1
 end subroutine
 end module
 subroutine swap_error(a,b)
 character(*)::a,b
 error stop 1
 end subroutine
 program test_dispatch
 use plant_interface
 use variables
 use MOD_re_global
 use dispatch_counts
 use MOD_rootextraction
 integer::selector,emerged,task,n
 n=0
 do selector=1,3
 do emerged=0,1
 do task=1,2
 sw_drought=selector;fl_cropemergence=emerged==1;mac=0;mic=0;qrot=1;qpotrot=1;qrosum=1
 call RootExtraction(task)
 if(task==2.and.emerged==0)then
 if(any(mac/=0).or.any(mic/=0).or.any(qrot/=0).or.any(qpotrot/=0).or.qrosum/=0)error stop 2
 else if(selector==1)then
 if(mac(task)/=1.or.any(mic/=0))error stop 3
 else
 if(mic(task)/=1.or.any(mac/=0))error stop 4
 end if
 n=n+1
 end do
 end do
 end do
 print '(a,i0)','PPA_EXACT01_UNCHANGED_DISPATCH_CASES=',n
 end program
''')
 outputs=[]
 for opt in ['O0','O2']:
  b=folder/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
  r=[]
  for kind,files in [('dispatch',[folder/'dispatch.f90']),('cutoff',[folder/'state.f90']+[ROOT/p for p in sources[:-1]]+[folder/'reference.f90',ROOT/sources[-1]])]:
   exe=b/kind;subprocess.run(['gfortran']+flags+[str(p) for p in files]+['-o',str(exe)],check=True)
   p=subprocess.run([str(exe)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);print(p.stdout,flush=True)
   r+=p.stdout.splitlines();p.check_returncode()
  record['runs'][opt]=r;outputs.append(r)
 assert outputs[0]==outputs[1]
record['status']='LOCAL_EXACT_DISPATCH_AND_MACRO_COMPONENT_PASS_NOT_MICRO_PHYSICS'
pathlib.Path(os.environ.get('C3A_RESULT','ppa_exact01_result.json')).write_text(json.dumps(record,indent=2)+'\n')
print('PPA_EXACT01_O0_O2_SOURCE_COMPONENTS=PASS')
