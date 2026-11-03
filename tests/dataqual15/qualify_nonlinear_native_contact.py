"""Native actual-process local nonlinear contact and actual-input thermal receipts.

Research overlay only. Neighbour heads/conductivities are fixed in the two-cell
contact problem. No full nonlinear step or whole-project admission is claimed.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time
import zlib

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/solute'))
from legacy_reader_sources import materialize
from original_sources import build_original
from research_native_build_cache import verified_objects

RESEARCH='tests/dataqual15/research/'
MACRO='src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90'
HEAD='src/legacy/b1_10_port/headcalc.f90'
DRIVER='app/solute_project/main_water.f90'
IO='app/solute_column/macro_water_restart.f90'
SELF='tests/dataqual15/qualify_nonlinear_native_contact.py'


def replace_one(s,needle,value):
    assert s.count(needle)==1,(needle[:100],s.count(needle));return s.replace(needle,value)


def overlays(folder):
    rendered={}
    s=(ROOT/MACRO).read_text(encoding='utf-8')
    s=replace_one(s,'  end type ppa_wu05a16_inner_macropore_provider_t',
                 '    procedure,public::research_contact_rates\n  end type ppa_wu05a16_inner_macropore_provider_t')
    s=replace_one(s,'\ncontains\n','\ncontains\n'+(ROOT/(RESEARCH+'contact_provider_methods.inc')).read_text(encoding='utf-8'))
    rendered[MACRO]=s
    s=(ROOT/HEAD).read_text(encoding='utf-8')
    marker='   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t'
    s=replace_one(s,marker,marker+'\n   use mod_nonlinear_contact_pair\n   use mod_ppa_wu05a16_inner_macropore_provider,only:ppa_wu05a16_inner_macropore_provider_t')
    marker='   type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context'
    s=replace_one(s,marker,marker+'''
   real(8),allocatable::research_h(:),research_theta(:),research_f(:),research_increment(:),research_exchange(:)
   logical,save::research_logged=.false.
   integer::research_branch=0
''')
    marker='!     in the rare case that TRIDAG fails, use alternative solution'
    s=replace_one(s,marker,'''      if(provider_macropore_active.and.dt<=1d-7.and.state%numbit>=MaxIt)then
         block
            character(8)::setting
            integer::env_status
            call get_environment_variable('SWAP5_RESEARCH_CONTACT',setting,status=env_status)
            if(env_status==0.and.trim(setting)=='1')call research_nonlinear_contact()
         end block
      end if
'''+marker)
    s=replace_one(s,'\ncontains\n','\ncontains\n'+(ROOT/(RESEARCH+'contact_headcalc_methods.inc')).read_text(encoding='utf-8'))
    rendered[HEAD]=s
    s=(ROOT/DRIVER).read_text(encoding='utf-8')
    marker='        call require(fmr_macropore_trace_receipt_valid(s,numnod),'
    assert s.count(marker)==1
    pos=s.index(marker)
    s=s[:pos]+'''        block
          integer::heat_unit,heat_node
          if(s%thermal%available.and.s%thermal%conductive_profile_available)then
            open(newunit=heat_unit,file='actual-thermal.csv',status='unknown',position='append')
            do heat_node=1,numnod
              write(heat_unit,'(a,2(a,es25.17e3),a,i0,16(a,es25.17e3),3(a,i0))')'THERMAL',',',s%t0,',',s%t1,',',heat_node, &
                ',',s%thermal%temperature_start_c(heat_node),',',s%thermal%temperature_end_c(heat_node), &
                ',',s%water_start(heat_node),',',s%water_end(heat_node),',',s%thermal%dz_cm(heat_node), &
                ',',s%thermal%heat_capacity_average_j_cm3_k(heat_node), &
                ',',s%thermal%conductive_face_energy_j_cm2(heat_node),',',s%thermal%conductive_face_energy_j_cm2(heat_node+1), &
                ',',s%root_sink(heat_node),',',s%drainage_sink(heat_node),',',s%subsurface_source(heat_node), &
                ',',s%macropore_matrix_exchange(heat_node),',',s%thermal%theta_sat(heat_node), &
                ',',s%thermal%f_quartz(heat_node),',',s%thermal%f_clay(heat_node),',',s%thermal%f_organic(heat_node), &
                ',',merge(1,0,s%thermal%independent_boundary_heat),',',s%thermal%solution_mode,',',s%thermal%top_boundary_mode
            end do
            close(heat_unit)
          end if
        end block
'''+s[pos:]
    rendered[DRIVER]=s
    # The macro codec still uses POSIX-only fsync. The research executable uses
    # the already admitted sibling-file C publisher/CRC, with identical bytes.
    s=(ROOT/IO).read_text(encoding='utf-8')
    s=replace_one(s,' use mod_age_joint_restart_file,only:crc32',' use iso_c_binding,only:c_size_t,c_int32_t,c_int8_t')
    start=s.index('  integer(c_int) function rename_c');end=s.index(' end interface',start)
    s=s[:start]+'''  integer(c_int) function publish_c(a,b)bind(C,name='swap5_restart_publish')
   import c_int,c_char
   character(c_char),intent(in)::a(*),b(*)
  end function
  integer(c_int32_t) function crc_c(a,n)bind(C,name='swap5_restart_crc32')
   import c_int32_t,c_int8_t,c_size_t
   integer(c_int8_t),intent(in)::a(*)
   integer(c_size_t),value::n
  end function
'''+s[end:]
    start=s.index("  fd=open_c(path//'.tmp'");end=s.index('  status=0',start)
    s=s[:start]+"  rc=publish_c(path//'.tmp'//c_null_char,path//c_null_char);if(rc/=0)return\n"+s[end:]
    s=replace_one(s,'contains\n','''contains
 integer(int32) function crc32(bytes)result(crc)
  integer(int8),intent(in)::bytes(:)
  crc=crc_c(bytes,int(size(bytes),c_size_t))
 end function
''')
    rendered[IO]=s
    result={}
    for name,text in rendered.items():
        path=folder/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8');result[name]=path
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--optimization',choices=['O0','O2'],required=True)
    ap.add_argument('--reuse-build',type=Path,help='Exact compiled inputs/objects after a recorded link failure')
    ap.add_argument('--prepare-only',action='store_true',help='Validate the real source graph and provenance without compiling')
    args=ap.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=shutil.which('gfortran');assert fc
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    capsule=ROOT/'integration/dataqual15/ANDELST_CONTACT_DIAGNOSTIC.tar.xz'
    assert sha(capsule.read_bytes())=='0e0c5a80e4481e98a4e74632a06cbdc813e8514a76508716c4d131f445b470e4'
    report=dict(scope='ACTUAL_NATIVE_LOCAL_TWO_CELL_NONLINEAR_CONTACT_NOT_FULL_ACCEPTED_STEP',
        measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        optimization=args.optimization,full_original_andelst_complete=False,full_energy_balance_complete=False,events=[])
    def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    def run(command,folder,label,timeout=120,env=None,check=True):
        start=time.monotonic();cp=subprocess.run(list(map(str,command)),cwd=folder,capture_output=True,timeout=timeout,env=env)
        (out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr)
        event=dict(label=label,command=list(map(str,command)),returncode=cp.returncode,seconds=time.monotonic()-start)
        report['events'].append(event);save()
        if check:assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-3000:])
        return cp
    shadow=overlays(out/'overlay');build=out/'build';build.mkdir()
    original,tt=materialize(ROOT,build)
    candidates=list((ROOT/'src').rglob('*.f90'))+list((ROOT/'app/solute_column').glob('*.f90'))+[original,ROOT/(RESEARCH+'mod_nonlinear_contact_pair.f90')]
    mapping={};imports={}
    for source in candidates:
        key=source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else None
        actual=shadow.get(key,source);text=actual.read_text(encoding='utf-8')
        imports[actual]=re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',text,re.M|re.I)
        for name in re.findall(r'^\s*module\s+(\w+)\s*$',text,re.M|re.I):
            assert name.lower() not in mapping;mapping[name.lower()]=actual
    ordered=[];seen=set();active=set()
    def visit(source):
        if source in seen:return
        assert source not in active;active.add(source)
        for name in sorted(set(imports.get(source,re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',source.read_text(encoding='utf-8'),re.M|re.I)))):
            if name.lower() in mapping and mapping[name.lower()]!=source:visit(mapping[name.lower()])
        active.remove(source);seen.add(source);ordered.append(source)
    visit(shadow[DRIVER]);ordered.remove(shadow[DRIVER]);visit(shadow[HEAD]);visit(original);ordered.append(shadow[DRIVER])
    deps=[p.relative_to(ROOT).as_posix() for p in ordered if p.is_relative_to(ROOT) and not p.is_relative_to(out)]
    deps=list(dict.fromkeys([*deps,*shadow,RESEARCH+'contact_headcalc_methods.inc',RESEARCH+'contact_provider_methods.inc',
          RESEARCH+'mod_nonlinear_contact_pair.f90',SELF,'app/support/restart_publish.c','tools/solute/legacy_reader_sources.py',
          'tests/dataqual15/original_sources.py','tools/vq/b0_source_runner.py',
          'tests/dataqual15/research_native_build_cache.py',RESEARCH+'native_contact_platform.c']))
    assert not subprocess.check_output(['git','diff','HEAD','--',*deps],cwd=ROOT),'persist first'
    report['source_git_blob']={p:subprocess.check_output(['git','rev-parse','HEAD:'+p],cwd=ROOT,text=True).strip() for p in deps}
    report['rendered_overlay_sha256']={p:sha(q.read_bytes()) for p,q in shadow.items()}
    report['generated_reader_sha256']=sha(original.read_bytes())
    report['compiler']=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];save()
    if args.prepare_only:
        report['status']='SOURCE_PLAN_READY_NOT_EXECUTED';report['provider_count']=len(ordered);save()
        print('NATIVE_SOURCE_PROVENANCE_READY_GENERATED_FILES_NOT_GIT_INPUTS');return
    if args.reuse_build:
        objects,utilities,proof=verified_objects(args.reuse_build.resolve(),ROOT,ordered,shadow,args.optimization,report['compiler'])
        report['exact_reused_objects']=proof
    else:
        utilities=build_original(out/'original',fc,args.optimization,utilities_only=True)
    flags=['-'+args.optimization,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace',
           '-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(utilities/'ttobj')]
    if not args.reuse_build:
        objects=[]
        for i,source in enumerate(ordered):
            obj=build/(str(i)+'.o');run([fc,*flags,'-c',source,'-o',obj],build,'compile-'+str(i));objects.append(obj)
    else:
        for i,obj in enumerate(objects):
            if obj is None:
                assert ordered[i]==shadow[DRIVER]
                objects[i]=build/(str(i)+'.o')
                run([fc,*flags,'-I'+str(args.reuse_build.resolve()/'build'),'-c',ordered[i],'-o',objects[i]],build,'recompile-driver')
    cc=shutil.which('gcc');assert cc;cobj=build/'publish.o'
    run([cc,'-O2','-c',ROOT/'app/support/restart_publish.c','-o',cobj],build,'compile-publish')
    platform=build/'platform.o'
    run([cc,'-O2','-c',ROOT/(RESEARCH+'native_contact_platform.c'),'-o',platform],build,'compile-platform')
    exe=build/'native.exe';run([fc,'-fopenmp',*objects,cobj,platform,utilities/'ttobj/libttutil.a','-o',exe],build,'link')
    report['executable_sha256']=sha(exe.read_bytes());report['provider_count']=len(ordered);save()
    def case(name):
        folder=out/name;folder.mkdir()
        with tarfile.open(capsule) as t:
            for n in ('input.nml','input.swp','input.bbc','input.dra','macro.nml','origin.bin'):
                (folder/n).write_bytes(t.extractfile('run/'+n).read())
        binding=sha((folder/'input.nml').read_bytes()+(folder/'input.swp').read_bytes()+
                    (folder/'macro.nml').read_bytes()+report['executable_sha256'].encode())
        raw=(folder/'origin.bin').read_bytes();assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
        rebound=raw[:8]+binding.encode()+raw[72:-4];rebound+=struct.pack('=I',zlib.crc32(rebound))
        assert rebound[72:-4]==raw[72:-4];(folder/'origin.bin').write_bytes(rebound)
        return folder,binding
    for enabled in (False,True):
        folder,binding=case('contact-'+str(int(enabled)))
        cmd=[exe,'input.nml','origin.bin','5','input.swp','macro.nml',binding,'5.0','anchored-cauchy','0.0001',
             'experimental','source-surface-demand','perched-jacobian','conservative-macro-storage']
        cp=run(cmd,folder,'contact-'+str(int(enabled)),timeout=90,env=dict(os.environ,SWAP5_RESEARCH_CONTACT=str(int(enabled))),check=False)
        assert cp.returncode!=0,'known original barrier unexpectedly completed; inspect before qualification'
    a=out/'contact-0/diagnostic-rejected.bin';b=out/'contact-1/diagnostic-rejected.bin'
    assert a.is_file() and a.read_bytes()==b.read_bytes(),'observational nonlinear probe altered native rollback'
    contact=(out/'contact-1/nonlinear-contact.csv').read_text(encoding='utf-8').splitlines()
    trials=[r.split(',') for r in contact if r.startswith('TRIAL,')]
    assert len(trials)==5 and [r[2] for r in trials]==['T','T','T','F','F'],trials
    assert max(abs(float(x)) for r in trials[:3] for x in r[-2:])<=1e-10
    assert max(float(r[6]) for r in trials[:3])-min(float(r[6]) for r in trials[:3])<1e-7
    assert 'NATIVE_STATE_UNCHANGED_NONLINEAR_PAIR_ONLY_FULL_STEP_OPEN' in contact
    folder,binding=case('actual-prefix')
    cmd=[exe,'input.nml','-','1','input.swp','macro.nml',binding,'1.0','anchored-cauchy','0.0001','experimental',
         'source-surface-demand','perched-jacobian','conservative-macro-storage']
    run(cmd,folder,'actual-prefix',timeout=90,env=dict(os.environ,SWAP5_RESEARCH_CONTACT='0'))
    rows=[l.split(',') for l in (folder/'actual-thermal.csv').read_text(encoding='utf-8').splitlines()]
    assert rows and all(r[0]=='THERMAL' for r in rows)
    intervals={}
    for r in rows:intervals.setdefault((float(r[1]),float(r[2])),[]).append(r)
    assert all(len(v)==112 and [int(r[3]) for r in v]==list(range(1,113)) for v in intervals.values())
    report.update(status='NONLINEAR_LOCAL_CONTACT_AND_ACTUAL_NATIVE_THERMAL_RECEIPTS_PASS',
                  native_rollback_exact=True,contact_trials=trials,actual_thermal_intervals=len(intervals),actual_thermal_node_rows=len(rows))
    save();print(json.dumps({k:v for k,v in report.items() if k not in ('events','source_git_blob','contact_trials')},indent=2))


if __name__=='__main__':main()
