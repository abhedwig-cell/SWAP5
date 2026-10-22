"""Select the explicit warm option in the existing generated physical driver."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--build',type=Path,required=True)
ap.add_argument('--output',type=Path,required=True)
args=ap.parse_args()
build,out=args.build.resolve(),args.output.resolve()
out.mkdir(parents=True,exist_ok=False)
meta=json.loads((build/'BUILD.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert meta['status']=='BUILT' and sha(build/'weather')==meta['executable_sha256']
text=(build/'driver.f90').read_text()
anchor="  call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'live weather crop bootstrap')"
assert text.count(anchor)==1
text=text.replace(anchor,'  tc%tiles(1)%parameters%weather_trial_warm_start=.true.\n'+anchor)
for path in build.iterdir():
    if path.is_file() and path.name not in ['driver.f90','weather','BUILD.json']:
        (out/path.name).symlink_to(path)
(out/'driver.f90').write_text(text)
flags=[v for v in meta['flags'] if not v.startswith(('-I','-J'))]+['-I'+str(build),'-J'+str(out)]
command=meta['compiler_command']+flags+[str(out/'driver.f90'),str(ROOT/'src/legacy/b1_10_port/headcalc.f90')]
command += [str(build/f'{i:04d}.o') for i in range(len(meta['sources']))]+['-o',str(out/'weather')]
start=time.monotonic();result=subprocess.run(command,capture_output=True)
for stream in ['stdout','stderr']:(out/('link.'+stream)).write_bytes(getattr(result,stream))
result.check_returncode()
meta.update(executable_sha256=sha(out/'weather'),generated_driver_sha256=sha(out/'driver.f90'),
            warm_start_option=True,option_parent_build=str(build),
            option_link={'command':command,'returncode':result.returncode,'seconds':time.monotonic()-start})
(out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps({'status':'BUILT_EXPLICIT_WARM_OPTION','executable_sha256':meta['executable_sha256']}))
