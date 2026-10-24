"""Observe unchanged HeadCalc rejections in the bounded-interval research driver."""
import argparse
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build', type=Path, required=True)
    ap.add_argument('--bundle', type=Path, required=True)
    ap.add_argument('--case', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--stop', type=int, required=True)
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    r = dict(status='RESEARCH_OBSERVATION_RUNNING', production_changed=False, events=[])

    def save():
        (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')

    def run(cmd, cwd, label):
        t = time.perf_counter()
        p = subprocess.run(list(map(str, cmd)), cwd=cwd, capture_output=True, timeout=120)
        (out / (label + '.stdout')).write_bytes(p.stdout)
        (out / (label + '.stderr')).write_bytes(p.stderr)
        r['events'].append(dict(label=label, command=list(map(str, cmd)), returncode=p.returncode,
                                seconds=time.perf_counter() - t))
        save()
        return p

    meta = json.loads((a.bundle / 'shared/build-complete.json').read_text())
    head = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
    text = head.read_text()
    needle = '!  Convergence could not been reached\n'
    assert text.count(needle) == 1
    text = text.replace(needle, needle + '''   write(*,*)'PERF01_HEAD_REJECT',dt,Fmax,sum1,state%ftoph,state%pondm1,state%pond,state%qtop
   write(*,*)'PERF01_HEAD_ORIGIN',minval(state%hm1(1:NN)),maxval(state%hm1(1:NN))
   write(*,*)'PERF01_HEAD_CANDIDATE',minval(state%h(1:NN)),maxval(state%h(1:NN))
''')
    generated = out / 'observed_headcalc.f90'
    generated.write_text(text)
    compile_command = next(e['command'] for e in meta['events'] if str(head) in e['command'])
    old_object = compile_command[-1]
    command = [str(generated) if x == str(head) else str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in compile_command]
    assert run(command, out, 'head-build').returncode == 0
    driver = (a.build / 'main.f90').read_text()
    needle = '      if(part%status/=JOINT_OK)then'
    assert driver.count(needle) == 1
    driver = driver.replace(needle, needle + "\n        write(*,*)'PERF01_FAILED_SEGMENT',j,cursor,endpoint,rain_rates(idx)")
    main_source = out / 'main.f90'
    main_source.write_text(driver)
    link = next(e['command'] for e in json.loads((a.build / 'RESULT.json').read_text())['events'] if e['label'] == 'build')
    command = [str(main_source) if x == str(a.build / 'main.f90') else
               str(out / 'project') if x == str(a.build / 'project') else
               str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in link]
    assert run(command, out, 'link').returncode == 0
    case = out / 'case'
    case.mkdir()
    for n in ['input.nml', 'input.swp']:
        (case / n).write_bytes((a.case / n).read_bytes())
    p = run([out / 'project', 'input.nml', '-', a.stop, 'input.swp'], case, 'native')
    assert p.returncode != 0
    r['physical_identity'] = {}
    for n in ['budget.csv', 'diagnostic-partial-candidate.bin']:
        r['physical_identity'][n] = (case / n).read_bytes() == (a.case / n).read_bytes()
    assert all(r['physical_identity'].values())
    r['failed_segment'] = [line for line in p.stdout.decode().splitlines() if 'PERF01_FAILED_SEGMENT' in line]
    r['last_head_observations'] = [line for line in p.stdout.decode().splitlines() if 'PERF01_HEAD_' in line][-12:]
    r['status'] = 'OBSERVED_REJECTION_PHYSICAL_BYTES_EXACT'
    save()
    print(json.dumps({k: r[k] for k in ['status', 'failed_segment', 'last_head_observations']}))


if __name__ == '__main__':
    main()
