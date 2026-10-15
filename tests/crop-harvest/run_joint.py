"""Reuse the existing complete senescence science runner plus the harvest driver.

Every original driver, assertion, native mutation and immutable endpoint check
is retained. Providers are shared in the same live O0/O2 execution only.
"""
from pathlib import Path
import hashlib,json,os,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['HARVEST_JOINT_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=False)
s=(ROOT/'tests/nut-senescence/run_senescence.py').read_text()
needle="if mode=='joint':drivers += [ROOT/'tests/nut-material/test_material_joint.f90',ROOT/'tests/nut-material-environment/test_material_environment_joint.f90',ROOT/'tests/nut-senescence/test_senescence_joint.f90']"
assert s.count(needle)==1;s=s.replace(needle,needle+"+[ROOT/'tests/crop-harvest/test_harvest_joint.f90']")
s=s.replace("'test_senescence_joint':'senescence-'", "'test_senescence_joint':'senescence-','test_harvest_joint':'harvest-'")
s=s.replace("if d.stem!='test_senescence_joint':", "if d.stem not in ['test_senescence_joint','test_harvest_joint']:")
needle="   rawdisk=bytearray(first.read_bytes());mutants="
a=s.index(needle)
s=s[:a]+'''   if d.stem=='test_harvest_joint':
    assert first.read_bytes()[:8]==b'S5NC0006'
    assert end.read_bytes()[:8]==b'S5NC0005'
    # Entire admitted water record is unchanged by harvest incorporation.
    disk=first.read_bytes();nodes=struct.unpack_from('<i',disk,152)[0]
    history=struct.unpack_from('<i',disk,156)[0]
    water_end=160+16*nodes+16+(8*nodes if history else 0)
    assert disk[8:water_end]==end.read_bytes()[8:water_end]
    row['drivers'][d.stem]['water_record_unchanged']=True
    continue
'''+s[a:]
s=s.replace("for name in ['test_material_joint','test_material_environment_joint','test_senescence_joint']:","for name in ['test_material_joint','test_material_environment_joint','test_senescence_joint','test_harvest_joint']:")
s=s.replace("for p in [Path(__file__),ROOT/'tests/nut-crop/crop_fixture.inc'", "for p in [ROOT/'tests/crop-harvest/run_joint.py',ROOT/'tests/nut-senescence/run_senescence.py',ROOT/'tests/nut-crop/crop_fixture.inc'")
(OUT/'executed_runner.py').write_text(s)
(OUT/'GENERATION.json').write_text(json.dumps(dict(executed_runner_sha256=hashlib.sha256(s.encode()).hexdigest(),source_runner_sha256=hashlib.sha256((ROOT/'tests/nut-senescence/run_senescence.py').read_bytes()).hexdigest()),indent=2)+'\n')
os.environ['SENESCENCE_RESULT_DIR']=str(OUT);sys.argv=[str(ROOT/'tests/nut-senescence/run_senescence.py'),'joint']
exec(compile(s,str(OUT/'executed_runner.py'),'exec'),globals())
