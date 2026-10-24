"""Capture a real failed old Picard request for a small production-provider test."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '367c11e394e3f166f861d9f1502aaeeda01215d7'
HEAD = 'src/legacy/b1_10_port/headcalc.f90'


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
    text = subprocess.check_output(['git', 'show', BASELINE + ':' + HEAD], cwd=ROOT).decode()
    anchor = '   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t\n'
    assert text.count(anchor) == 1
    text = text.replace(anchor, anchor + '   use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t\n')
    anchor = '!  Convergence could not been reached\n'
    assert text.count(anchor) == 1
    text = text.replace(anchor, anchor + '''   if(picard_conductivity_iteration.and.provider_dynamic_top_active.and. &
      any(abs(state%hm1(1:NN))<=sqrt(epsilon(1d0))))then
      block
         integer::fixture_unit
         logical::fixture_exists
         inquire(file='corner_fixture.dat',exist=fixture_exists)
         if(.not.fixture_exists)then
         select type(hp=>evaluation_context%constitutive)
         type is(b110_default_mvg_provider_t)
         select type(top=>evaluation_context%dynamic_top_boundary)
         type is(b110_dynamic_top_boundary_solver_provider_t)
            open(newunit=fixture_unit,file='corner_fixture.dat',status='new')
            write(fixture_unit,*)NN
            write(fixture_unit,*)(grid_z(i),i=1,NN),(grid_dz(i),i=1,NN),(grid_disnod(i),i=1,NN)
            write(fixture_unit,*)hp%parameters%cofgen(1:24,1:NN)
            write(fixture_unit,*)state%hm1(1:NN),state%thetm1(1:NN),state%pondm1,state%gwlm1
            write(fixture_unit,*)fsi_ws%sink(1:NN),fsi_ws%source(1:NN),(root_sink_term(i),i=1,NN)
            write(fixture_unit,*)boundary_conditions
            write(fixture_unit,*)numerical_config
            write(fixture_unit,*)dt
            write(fixture_unit,*)top%previous_ponding_depth,top%precipitation_rate,top%irrigation_rate, &
               top%snowmelt_rate,top%runon_rate,top%potential_bare_soil_evaporation, &
               top%potential_pond_evaporation,top%ponding_max,top%runoff_resistance,top%runoff_exponent, &
               top%fixed_top_node_conductivity,top%implicit_conductivity
            close(fixture_unit)
         end select
         end select
         end if
      end block
   end if
''')
    generated = out / 'headcalc.f90'
    generated.write_text(text)
    meta = json.loads((a.bundle / 'shared/build-complete.json').read_text())
    old = next(e['command'] for e in meta['events'] if str(ROOT / HEAD) in e['command'])
    old_object = old[-1]
    events = []

    def run(cmd, cwd, label):
        cmd = list(map(str, cmd))
        t = time.perf_counter()
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=120)
        (out / (label + '.stdout')).write_bytes(p.stdout)
        (out / (label + '.stderr')).write_bytes(p.stderr)
        events.append(dict(label=label, command=cmd, returncode=p.returncode, seconds=time.perf_counter() - t))
        (out / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        return p.returncode

    command = [str(generated) if x == str(ROOT / HEAD) else str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in old]
    assert run(command, out, 'compile') == 0
    link = next(e['command'] for e in json.loads((a.build / 'RESULT.json').read_text())['events'] if e['label'] == 'build')
    command = [str(out / 'project') if x == str(a.build / 'project') else
               str(out / 'headcalc.o') if x == old_object else
               '-J' + str(out) if x.startswith('-J') else x for x in link]
    assert run(command, out, 'link') == 0
    case = out / 'case'
    case.mkdir()
    for n in ['input.nml', 'input.swp']:
        (case / n).write_bytes((a.case / n).read_bytes())
    assert run([out / 'project', 'input.nml', '-', a.stop, 'input.swp'], case, 'native') != 0
    for n in ['budget.csv', 'diagnostic-partial-candidate.bin']:
        assert (case / n).read_bytes() == (a.case / n).read_bytes(), n
    raw = (case / 'corner_fixture.dat').read_bytes()
    r = dict(status='REAL_FAILED_REQUEST_CAPTURED_OLD_PHYSICAL_BYTES_EXACT', baseline=BASELINE,
             fixture_sha256=hashlib.sha256(raw).hexdigest(), events=events)
    (out / 'RESULT.json').write_text(json.dumps(r, indent=2) + '\n')
    print(json.dumps({k: r[k] for k in ['status', 'fixture_sha256']}))


if __name__ == '__main__':
    main()
