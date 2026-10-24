"""Research relink: one consistent-Jacobian retry after failed corner Picard."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '367c11e394e3f166f861d9f1502aaeeda01215d7'


def transform(text):
    anchor = '   logical :: corner_retry_available, corner_retry_active\n'
    assert text.count(anchor) == 1
    text = text.replace(anchor, anchor + '''   logical :: picard_corner_available, picard_corner_active
   type(reference_richards_state_binding_t) :: picard_corner_entry
''')
    anchor = '   saturated_flux_available = saturated_flux_restart_admitted()\n'
    assert text.count(anchor) == 1
    text = text.replace(anchor, '''   picard_corner_active=.false.
   picard_corner_available=picard_conductivity_iteration.and.provider_dynamic_top_active.and. &
      swmacro==0.and.swbotb==2.and.swkimpl==0.and.swkmean==1.and..not.scale_matrix_area
   if(picard_corner_available)then
      picard_corner_available=any(abs(state%hm1(1:NN))<=sqrt(epsilon(1d0)))
      select type(provider=>evaluation_context%constitutive)
      type is(b110_default_mvg_provider_t)
         picard_corner_available=picard_corner_available.and.provider%parameters%continuous_saturation_conductivity.and. &
            .not.provider%parameters%elastic_storage_active.and..not.provider%parameters%ksatexm_extension_enabled.and. &
            .not.provider%parameters%conductivity_power_tail_enabled
      class default
         picard_corner_available=.false.
      end select
      if(picard_corner_available)picard_corner_entry=state
   end if
''' + anchor)
    anchor = '!  Convergence could not been reached\n'
    assert text.count(anchor) == 1
    text = text.replace(anchor, anchor + '''   if(picard_corner_available.and..not.picard_corner_active)then
      state=picard_corner_entry
      picard_corner_active=.true.
      consistent_provider_conductivity=.true.
      iBackTr=0
      ctx%diagnostics%internal_retries=ctx%diagnostics%internal_retries+1
      goto 900
   end if
''')
    return text


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle', type=Path, required=True)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--case', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--stop', type=int, required=True)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    r = dict(status='RUNNING_RESEARCH', production_qualified=False, events=[])

    def run(cmd, cwd, label):
        cmd = list(map(str, cmd))
        t = time.perf_counter()
        try:
            p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=120)
            code, stdout, stderr = p.returncode, p.stdout, p.stderr
        except subprocess.TimeoutExpired as e:
            code, stdout, stderr = 'CENSORED', e.stdout or b'', e.stderr or b''
        (out / (label + '.stdout')).write_bytes(stdout)
        (out / (label + '.stderr')).write_bytes(stderr)
        r['events'].append(dict(label=label, command=cmd, seconds=time.perf_counter() - t, returncode=code))
        (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')
        return code

    head = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
    generated = out / 'headcalc.f90'
    original = subprocess.check_output(['git', 'show', BASELINE + ':' + str(head.relative_to(ROOT))], cwd=ROOT)
    generated.write_text(transform(original.decode()))
    meta = json.loads((a.bundle / 'shared/build-complete.json').read_text())
    old = next(e['command'] for e in meta['events'] if str(head) in e['command'])
    assert hashlib.sha256(original).hexdigest() == meta['input_sha256'][str(head.relative_to(ROOT))]
    old_object = old[-1]
    command = [str(generated) if x == str(head) else str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in old]
    assert run(command, out, 'head-build') == 0
    link = next(e['command'] for e in json.loads((a.build / 'RESULT.json').read_text())['events'] if e['label'] == 'build')
    command = [str(out / 'project') if x == str(a.build / 'project') else
               str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in link]
    assert run(command, out, 'link') == 0
    case = out / 'case'
    case.mkdir()
    for name in ['input.nml', 'input.swp']:
        (case / name).write_bytes((a.case / name).read_bytes())
    code = run([out / 'project', 'input.nml', '-', a.stop, 'input.swp'], case, 'native')
    r['status'] = 'RESEARCH_COMPLETED' if code == 0 else 'RESEARCH_REJECTED_OR_CENSORED'
    r['head_source_sha256'] = hashlib.sha256(generated.read_bytes()).hexdigest()
    (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')
    print(r['status'])


if __name__ == '__main__':
    main()
