#!/usr/bin/env python3
"""Isolated feasibility experiment; never a production/restart qualification."""
import argparse
import importlib.util
import re
import shutil
import subprocess
from pathlib import Path

spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def extract(text, kind, name):
    if kind == 'type':
        pattern=rf'^  type[^\n]*:: {name}\n.*?^  end type {name}\b[^\n]*'
    else:
        pattern=rf'^  (?:logical function|subroutine) {name}\(.*?^  end (?:function|subroutine) {name}\b[^\n]*'
    matches=re.findall(pattern,text,re.M|re.S)
    if len(matches)!=1: raise RuntimeError('ambiguous extraction '+name)
    return matches[0]+'\n'


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',required=True);a=ap.parse_args()
    out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
    tree=out/'tree';tree.mkdir();shutil.copytree(m.ROOT/'src',tree/'src')
    src=m.ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90';text=src.read_text()
    types=['fmr_snow_runtime_state_t','fmr_mobile_salt_component_t','fmr_b110_physical_state_t',
           'fmr_b110_temporal_indicator_state_t']
    routines=['copy_b110_physical_state','fmr_mobile_salt_ready','fmr_b110_state_clone',
              'fmr_b110_temporal_indicator_state_clone','fmr_b110_temporal_history_available','fmr_b110_temporal_history_snapshot']
    header='''module probe_accepted_state_types
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_state_t
  use mod_snow_process, only: snow_state_t
  use mod_restricted_soil_temperature, only: soil_temperature_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_rutter_source_window_processor, only: rutter_source_state_t
  use mod_fkt_temporal_indicator_history, only: fkt_temporal_indicator_history_t
  implicit none
  private
'''
    generated=header+''.join(extract(text,'type',n) for n in types)+'contains\n'+''.join(extract(text,'procedure',n) for n in routines)+'end module\n'
    target=tree/'src/runtime/probe_accepted_state_types.f90';target.write_text(generated)
    accessor='src/runtime/mod_fmr_crop_accepted_soil_temperature.f90'
    p=tree/accessor;p.write_text(p.read_text().replace('use mod_fmr_serialized_reference_backend','use probe_accepted_state_types'))
    # The exact accessor code is retained except its hypothetical module import.
    original,_=m.DEP.strict_closure(m.ROOT,[accessor],[m.STUB])
    closure,_=m.DEP.strict_closure(tree,[accessor])
    probe=tree/'probe.f90'
    probe.write_text('''program probe
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_transaction_reference, only: transaction_state_t
  use probe_accepted_state_types
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state,SOIL_TEMP_OK
  use mod_fmr_crop_accepted_soil_temperature
  implicit none
  type(fmr_b110_physical_state_t)::source
  type(kernel_committed_state_t)::committed
  class(transaction_state_t),allocatable::carrier
  real(real64)::got
  integer::status
  logical::ok
  source%active_nodes=2
  source%pressure_head=[-50._real64,-100._real64];source%water_content=[.2_real64,.3_real64]
  allocate(source%soil_temperature)
  call initialize_soil_temperature_state([8._real64,12._real64],source%soil_temperature,status)
  if(status/=SOIL_TEMP_OK) error stop 'heat init'
  allocate(carrier,source=source)
  call committed%initialize(10_int64,carrier,ok,7._real64)
  if(.not.ok) error stop 'committed init'
  call sample_committed_crop_soil_temperature(committed,10_int64,0_int64,7._real64,2,got,status)
  if(status/=CROP_ACCEPTED_TEMP_OK.or.got/=12._real64) error stop 'sample'
  call sample_committed_crop_soil_temperature(committed,11_int64,0_int64,7._real64,2,got,status)
  if(status/=CROP_ACCEPTED_TEMP_MISMATCH) error stop 'foreign lineage'
  print '(a)','ISOLATED_STATE_TYPES_FEASIBILITY_ONLY=PASS'
end program
''')
    s=m.Session(out/'commands');records=[]
    for opt in (0,2):
        build=out/f'O{opt}';build.mkdir();objects=[];compile_s=0
        for i,p in enumerate([*closure,probe]):
            obj=build/f'{i}.o'
            _,e=s.command([s.compiler,*m.COMMON,f'-O{opt}','-J',str(build),'-I',str(build),'-c',str(p),'-o',str(obj)],build,'compile')
            compile_s+=e['wall_seconds'];objects.append(str(obj))
        exe=build/'probe';_,link=s.command([s.compiler,*m.COMMON,f'-O{opt}',*objects,'-o',str(exe)],build,'link')
        output,native=s.command([str(exe)],build,'probe')
        records.append({'optimization':opt,'compile_seconds':compile_s,'link_seconds':link['wall_seconds'],
                        'native_seconds':native['wall_seconds'],'stdout_sha256':native['stdout_sha256']})
    m.write(out/'PROBE.json',{'status':'PASS_FEASIBILITY_ONLY','production_state_changed':False,
             'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=m.ROOT,text=True).strip(),
             'source_sha256':m.sha(src),'original_providers':len(original),'isolated_providers':len(closure),
             'closure':[str(p.relative_to(tree)) for p in closure],
             'input_sha256':{str(p.relative_to(tree)):m.sha(p) for p in [*closure,probe]},
             'types':types,'routines':routines,'records':records,'events':s.events,
             'blocker':'Moving type identity and private history requires shared HY/RT/restart successor authority and full affected gates; this experiment authorizes no production split.'})
    print('ISOLATED_STATE_TYPES_FEASIBILITY_ONLY=PASS',flush=True)


if __name__=='__main__':main()
