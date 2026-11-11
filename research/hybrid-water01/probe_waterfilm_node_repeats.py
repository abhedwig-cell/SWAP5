"""Count exact wet-node repeats on whole-profile cache misses; no physics change.

Uses a completed production build, verifies every original source/object, then
replaces only the provider object with a diagnostic-only counter postimage.
Counters are not production model state and this executable cannot qualify
instance isolation. Native runs retain the ordinary profile and all tolerances.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
bundle = a.bundle.resolve()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
build = json.loads((bundle / 'BUILD.json').read_text())
assert build['status'] == 'ORIGINAL_INTERVAL_COMPLETED'
assert build['profile'] == 'production'
assert build['grass_numerical_profile'] == 'thermal-control-1e-5C'
for name, h in build['source_sha256'].items():
    assert sha(name) == h, name
for name, h in build['object_sha256'].items():
    assert sha(name) == h, name
provider = next(Path(x) for x in build['source_sha256']
                if Path(x).name == 'mod_bartholomeus_waterfilm_provider.f90')
source = provider.read_text()
declarations = '''  integer, save :: observed_calls=0, whole_hits=0
  integer, save :: miss_wet_nodes=0, repeated_miss_wet_nodes=0
'''
source = source.replace('contains\n  subroutine reset_waterfilm_cache',
                        declarations + '\ncontains\n  subroutine reset_waterfilm_cache', 1)
probe = '''        observed_calls=observed_calls+1
        if(allocated(cache%key).and.cache%mode==mode)then
          if(size(cache%key,2)==n)then
            if(all(cache%key==key))then
              whole_hits=whole_hits+1
            else
              do i=1,n
                if(view%pressure_head_cm(i)>=0 .or. &
                   data%soil(i)%saturated_water_content-view%water_content(i)<1.e-4_real64)cycle
                miss_wet_nodes=miss_wet_nodes+1
                if(all(cache%key(:,i)==key(:,i)))repeated_miss_wet_nodes=repeated_miss_wet_nodes+1
              end do
            end if
          end if
        end if
        if(mod(observed_calls,1000)==0)write(*,'(a,4(1x,i0))') &
          'NODE_REPEAT_COUNTS',observed_calls,whole_hits,miss_wet_nodes,repeated_miss_wet_nodes
'''
needle = '        if(allocated(cache%key).and.cache%mode==mode)then'
assert source.count(needle) == 1
source = source.replace(needle, probe + needle)
generated = out / provider.name
generated.write_text(source)
events = []


def run(cmd, label, cwd=out, timeout=60):
    start = time.perf_counter()
    try:
        r = subprocess.run(list(map(str, cmd)), cwd=cwd, capture_output=True,
                           timeout=timeout, env=dict(os.environ, OMP_NUM_THREADS='1'))
        rc = r.returncode
    except subprocess.TimeoutExpired as e:
        r, rc = e, None
    (out / (label + '.stdout')).write_bytes(r.stdout or b'')
    (out / (label + '.stderr')).write_bytes(r.stderr or b'')
    events.append(dict(label=label, command=list(map(str, cmd)),
                       seconds=time.perf_counter()-start, returncode=rc))
    (out / 'events.json').write_text(json.dumps(events, indent=2)+'\n')
    assert rc == 0, (label, rc)


compile_event = next(e for e in build['events'] if e['label'] == 'compile'
                     and str(provider) in e['command'])
cmd = compile_event['command'][:]
obj = out / 'observed.o'
for i, value in enumerate(cmd):
    if value == str(provider):
        cmd[i] = str(generated)
    elif value == '-J'+str(bundle):
        cmd[i] = '-J'+str(out)
cmd[-1] = str(obj)
run(cmd, 'compile')
old_obj = compile_event['command'][-1]
cmd = next(e['command'][:] for e in build['events'] if e['label'] == 'link')
assert cmd.count(old_obj) == 1
cmd[cmd.index(old_obj)] = str(obj)
exe = out / ('observed.exe' if os.name == 'nt' else 'observed')
cmd[-1] = str(exe)
run(cmd, 'link')
inputs = ['input.swp', 'grass.crp', 'input.met', 'swap.bbc', 'swap.dra']
physical = ['budget.csv', 'conductive_budget.csv', 'crop.csv', 'state.csv', 'endpoint.csv']
results = {}
for label, executable in [('baseline', bundle/build['executable']), ('observed', exe)]:
    case = out/label
    case.mkdir()
    for name in inputs:
        shutil.copyfile(bundle/'original-interval'/name, case/name)
    binding = json.loads((bundle/'original-interval/application.binding').read_text())
    binding['executable_sha256'] = sha(executable)
    if label == 'observed':
        binding['source_sha256'][str(provider)] = sha(generated)
    (case/'application.binding').write_text(json.dumps(binding, sort_keys=True))
    run([executable, '4', 'retain-step', '100000', '', 'thermal-control'], label, case, 60)
    results[label] = {name: sha(case/name) for name in physical}
assert results['baseline'] == results['observed'], 'observation changed physical output'
counts = [list(map(int, line.split()[1:])) for line in
          (out/'observed.stdout').read_text().splitlines() if line.startswith('NODE_REPEAT_COUNTS')]
assert counts
result = dict(status='EXACT_PHYSICAL_OUTPUT_OBSERVER_PASS', baseline_build_sha256=sha(bundle/'BUILD.json'),
              source_sha256=sha(provider), observed_source_sha256=sha(generated),
              observed_executable_sha256=sha(exe), events=events,
              original_inputs_sha256={name: sha(out/'baseline'/name) for name in inputs},
              physical_sha256=results, counts=counts,
              columns=['calls', 'whole_profile_hits', 'wet_nodes_on_comparable_misses', 'identical_wet_nodes_on_misses'],
              scope='Four original Grassgrowth days; counters report 1000-call prefixes. First calls after reset excluded from comparable misses.')
(out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(dict(status=result['status'], final_reported_counts=counts[-1])))
