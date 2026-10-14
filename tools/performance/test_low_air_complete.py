#!/usr/bin/env python3
"""Negative controls for the actual complete original low-air receipt."""
import argparse, copy, hashlib, json, pathlib, shutil, tempfile
from verify_low_air_complete import verify_complete


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('qualified_candidate', type=pathlib.Path)
    args = parser.parse_args()
    origin = args.qualified_candidate.resolve()
    positive = verify_complete(origin, check_binaries=True)
    receipt = json.loads((origin / 'RESULTS.json').read_text())
    controls = []
    for name in ['partial_matrix', 'false_tenfold', 'foreign_source', 'changed_period', 'weakened_assertion', 'missing_fine', 'foreign_output']:
        with tempfile.TemporaryDirectory(prefix='low-air-full-control-') as tmp:
            folder = pathlib.Path(tmp)
            # Private text copies prevent corruption of immutable executed evidence.
            for item in origin.rglob('*'):
                if item.is_file() and item.suffix in ['.json', '.f90', '.stdout', '.stderr']:
                    target = folder / item.relative_to(origin)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(item, target)
            report = copy.deepcopy(receipt)
            run = report['runs'][0]
            driver = folder / f"o{run['optimization']}/{run['program']}.f90"
            stdout = folder / f"o{run['optimization']}-{run['program']}-family-{run['family']}.stdout"
            if name == 'partial_matrix':
                report['runs'].pop()
            elif name == 'false_tenfold':
                report['tenfold_proved'] = True
            elif name == 'foreign_source':
                report['source_tree'] = '0' * 40
            elif name in ['changed_period', 'weakened_assertion']:
                data = driver.read_text()
                token = '1.e-4_real64' if name == 'changed_period' else '1.e-6_real64'
                if token not in data:
                    raise RuntimeError('control must mutate actual scientific recipe')
                driver.write_text(data.replace(token, '9.0e-4_real64', 1))
                run['recipe_sha256'] = hashlib.sha256(driver.read_bytes()).hexdigest()
            elif name == 'missing_fine':
                stdout.write_text(stdout.read_text().replace('FINE_COMPARISON', 'REMOVED_COMPARISON', 1))
                run['stdout_sha256'] = hashlib.sha256(stdout.read_bytes()).hexdigest()
            else:
                stdout.write_text(stdout.read_text() + 'foreign evidence\n')
            (folder / 'RESULTS.json').write_text(json.dumps(report))
            try:
                verify_complete(folder)
            except ValueError as error:
                controls.append({'mutation': name, 'rejected': True, 'reason': str(error)})
            else:
                raise AssertionError('accepted invalid complete receipt: ' + name)
    print(json.dumps({'positive': positive, 'controls': controls, 'result': 'PASS'}, indent=2))

if __name__ == '__main__':
    main()
