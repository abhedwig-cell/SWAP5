"""Fresh isolated builds for the uncovered actual anaerobic branch; no cache reuse."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tests/crop-co2'),str(ROOT/'tests/crop-cycle')]
from swrd3_discriminator_driver import prepare as prepare_swrd3
from co2_source_oracle import prepare as co2_oracle
from oxygen_source_oracle import prepare as oxygen_oracle
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
path=ROOT/'tests/mc-met01/run_raintb_legacy_owner_preservation.py';s=path.read_text()
def replace(a,b):
 global s
 assert s.count(a)==1,a;s=s.replace(a,b)
replace('    inputs={p:sha(ROOT/p) for p in providers}', '''    drivers={'swrd3_probe':prepare_swrd3(ROOT,output/'swrd3_probe.f90'),
             'swrd3_probe_off':prepare_swrd3(ROOT,output/'swrd3_probe_off.f90',False)}
    oxygen_oracle(ROOT,fixture/'oxygen_oracle.f90');co2_oracle(ROOT,fixture/'co2_oracle.f90')
    inputs={p:sha(ROOT/p) for p in providers}
    for p in ['tests/crop-cycle/oxygen_cycle_driver.py','tests/crop-cycle/oxygen_segment_oracle.inc',
              'tests/crop-cycle/oxygen_source_oracle.py','tests/crop-co2/co2_source_oracle.py',
              'tests/root-growth/swrd3_cycle_driver.py','tests/root-growth/swrd3_discriminator_driver.py',
              'tests/root-growth/run_swrd3_discriminator.py','tests/support/augment_bartholomeus_backend_sources.py',
              'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']:
        inputs[p]=sha(ROOT/p)
''')
replace("    for name,include,call in [('daily_demand','test_daily_demand_production.inc','test_daily_demand_production'),\n                              ('raintb','test_raintb_production.inc','test_raintb_production')]:", "    for name,include,call in []:")
replace("'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']", "'task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90','oxygen_oracle.f90','co2_oracle.f90']")
replace("marker={'weather':b'CROP_FILE_WEATHER_PRODUCTION=PASS','daily_demand':b'MC_MET01_AUTHENTIC_DAILY_DEMAND_RETRY_RESTART_MASS=PASS','raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]", "marker=b'SWRD3_ACTUAL_RICHARDS_GROWTH_OXYGEN_JOINT_RESTART=PASS'\n                    if name=='swrd3_probe':\n                        assert b'SWRD3_ACTUAL_RICHARDS_ANAEROBIC_ROOT_DEATH=PASS'in raw,'probe must actually suppress growth'")
replace('    results=[];output_hashes={}',"    (output/'executed_controller.py').write_text(executed_source)\n    results=[];output_hashes={}")
ns={'__file__':str(path),'__name__':'__main__','prepare_swrd3':prepare_swrd3,'co2_oracle':co2_oracle,'oxygen_oracle':oxygen_oracle,'executed_source':s}
exec(compile(s,str(path),'exec'),ns)
print('SWRD3_ACTUAL_ANAEROBIC_DISCRIMINATOR_O0_O2=PASS')
