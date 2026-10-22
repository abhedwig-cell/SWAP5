"""Bind the completed current physical proof to the exact additive source seam."""
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT=Path(__file__).resolve().parents[2]
g=runpy.run_path(str(ROOT/'integration/performance/verify_weather_line_search_successor.py'))
path=ROOT/g['STATUS'];r=json.loads(path.read_text())
proof=json.loads((ROOT/'benchmarks/performance/PERF01_LINE_SEARCH_COMPOSITION_20261022_EVIDENCE.json').read_text())
old=json.loads((ROOT/'benchmarks/performance/PERF01_WARM_START_20261022_STATUS.json').read_text())['source_composition_80db']
sha=lambda p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
delta={line.split('\t')[1]:line.split('\t')[0]for line in g['git']('diff','--name-status',g['BASE'],'HEAD','--',*g['SCIENCE']).splitlines()}
inputs={p:sha(p)for p in old['executed_input_sha256']}
inputs.update(proof['current_inputs'])
assert all(sha(p)==h for p,h in inputs.items())
r['source_successor']=dict(baseline=g['BASE'],source_delta=delta,postimages={p:sha(p)for p in delta},
    source_inputs=inputs,evidence=dict(path='benchmarks/performance/PERF01_LINE_SEARCH_COMPOSITION_20261022_EVIDENCE.tar.xz',**proof['evidence']),
    frozen_fsi35_successors=json.loads(Path('/tmp/perf01-lsr-frozen-fsi35.json').read_text()),
    qualified_science=True,qualified_fsi35=False,canonically_admitted=False)
r['status']='CURRENT_TYPED_SOURCE_AND_NATIVE_PASS_ORIGINAL_FSI35_PENDING'
r['qualified']=False
r['next_action']='Run the exact current source owners and controls, complete the independently selected original full FSI35 O0/O2 native body, then current paired CPU and docs/source gates before safe admission. No production default activation.'
path.write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(dict(scientific_paths=len(delta),source_inputs=len(inputs))))
