"""Current production component composition, not whole-application energy admission.

Reuses immutable Sprint04 inputs; does not inherit its whole-tree PASS. Compiles
the actual current heat owner and exact storage/ledger owner in one executable.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT / 'integration/dataqual15/SPRINT04_ENERGY_COMPONENT_INPUTS.tar.xz'
ARCHIVE_SHA = '46ba4ef8101cf8a4b533f3d8c12761fb20d71488ea634e9f5f77862be29ed277'
INPUT_SHA = 'cc10198a7e5ed88037e49609fc85086e10f4a257299da4e89b3b2c31270b28c6'
SOURCES = [
    'src/transaction/mod_transaction_reference.f90',
    'src/solver/mod_soil_water_solver_contract.f90',
    'src/solver/mod_process_hydraulic_view.f90',
    'src/process/mod_soil_temperature_contract.f90',
    'src/process/mod_restricted_soil_temperature.f90',
    'src/kernel/mod_energy_conservation_types.f90',
    'src/process/mod_linear_mixture_sensible_storage.f90',
    'src/process/mod_whole_column_sensible_energy_accounting.f90',
    'tests/dataqual15/energy_boundary_driver.f90',
]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def inputs():
    assert sha(ARCHIVE.read_bytes()) == ARCHIVE_SHA, 'immutable input archive changed'
    with tarfile.open(ARCHIVE) as archive:
        members = archive.getmembers()
        assert len(members) == 109
        assert len({m.name for m in members}) == len(members)
        assert all(m.isfile() and not Path(m.name).is_absolute() and
                   '..' not in Path(m.name).parts for m in members)
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    assert manifest == {name: sha(raw) for name, raw in files.items()}
    raw = files['Windows/inputs.dat']
    assert raw == files['Linux/inputs.dat'] and sha(raw) == INPUT_SHA
    return raw


def observe(text, raw):
    """Independent endpoint stock/decomposition, using explicit driver states."""
    lines = raw.decode().splitlines()
    n, count = map(int, lines[0].split())
    assert (n, count) == (113, 432)
    dz, porosity = [[float(x) for x in lines[i].split()] for i in (2, 4)]
    params, states, missing, counter, domains, ledger_status = {}, {}, {}, {}, {}, {}
    for line in text.splitlines():
        fields = line.split(',')
        if fields[0] == 'PARAM':
            params[int(fields[1])] = list(map(float, fields[2:]))
        elif fields[0] == 'NODE':
            states[int(fields[1]), int(fields[2])] = float(fields[3])
        elif fields[0] == 'LEDGER_STATUS':
            ledger_status[tuple(map(int,fields[1:3]))] = int(fields[3])
        elif fields[0] == 'RAW_DOMAIN':
            domains[tuple(map(int,fields[1:3]))] = int(fields[3])
        elif fields[0] in ('MISSING', 'ZERO_ADVECTION_COUNTERFACTUAL'):
            target = missing if fields[0] == 'MISSING' else counter
            key = tuple(map(int, fields[1:3]))
            assert key not in target
            target[key] = list(map(float, fields[3:]))
    assert len(params) == n and len(states) == n * count
    assert len(missing) == len(counter) == len(domains) == count * 2
    assert len(ledger_status)==count*2 and set(ledger_status.values())<={0,4}
    assert set(domains.values()) <= {2,3}
    max_normalization = 0.
    worst = dict(independent_stock_error_j_m2=0., independent_composition_error_j_m2=0.,
                 counterfactual_residual_error_j_m2=0.)
    maxima = {}
    for case in range(1, count + 1):
        at = 9 + (case - 1) * 5
        day, kind, dt, air = map(float, lines[at].split())
        theta0, theta1, old = [[float(x) for x in lines[at + k].split()] for k in (2, 3, 4)]
        raw_outside = any(x<0 or x>porosity[j] for data in (theta0,theta1) for j,x in enumerate(data))
        for gauge in (0, 1):
            assert domains[case,gauge] == (2 if raw_outside else 3)
            reference = 5. * gauge
            stock = composition = 0.
            for j in range(n):
                pdz, psat, quartz, clay, organic, distance = params[j + 1]
                assert abs(pdz - dz[j]) < 1e-12 and abs(psat - porosity[j]) < 1e-12
                a,b = theta0[j],theta1[j]
                theta0[j] = min(porosity[j],max(0.,a))
                theta1[j] = min(porosity[j],max(0.,b))
                max_normalization=max(max_normalization,abs(a-theta0[j]),abs(b-theta1[j]))
                assert max_normalization <= 64*2.220446049250313e-16
                solid = quartz * 2.128 + clay * 2.385 + organic * 2.496
                c0 = solid + theta0[j] * 4.18 + (porosity[j] - theta0[j]) * .001212
                c1 = solid + theta1[j] * 4.18 + (porosity[j] - theta1[j]) * .001212
                new = states[case, j + 1]
                stock += dz[j] * (c1 * (new-reference) - c0 * (old[j]-reference)) * 1e4
                composition += dz[j] * (c1-c0) * ((new+old[j])/2-reference) * 1e4
            measured, temperature, measured_composition = missing[case, gauge]
            residual, decomposition_error = counter[case, gauge]
            for name, error in [('independent_stock_error_j_m2', abs(stock-measured)),
                                ('independent_composition_error_j_m2', abs(composition-measured_composition)),
                                ('counterfactual_residual_error_j_m2', abs(residual-composition))]:
                worst[name] = max(worst[name], error)
                assert error < 1e-6, (case, gauge, name, error)
            assert abs(decomposition_error) < 1e-6
            key = f'kind{int(kind)}_gauge{int(reference)}'
            maxima[key] = max(maxima.get(key, 0.), abs(residual) / 1e4)
    return dict(cases=count, gauges_c= [0, 5], missing_boundary_rejections=count*2,
                projected_stock_roundoff_rejections=sum(s==4 for s in ledger_status.values()),
                raw_storage_domain_rejections=sum(s==2 for s in domains.values()),
                max_accounting_only_normalization_theta=max_normalization,
                counterfactual_max_residual_j_cm2=maxima, **worst)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    raw = inputs()
    (out/'inputs.dat').write_bytes(raw)
    assert not subprocess.check_output(['git','diff','HEAD','--',*SOURCES],cwd=ROOT), 'persist source before qualification'
    compiler = shutil.which('gfortran')
    assert compiler, 'gfortran required'
    report = dict(scope='CURRENT_HEAT_OWNER_PLUS_EXACT_STOCK_AND_BOUNDARY_LEDGER_COMPONENT',
                  measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  input_archive_sha256=ARCHIVE_SHA, input_sha256=INPUT_SHA,
                  source_sha256={p:sha((ROOT/p).read_bytes()) for p in SOURCES},
                  source_git_blob={p:subprocess.check_output(['git','rev-parse','HEAD:'+p],cwd=ROOT,text=True).strip() for p in SOURCES},
                  compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
                  full_energy_balance_complete=False, whole_application_qualified=False, builds={})
    for opt in ('O0', 'O2'):
        build = out/opt
        build.mkdir()
        exe = build/('driver.exe' if __import__('os').name == 'nt' else 'driver')
        command = [compiler, '-'+opt, '-g', '-fcheck=all', '-ffree-line-length-none',
                   '-fbacktrace', '-J'+str(build), '-I'+str(build),
                   *[str(ROOT/p) for p in SOURCES], '-o', str(exe)]
        compiled = subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=120)
        (build/'compile.stderr').write_text(compiled.stderr,encoding='utf-8')
        assert compiled.returncode == 0, compiled.stderr
        run = subprocess.run([str(exe),str(out/'inputs.dat')],cwd=build,capture_output=True,text=True,timeout=120)
        (build/'stdout').write_text(run.stdout,encoding='utf-8')
        (build/'stderr').write_text(run.stderr,encoding='utf-8')
        assert run.returncode == 0, run.stderr
        report['builds'][opt] = dict(command=command, executable_sha256=sha(exe.read_bytes()),
                                     stdout_sha256=sha(run.stdout.encode()), **observe(run.stdout,raw))
    report['O0_O2_stdout_exact'] = (out/'O0/stdout').read_bytes() == (out/'O2/stdout').read_bytes()
    assert report['O0_O2_stdout_exact']
    rejected=report['builds']['O0']['projected_stock_roundoff_rejections']
    assert report['builds']['O2']['projected_stock_roundoff_rejections']==rejected
    report['status'] = ('DIAGNOSTIC_EVIDENCE_PASS_NUMERICAL_STOCK_CORRECTED_PHYSICAL_ENERGY_OPEN'
                        if rejected==0 else 'DIAGNOSTIC_EVIDENCE_PASS_PRODUCTION_COMPOSITION_AND_FULL_ENERGY_OPEN')
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
