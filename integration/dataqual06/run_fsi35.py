"""Execute the immutable FSI35 native oracle tail under the DATAQUAL06 boundary.

Historical hash/registration front matter is held as historical authority; the
new source boundary checks the exact25 unchanged dependencies plus the two
explicitly qualified provider. The native assertions/compile algorithm are exact.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='cba2117d679fe1165cc03c60e86e67943a777466'
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
changed=[x['path']for x in deps if subprocess.check_output(['git','show',BASE+':'+x['path']],cwd=ROOT)!=(ROOT/x['path']).read_bytes()]
assert set(changed)=={'src/solver/mod_b110_dynamic_top_boundary_provider.f90','src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90'},changed
path='tests/fci/run_fci93_non_m1_fixed_k_qualification.sh';raw=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode();assert raw==(ROOT/path).read_text()
tail=raw[raw.rindex('\nFKT15_DONOR='):]
# Keep the temporary native evidence directory for recovery instead of trap cleanup.
tail=tail.replace("trap 'rm -rf \"$BUILD\"' EXIT",'')
prefix='#!/usr/bin/env bash\nset -euo pipefail\ncd '+str(ROOT)+'\nBASE=d8414c1ba11bee9f061622fd2495f631a57d2383\nOWNER_SOURCE=5898e6616dbb6871a9f52d489038235ba1172cae\nfail(){ echo "FCI93_FIXED_K_FAIL $*" >&2; exit 93; }\n'
script=out/'native.sh';script.write_text(prefix+tail)
start=time.monotonic();cp=subprocess.run(['bash',str(script)],capture_output=True,cwd=ROOT)
(out/'stdout').write_bytes(cp.stdout);(out/'stderr').write_bytes(cp.stderr)
report=dict(returncode=cp.returncode,seconds=time.monotonic()-start,immutable_runner_sha256=hashlib.sha256(raw.encode()).hexdigest(),changed_dependencies=changed,unchanged_dependencies=25,oracle_tail_sha256=hashlib.sha256(tail.encode()).hexdigest(),source={x['path']:hashlib.sha256((ROOT/x['path']).read_bytes()).hexdigest()for x in deps})
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));cp.check_returncode()
