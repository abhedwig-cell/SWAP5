"""Fresh incumbent weather/PM/RAINTB preservation plus physical wet-stress cycle.

Reuses existing measured Session and owner build. No gate or PASS inheritance.
"""
from pathlib import Path
import argparse, sys, hashlib
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from oxygen_source_oracle import prepare as source_oracle
from oxygen_cycle_driver import prepare as prepare_driver
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
# Existing controller owns command logging, provider identity and O0/O2 checks.
path=ROOT/'tests/mc-met01/run_raintb_legacy_owner_preservation.py'
s=path.read_text()
def replace(old,new):
 global s
 assert s.count(old)==1,old
 s=s.replace(old,new)
replace("    inputs={p:sha(ROOT/p) for p in providers}","""    drivers['oxygen']=prepare_driver(ROOT,output/'oxygen_driver.f90')
    source_oracle(ROOT,fixture/'oxygen_oracle.f90')
    inputs={p:sha(ROOT/p) for p in providers}
    for p in ['tests/crop-cycle/oxygen_cycle_driver.py','tests/crop-cycle/oxygen_segment_oracle.inc',
              'tests/crop-cycle/oxygen_source_oracle.py','tests/crop-cycle/run_oxygen_cycle.py']:
        inputs[p]=sha(ROOT/p)
""")
replace("'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']", "'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90']")
replace("'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]", "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','oxygen':b'CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS'}[name]")
replace("'owning_scope':'fresh incumbent MC-MET01 weather/demand/RAINTB composition; full highest/F-CI still pending'", "'owning_scope':'fresh incumbent weather/demand/RAINTB and bounded empirical oxygen production cycle; canonical admission separate'")
replace("    results=[];output_hashes={}","    (output/'executed_controller.py').write_text(executed_source)\n    results=[];output_hashes={}")
ns={'__file__':str(path),'__name__':'__main__','prepare_driver':prepare_driver,'source_oracle':source_oracle,'executed_source':s}
exec(compile(s,str(path),'exec'),ns)
print('CROP_CYCLE_OXYGEN_AND_INCUMBENT_PRESERVATION_O0_O2=PASS')
