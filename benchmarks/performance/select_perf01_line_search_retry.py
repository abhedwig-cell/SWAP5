"""Select the actual typed weather option in a current source-verified build."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
a=ap.parse_args();base,out=a.build.resolve(),a.output.resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((base/'BUILD.json').read_text())
assert b['status']=='BUILT'and sha(base/'weather')==b['executable_sha256']
overrides={'tests/fsi/fsi04_real_headcalc_stubs.f90':'grid_stubs.f90',
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90':'observed_serial_runtime.f90',
    'src/runtime/mod_fmr_production_application_bootstrap.f90':'observed_bootstrap.f90'}
for p,h in b['sources'].items():assert sha(base/overrides[p]if p in overrides else ROOT/p)==h,p
assert sha(ROOT/'src/legacy/b1_10_port/headcalc.f90')==b['headcalc_sha256']
text=(base/'driver.f90').read_text()
anchor="  call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'live weather crop bootstrap')"
assert text.count(anchor)==1
text=text.replace(anchor,'  tc%tiles(1)%parameters%weather_line_search_retry=.true.\n'+anchor,1)
for p in base.iterdir():
    if p.is_file()and p.name not in ['driver.f90','weather','BUILD.json']:(out/p.name).symlink_to(p)
(out/'driver.f90').write_text(text)
flags=[v for v in b['flags']if not v.startswith(('-I','-J'))]+['-I'+str(base),'-J'+str(out)]
objects=[base/f'{i:04d}.o'for i in range(len(b['sources']))]
pinned={str(p):sha(p)for p in objects}
command=b['compiler_command']+flags+[str(out/'driver.f90'),str(ROOT/'src/legacy/b1_10_port/headcalc.f90'),*map(str,objects),'-o',str(out/'weather')]
start=time.monotonic();r=subprocess.run(command,capture_output=True)
for stream in ['stdout','stderr']:(out/('link.'+stream)).write_bytes(getattr(r,stream))
r.check_returncode();assert all(sha(Path(p))==h for p,h in pinned.items())
b.update(executable_sha256=sha(out/'weather'),generated_driver_sha256=sha(out/'driver.f90'),weather_line_search_retry=True,
    option_parent_build=str(base),option_link=dict(command=command,returncode=r.returncode,seconds=time.monotonic()-start),
    pinned_objects=pinned)
(out/'BUILD.json').write_text(json.dumps(b,indent=2)+'\n')
print('BUILT_TYPED_WEATHER_LINE_SEARCH_RETRY')
