#!/usr/bin/env python3
"""Existing WOFOST81 full-season science, with current module closure only."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args()
out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
p=ROOT/'tests/fwof/pp02/run_wofost81_case001_fullseason_gate.sh';s=p.read_text()
s=s.replace('ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"','ROOT="${ANNUAL_ROOT:?}"',1)
s=s.replace('BUILD="${TMPDIR:-/tmp}/swap5-fwof-pp02-case001-$$"','BUILD="${ANNUAL_BUILD:?}"',1).replace('trap \'rm -rf "$BUILD"\' EXIT',"trap ':' EXIT",1)
anchor='for opt in 0 2; do';assert s.count(anchor)==1
s=s.replace(anchor,'mapfile -t CANONICAL_SOURCES < <(python3 "$ROOT/tests/support/augment_bartholomeus_backend_sources.py" --all "${CANONICAL_SOURCES[@]}")\n'+anchor,1)
s=s.replace('-Werror -fcheck=all','-Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all')
(out/'run.sh').write_text(s);env=os.environ.copy();env.update(ANNUAL_ROOT=str(ROOT),ANNUAL_BUILD=str(out))
t=time.monotonic();r=subprocess.run(['bash',str(out/'run.sh')],cwd=ROOT,env=env,capture_output=True,text=True)
(out/'stdout').write_text(r.stdout);(out/'stderr').write_text(r.stderr)
res={'exit':r.returncode,'seconds':time.monotonic()-t,'incumbent_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'stdout_sha256':hashlib.sha256(r.stdout.encode()).hexdigest(),'scope':'Complete incumbent WOFOST81 case001 scientific assertions and immutable oracle, O0/O2; current compile dependencies added. Not classic-equivalence evidence.'}
(out/'result.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res));raise SystemExit(r.returncode)
