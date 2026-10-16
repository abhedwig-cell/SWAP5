#!/usr/bin/env python3
"""Discriminating classic-route source probe, not full capability admission.

B1.11 routines are compiled verbatim, apart from module name/visibility.
Constant-table and externally supplied weather adapters are test boundaries.
Unselected N/soybean/grass calls fail closed. All compiled production is real.
"""
import argparse,base64,hashlib,importlib.util,io,json,os,re,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
AUTH='988b46c3246e835b6f9bcd97b3f2714c56de30d2'
ARCH='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
HASH='3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b'
STUBS='''module MOD_arrays
 integer,parameter::macroptb=6,mahrv=1
end module
module parameters
 real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module atmosphere_interface
 real(8)::tav,rad
end module
module MOD_swap_base
 integer::swcropsnm=0
end module
module plant_interface
 real(8)::dvs,tsum,kdif,aeratecrit=0,wrtmax=1d30
 integer::swrd=1,swwrtnonox=0
end module
module MOD_integral
 real(8)::ialpwet_day=1
end module
module MOD_wofost_nut
 real(8)::nni=1,nsla=0,rdrns=0,nlai=0
end module
module MOD_SoilTemperature
 real(8)::tsoil(1)=20
end module
'''
SUPPORT='''
 real(8) function rfmgtemp()
 error stop 'unselected soybean'
 end function
 real(8) function rfmgphotop()
 error stop 'unselected soybean'
 end function
 subroutine subpar(r,reltr)
 type(WOFOST_rates)::r
 real(8)::reltr
 error stop 'unselected nitrogen'
 end subroutine
 subroutine management_event(s,r,m,fl_continue)
 type(WOFOST_states)::s
 type(WOFOST_rates)::r
 type(AGRO_management)::m
 logical::fl_continue
 error stop 'unselected grass'
 end subroutine
'''
EXTERNAL='''
subroutine swap_error(where,message)
 character(*)::where,message
 print *,where,message
 error stop 'source balance check'
end subroutine
'''
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args()
 out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
 raw=base64.b64decode(subprocess.check_output(['git','show',f'{AUTH}:{ARCH}'],cwd=ROOT))
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:gz') as tar:
  source=tar.extractfile('SWAP/wofost.f90').read()
  functions=tar.extractfile('SWAP/functions.f90').read()
 assert sha(source)==HASH
 assert sha(functions)=='b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
 ftext=functions.decode().replace('\r\n','\n')
 fstart=ftext.index('   real(8) function afgen ('); fend=ftext.index('   end function afgen',fstart)+len('   end function afgen')
 afgen=ftext[fstart:fend]
 s=source.decode().replace('\r\n','\n')
 # Preserve type and variable declarations. Only module visibility changes.
 header=s[:s.index('   contains')]
 header=header.replace('module MOD_wofost','module b111_oracle',1)
 header='\n'.join(l for l in header.splitlines() if not re.match(r'\s*(private|public)\b',l))
 names=['update_dvs_rate','update_wofost','totass','assim','chckprt','chckcbl','relgrwt','deaths','deatha','glai','lvdth','lvshft','lvwgli']
 pieces=[]
 for name in names:
  pattern=r'^ +subroutine '+name+r'\s*\(.*?^\s*end(?:\s+subroutine(?:\s+'+name+r')?)?\s*$'
  m=re.search(pattern,s,re.I|re.M|re.S)
  if not m: raise ValueError(name)
  pieces.append(m.group())
 # lvwgli has four rather than three leading spaces.
 oracle=STUBS+header+'\ncontains\n'+'\n'.join(pieces)+SUPPORT+'\nend module\n'+EXTERNAL+'\n'+afgen+'\n'
 (out/'oracle.f90').write_text(oracle)
 spec=importlib.util.spec_from_file_location('dep',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
 dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
 driver='tests/fmig431/annual/test_classic_source.f90'
 # Exclude the explicit source-side adapter from production provider discovery.
 # It is used only to resolve b111_oracle and its source-side dependency modules.
 ordered,_=dep.strict_closure(ROOT,['src/crop/mod_wofost_two_phase_crop_window.f90','src/runtime/mod_fmr_wofost_crop_transaction.f90','tests/fwof/mod_fwof40_external_crop_restart_adapter.f90'])
 ordered += [out/'oracle.f90',ROOT/driver]
 records=[]
 compiler=os.environ.get('FC','gfortran')
 flags=['-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
 for opt in [0,2]:
  build=out/f'o{opt}';build.mkdir()
  cmd=[compiler,*flags,f'-O{opt}',*[str(p) for p in ordered],'-o',str(build/'probe')]
  t=time.monotonic();cp=subprocess.run(cmd,cwd=build,capture_output=True,text=True)
  (build/'compile.stdout').write_text(cp.stdout);(build/'compile.stderr').write_text(cp.stderr)
  rec={'optimization':opt,'command':cmd,'compile_link_seconds':time.monotonic()-t,'compile_exit':cp.returncode}
  records.append(rec)
  if cp.returncode:break
  t=time.monotonic();cp=subprocess.run([str(build/'probe')],cwd=build,capture_output=True,text=True)
  (build/'native.stdout').write_text(cp.stdout);(build/'native.stderr').write_text(cp.stderr)
  rec.update(native_seconds=time.monotonic()-t,native_exit=cp.returncode,stdout_sha256=sha(cp.stdout.encode()))
  if cp.returncode:break
 result={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'source_functions_sha256':sha(functions),'source_authority_ref':AUTH,'source_member_sha256':HASH,'source_archive_sha256':sha(raw),
 'extracted_routines':{n:sha(v.encode()) for n,v in zip(names,pieces)},'source_adapter_sha256':sha(oracle.encode()),
 'compiled_inputs':{str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p):sha(p.read_bytes()) for p in ordered},
 'runs':records,'scope':'Three 200-day classic IDSL0 actual-crop process trajectories; supplied weather and water ratios, literal AFGEN and DVS-dependent AMAXTB; actual classic opaque and existing disk-codec continuation every17 days, including cumulative organ mortality; not Richards or accepted-event admission.',
 'cost_limits':{'separate_compile_seconds':'UNKNOWN','separate_link_seconds':'UNKNOWN'},
 'disposition':'NOT_QUALIFIED'}
 ok=len(records)==2 and all(x.get('native_exit')==0 for x in records)
 if ok: result['disposition']='SOURCE_AND_PERSISTENCE_QUALIFIED_PENDING_ACCEPTED_EVENT_ADMISSION'
 result['source_state_completeness']={'B111_retained_dead_organs':['dwrt','dwst','dwlv'],
 'mapping_complete_for_tested_trajectories':ok,'diagnostic_not_physical_storage':True,
 'opaque_and_existing_disk_codec_continuation':ok}
 result['living_source_probe_pass']=ok
 result['O0_O2_stdout_identity']=ok and records[0]['stdout_sha256']==records[1]['stdout_sha256']
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps(result,indent=2))
 if not ok:raise SystemExit(1)
if __name__=='__main__': main()
