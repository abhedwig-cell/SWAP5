"""Cold-build pinned original sources for bounded tests, without a model run."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir()
distribution=a.output/'distribution/SWAP_4.3.1'
source=distribution/'tools/SWAP/source';source.mkdir(parents=True)
for name,encoded,digest in [('SWAP.ZIP','SWAP431_ORIGINAL_SOURCE.zip.b64','1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'),
                            ('TTUTIL.ZIP','SWAP431_TTUTIL_AUTHORITY.zip.b64','ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193')]:
    raw=base64.b64decode((ROOT/'integration/audits/evidence'/encoded).read_bytes())
    assert hashlib.sha256(raw).hexdigest()==digest
    (source/name).write_bytes(raw)
for project in ['2.grassgrowth','3.macroporeflow']:
    shutil.copytree(ROOT/'reference/swap-4.3.1/projects'/project,distribution/'cases'/project)
events=[];real_run=subprocess.run
def logged(command,*args,**kwargs):
    start=time.monotonic()
    result=real_run(command,*args,**kwargs)
    events.append({'command':list(map(str,command)),'cwd':str(args[0]) if args else str(kwargs.get('cwd','')),
                   'seconds':time.monotonic()-start,'returncode':result.returncode})
    (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    return result
subprocess.run=logged
sys.path.insert(0,str(ROOT/'tools/vq'))
from b0_source_runner import build_gfortran
exe,logs=build_gfortran(distribution,a.output/'build')
(a.output/'compile.log').write_text(''.join(logs))
assert exe.exists()
print('PINNED_ORIGINAL_SOURCE_COLD_BUILD_PASS_NO_NATIVE_REFERENCE_RUN')
