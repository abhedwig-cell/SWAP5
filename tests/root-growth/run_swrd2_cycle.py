"""Focused current SWRD2 and incumbent SWRD3/default daily Richards O0/O2."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tests/crop-cycle'),str(ROOT/'tests/crop-co2')]
from swrd2_cycle_driver import prepare as swrd2
from swrd3_cycle_driver import prepare as swrd3
from co2_source_oracle import prepare as co2_oracle
from oxygen_source_oracle import prepare as oxygen_oracle
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
path=ROOT/'tests/mc-met01/run_raintb_legacy_owner_preservation.py';s=path.read_text()
def replace(a,b):
 global s
 assert s.count(a)==1,a
 s=s.replace(a,b)
replace("    inputs={p:sha(ROOT/p) for p in providers}","    inputs={p:sha(ROOT/p) for p in providers}")
anchor="    inputs.update({p:sha(ROOT/p) for p in PINS})"
replace(anchor,"""    drivers={'weather':drivers['weather'],
      'swrd3':swrd3(ROOT,output/'swrd3.f90'),
      'swrd2':swrd2(ROOT,output/'swrd2.f90'),
      'swrd2_off':swrd2(ROOT,output/'swrd2_off.f90',False),
      'swrd2_unscaled':swrd2(ROOT,output/'swrd2_unscaled.f90',False,False)}
    oxygen_oracle(ROOT,fixture/'oxygen_oracle.f90');co2_oracle(ROOT,fixture/'co2_oracle.f90')
    for p in ['tests/root-growth/run_swrd2_cycle.py','tests/root-growth/swrd2_cycle_driver.py',
      'tests/root-growth/swrd3_cycle_driver.py','tests/crop-cycle/oxygen_cycle_driver.py',
      'tests/crop-cycle/oxygen_segment_oracle.inc','tests/crop-cycle/oxygen_source_oracle.py',
      'tests/crop-co2/co2_source_oracle.py','tests/support/augment_bartholomeus_backend_sources.py',
      'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']:
      inputs[p]=sha(ROOT/p)
"""+anchor)
replace("'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']", "'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90','co2_oracle.f90']")
replace("'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]", "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','swrd3':b'SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS','swrd2':b'SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS','swrd2_off':b'SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS','swrd2_unscaled':b'SWRD2_ACTUAL_RICHARDS_DEPTH_OXYGEN_JOINT_RESTART=PASS'}[name]")
replace('    results=[];output_hashes={}',"    (output/'executed_controller.py').write_text(executed_source)\n    results=[];output_hashes={}")
ns={'__file__':str(path),'__name__':'__main__','swrd2':swrd2,'swrd3':swrd3,'co2_oracle':co2_oracle,'oxygen_oracle':oxygen_oracle,'executed_source':s}
exec(compile(s,str(path),'exec'),ns)
print('SWRD2_FOCUSED_AND_INCUMBENT_PHYSICAL_O0_O2=PASS')
