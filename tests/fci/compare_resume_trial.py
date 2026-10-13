#!/usr/bin/env python3
"""Compare all original output bytes, normalizing only audited private paths."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def normalize(data):
    result = []
    paths = []
    for number, line in enumerate(data.splitlines(keepends=True), 1):
        if line.startswith(b'FCI_RESUME_'):
            continue  # selector metadata; original scientific text stays intact
        changed = re.sub(
            rb'^(BUILD=/tmp/ppa-wu05b19-low-air-runtime-crop-owner-)[A-Za-z0-9]+(\r?\n)?$',
            rb'\1<PRIVATE_NONCE>\2', line)
        changed = re.sub(
            rb'^(F_ROM0_BUILD_EXECUTABLE=/tmp/swap5-irr-storage-preservation-local-)[0-9]+(/(?:dynamic_top_correction|frozen_wet_trajectory|fsi25_reference_indicator_production_seam|fsi39_b110_ksatexm)-o[02]/rom0_test)(\r?\n)?$',
            rb'\1<PRIVATE_PID>\2\3', changed)
        if changed != line:
            paths.append({'line': number, 'original': line.decode().rstrip(),
                          'normalized': changed.decode().rstrip()})
        result.append(changed)
    return b''.join(result), paths


def compare(directory):
    directory = Path(directory)
    baseline, left_paths = normalize((directory / 'baseline.stdout').read_bytes())
    resumed, right_paths = normalize((directory / 'resumed.stdout').read_bytes())
    controls = {name: json.loads((directory / (name + '.control.json')).read_text())
                for name in ['baseline', 'resumed']}
    valid = all(c['terminal_status'] == 'PASS' and c['terminal_exit_code'] == 0
                for c in controls.values())
    valid = valid and controls['baseline']['executed_head'] == controls['resumed']['executed_head']
    inherited = [line.decode().split()[-1] for line in
                 (directory / 'resumed.stdout').read_bytes().splitlines()
                 if line.startswith(b'FCI_RESUME_INHERITED ')]
    result = {'schema': 'swap5.fci.resume-comparison.v1',
              'exact_scientific_output_after_private_path_normalization': baseline == resumed,
              'controls_valid_same_candidate': valid,
              'inherited_groups': inherited,
              'original_full_stdout_byte_identical':
                  (directory / 'baseline.stdout').read_bytes() == (directory / 'resumed.stdout').read_bytes(),
              'baseline_normalized_sha256': hashlib.sha256(baseline).hexdigest(),
              'resumed_normalized_sha256': hashlib.sha256(resumed).hexdigest(),
              'normalized_baseline_paths': left_paths, 'normalized_resumed_paths': right_paths,
              'numerical_values_or_tolerances_normalized': False,
              'qualification_pass': valid and baseline == resumed and
                  inherited == ['frost-invalid', 'frost-independent']}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path, nargs='?')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        original = (b'MASS=1.0000000000000E-12\n'
                    b'F_ROM0_BUILD_EXECUTABLE=/tmp/swap5-irr-storage-preservation-local-123/dynamic_top_correction-o0/rom0_test\n')
        reference, _ = normalize(original)
        same, _ = normalize(original.replace(b'-123/', b'-456/'))
        if reference != same:
            raise SystemExit('private PID control failed')
        for before, after in [(b'1.0000000000000E-12', b'2.0000000000000E-12'),
                              (b'-o0/', b'-o2/'),
                              (b'dynamic_top_correction', b'fsi39_b110_ksatexm')]:
            changed, _ = normalize(original.replace(before, after))
            if reference == changed:
                raise SystemExit('scientific mutation incorrectly normalized')
        print('COMPARISON_REJECTS_NUMERICAL_OPT_AND_CASE_MUTATION=PASS')
        if args.directory is None:
            raise SystemExit(0)
    if args.directory is None:
        parser.error('directory required unless --self-test')
    result = compare(args.directory)
    (args.directory / 'adjudicated-comparison.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['qualification_pass'] else 1)
