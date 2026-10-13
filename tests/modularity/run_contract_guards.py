#!/usr/bin/env python3
"""Extra physical invalid-input contracts, using production providers."""
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.CASES['guards']={'driver':'tests/modularity/test_physical_contracts.f90','marker':'MODULAR_BOESTEN_NONMUTATION_INVALID_CONTRACT=PASS','flags':m.COMMON}
s=m.Session(Path(sys.argv[1]).resolve())
m.CASES['temperature']={'driver':'tests/fci/test_fci43_restricted_soil_temperature_independent.f90','marker':'FVQ58_INDEPENDENT_ORACLE=PASS','flags':m.COMMON}
m.CASES['timestep']={'driver':'tests/fpe/test_fpe_timearch11_controller_contract.f90','marker':'F_PE_TIMEARCH11_CONTROLLER_CONTRACT=PASS','flags':m.COMMON}
m.CASES['root_frost']={'driver':'tests/frost/test_ppa_wu05b2_root_frost.f90','marker':'PPA-WU05B2_ROOT_FROST_ORACLES=PASS','flags':m.COMMON}
records=[]
for case in ['guards','temperature','timestep','root_frost']:
    pair=[s.execute(case,o) for o in [0,2]]
    assert pair[0]['stdout_sha256']==pair[1]['stdout_sha256'],case
    records.extend(pair)
# Existing independent PCSE-backed crop oracle requires stdin, so preserve its
# original Python controller instead of replacing it with a marker-only driver.
crop_exes=[]
for opt in [0,2]:
    build=s.out/f'crop-O{opt}';build.mkdir();exe=build/'test'
    sources,_=m.DEP.strict_closure(m.ROOT,['tests/fwof/pp02/test_wofost81_assimilation_driver.f90'])
    s.command([s.compiler,*m.COMMON,f'-O{opt}','-J',str(build),'-I',str(build),*map(str,sources),'-o',str(exe)],build,'crop-build')
    crop_exes.append(str(exe))
s.command(['python',str(m.ROOT/'tests/fwof/pp02/check_wofost81_assimilation_oracle.py'),*crop_exes],s.out,'crop-oracle')
m.write(s.out/'GUARDS.json',{'status':'PASS','records':records,'events':s.events})
print('MODULAR_PHYSICAL_NEGATIVE_O0_O2=PASS')
