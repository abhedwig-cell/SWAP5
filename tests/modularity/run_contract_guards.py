#!/usr/bin/env python3
"""Extra physical invalid-input contracts, using production providers."""
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.CASES['guards']={'driver':'tests/modularity/test_physical_contracts.f90','marker':'MODULAR_BOESTEN_NONMUTATION_INVALID_CONTRACT=PASS','flags':m.COMMON}
s=m.Session(Path(sys.argv[1]).resolve())
records=[s.execute('guards',o) for o in [0,2]]
assert records[0]['stdout_sha256']==records[1]['stdout_sha256']
m.write(s.out/'GUARDS.json',{'status':'PASS','records':records,'events':s.events})
print('MODULAR_PHYSICAL_NEGATIVE_O0_O2=PASS')
