#!/usr/bin/env python3
"""Research-only attribution of unchanged canonical oxygen sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import statistics
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--result', type=Path, required=True)
args = parser.parse_args()
test = root / 'tests/performance/benchmark_bartholomeus_perf03_attribution.f90'
fc = shlex.split(os.environ.get('FC', 'gfortran'))
modules = {}
for path in sorted((root / 'src').rglob('*.f90')):
    for name in re.findall(r'^\s*module\s+(\w+)\s*$', path.read_text(), re.M | re.I):
        modules[name.lower()] = path
seen, ordered = set(), []
def visit(path):
    if path in seen:
        return
    seen.add(path)
    for name in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)', path.read_text(), re.M | re.I):
        if name.lower() in modules:
            visit(modules[name.lower()])
    ordered.append(path)
visit(test)
response = modules['mod_bartholomeus_response']
source = response.read_text()
assert source.count('\ncontains\n') == 1
needle = '         c_micro = bartholomeus_micro_concentration(p%micro,x)'
assert source.count(needle) == 1
instrumented = source.replace('\ncontains\n', '\n   integer,public,save :: perf03_residual_calls=0\ncontains\n').replace(
    needle, '         perf03_residual_calls=perf03_residual_calls+1\n'+needle)
result = {
    'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
    'compiler': subprocess.check_output(fc+['--version'],text=True).splitlines()[0],
    'fixture': {'nodes':3,'head_cm':-75,'water_content':0.40,'temperature_K':293,'ctop':0.27},
    'source_sha256': {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},
    'instrumentation': {'original_sha256':hashlib.sha256(source.encode()).hexdigest(),
                        'temporary_sha256':hashlib.sha256(instrumented.encode()).hexdigest(),
                        'scope':'One saved counter increment per actual residual callback; temporary diagnostic build only, excluded from timing.'},
    'qualification':{},'timing_outputs':[]}
def build(directory, flags, count=False):
    directory.mkdir()
    flags = flags+['-cpp','-ffree-line-length-none','-J'+str(directory),'-I'+str(directory)]
    objects=[]
    for path in ordered[:-1]:
        actual=path
        if count and path==response:
            actual=directory/path.name
            actual.write_text(instrumented)
        obj=directory/(path.stem+'.o')
        subprocess.run(fc+flags+['-c',str(actual),'-o',str(obj)],check=True)
        objects.append(str(obj))
    exe=directory/'benchmark'
    subprocess.run(fc+flags+(['-DPERF03_COUNT'] if count else [])+objects+[str(test),'-o',str(exe)],check=True)
    return exe
with tempfile.TemporaryDirectory(prefix='perf03-attribution-') as tmp:
    base=Path(tmp)
    for opt,flags in [('O0',['-O0','-std=f2008','-fcheck=all']),('O2',['-O2','-std=f2008'])]:
        plain=build(base/(opt+'-plain'),flags)
        counted=build(base/(opt+'-counted'),flags,True)
        normal=subprocess.check_output([str(plain),'check'],text=True)
        diagnostic=subprocess.check_output([str(counted),'check'],text=True)
        assert normal==''.join(line+'\n' for line in diagnostic.splitlines() if not line.startswith('PERF03_RESIDUAL_COUNT|'))
        assert 'PERF03_GATE_NEGATIVE_AND_FACTOR_IDENTITY=PASS' in normal
        result['qualification'][opt]={'plain':normal,'counted':diagnostic,'instrumented_plain_identity':True}
    def science(out):
        return [float(x) for x in re.findall(r'(?:FILM|FACTOR)=\s*([0-9.Ee+\-]+)',out)]
    a=science(result['qualification']['O0']['plain']);b=science(result['qualification']['O2']['plain'])
    assert len(a)==len(b)==6
    assert all(abs(x-y)<=1e-13*max(abs(x),abs(y),1e-12) for x,y in zip(a,b))
    counts = lambda out: re.findall(r'PERF03_RESIDUAL_COUNT\|NODE=(\d+)\|CALLS=(\d+)',out)
    assert counts(result['qualification']['O0']['counted'])==counts(result['qualification']['O2']['counted'])
    result['residual_calls_per_node']=counts(result['qualification']['O0']['counted'])
    exe=build(base/'O3-timing',['-O3','-march=native'])
    rows=[]
    for _ in range(7):
        out=subprocess.check_output([str(exe)],text=True)
        result['timing_outputs'].append(out)
        row={k:float(v) for k,v in re.findall(r'PERF03_TIME\|STAGE=(\w+)\|NS=\s*([0-9.Ee+\-]+)',out)}
        assert set(row)=={'WATERFILM','ASSEMBLY','PROFILE','FULL'}
        rows.append(row)
    result['timing']={'flags':['-O3','-march=native'],'warmup':100,'repetitions':5000,'runs':rows,
                      'median_ns':{k:statistics.median(r[k] for r in rows) for k in rows[0]}}
    result['timing']['stage_sum_to_full_ratio']=sum(result['timing']['median_ns'][k] for k in ['WATERFILM','ASSEMBLY','PROFILE'])/result['timing']['median_ns']['FULL']
args.result.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'qualification':'PASS','residual_calls_per_node':result['residual_calls_per_node'],'timing':result['timing']},indent=2))
