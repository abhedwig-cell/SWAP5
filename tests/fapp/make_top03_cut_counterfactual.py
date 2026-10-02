#!/usr/bin/env python3
"""Research counterfactual: remove inherited near-saturation K shortcut in scratch only."""
import argparse, hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('provider',type=Path);p.add_argument('test',type=Path);a=p.parse_args()
src=Path('src/solver/mod_b110_default_mvg_provider.f90');s=src.read_text()
needle='else if (relsat > (1.0_real64-1.0e-6_real64)) then'
assert s.count(needle)==1
a.provider.write_text(s.replace(needle,'else if (relsat >= 1.0_real64) then'))
s=Path('tests/fapp/test_sw_rib_top03_surface_transition.f90').read_text()
s=s.replace(' implicit none',' use mod_b110_default_mvg_provider,only:evaluate_b110_default_mvg_conductivity\n implicit none',1)
s=s.replace(' logical::continued',' real(real64)::cut_head,kleft,kright\n logical::oracle_ok1,oracle_ok2\n logical::continued',1)
needle=' call initialize_b110_default_mvg_parameters(hp,cofgen)'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
 cut_head=-((1.0_real64-1e-6_real64)**(-1.0_real64/hp%cofgen(7,1))-1.0_real64)** &
     (1.0_real64/hp%cofgen(6,1))/hp%cofgen(4,1)
 call evaluate_b110_default_mvg_conductivity(hp,1,cut_head-1e-9_real64,kleft,oracle_ok1)
 call evaluate_b110_default_mvg_conductivity(hp,1,cut_head+1e-9_real64,kright,oracle_ok2)
 if(.not.oracle_ok1.or..not.oracle_ok2)error stop 'counterfactual oracle unavailable'
 if(abs(kright-kleft)>1e-6_real64)error stop 'counterfactual retained jump'
 if(abs(kleft-4.570054653885331_real64)>1e-12_real64)error stop 'unsaturated side changed'
 write(*,'(a,3(a,es24.16))')'COUNTERFACTUAL_ORACLE',',',cut_head,',',kleft,',',kright
''')
a.test.write_text(s)
print('TOP03_COUNTERFACTUAL_ORIGINAL_PROVIDER_SHA256='+hashlib.sha256(src.read_bytes()).hexdigest())
