#!/usr/bin/env python3
"""Research-only profile discriminator over existing physical backend."""
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
DRIVER=ROOT/'tests/fgc/recovered/test_fgc31_active_drainage_production_tangent.f90'
RUNNER=ROOT/'tests/fgc/run_fgc31_current_drainage_profile_boundary.sh'
def blob(path):
    data=path.read_bytes()
    return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
assert blob(DRIVER)=='3d6f0320e16509ef22455393ce390ff6930bbb2f', 'driver drift requires reconciliation'
assert blob(RUNNER)=='d4d03da356275ece3895aad3ad5ec388438b0c5f', 'runner drift requires reconciliation'
driver=DRIVER.read_text()
assert driver.count('\ncontains\n')==1
probe=(ROOT/'tests/fgc/test_fixed_gwl_head_drainage_probe.inc').read_text()
driver=driver.replace('\ncontains\n','\n  call check_fixed_gwl_head_drainage()\n\ncontains\n'+probe+'\n')
with tempfile.TemporaryDirectory(prefix='swap5-fixed-gwl-head-') as tmp:
    driver_path=Path(tmp)/'driver.f90'
    driver_path.write_text(driver)
    runner=RUNNER.read_text().replace('tests/fgc/recovered/test_fgc31_active_drainage_production_tangent.f90',str(driver_path))
    lines=runner.splitlines()
    assert lines[2].startswith('ROOT=')
    lines[2]='ROOT="'+str(ROOT)+'"'
    script=Path(tmp)/'run.sh'
    script.write_text('\n'.join(lines)+'\n')
    subprocess.run(['bash',str(script)],cwd=ROOT,check=True)
