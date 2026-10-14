"""One O0/O2 provider build, fresh incumbent and CO2 scientific executables."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tests/crop-cycle')]
from co2_cycle_driver import prepare as prepare_co2
from co2_source_oracle import prepare as co2_oracle
from oxygen_cycle_driver import prepare as prepare_oxygen
from oxygen_source_oracle import prepare as oxygen_oracle
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
path=ROOT/'tests/mc-met01/run_raintb_legacy_owner_preservation.py';s=path.read_text()
def replace(old,new):
 global s
 assert s.count(old)==1,old
 s=s.replace(old,new)
replace('    inputs={p:sha(ROOT/p) for p in providers}', '''    drivers['oxygen']=prepare_oxygen(ROOT,output/'oxygen_driver.f90')
    drivers['co2']=prepare_co2(ROOT,output/'co2_driver.f90')
    oxygen_oracle(ROOT,fixture/'oxygen_oracle.f90')
    co2_oracle(ROOT,fixture/'co2_oracle.f90')
    inputs={p:sha(ROOT/p) for p in providers}
    for folder in ['tests/crop-cycle','tests/crop-co2']:
        for p in (ROOT/folder).glob('*'):
            if p.suffix in ['.py','.inc','.f90']:inputs[str(p.relative_to(ROOT))]=sha(p)
''')
replace("'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']", "'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90','co2_oracle.f90']")
replace("'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]", "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','oxygen':b'CROP_CYCLE_OXYGEN_PHYSICAL_LITERAL_RESTART=PASS','co2':b'CROP_CO2_PHYSICAL_GROWTH_UPTAKE_RESTART=PASS'}[name]")
replace('    results=[];output_hashes={}',"    (output/'executed_controller.py').write_text(executed_source)\n    results=[];output_hashes={}")
ns={'__file__':str(path),'__name__':'__main__','prepare_oxygen':prepare_oxygen,'prepare_co2':prepare_co2,'co2_oracle':co2_oracle,'oxygen_oracle':oxygen_oracle,'executed_source':s}
exec(compile(s,str(path),'exec'),ns)
print('CROP_CO2_AND_INCUMBENT_PHYSICAL_O0_O2=PASS')
