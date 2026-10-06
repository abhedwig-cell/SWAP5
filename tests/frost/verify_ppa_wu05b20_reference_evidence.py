#!/usr/bin/env python3
"""Validate a complete negative/reference audit, never promote it to runtime qualification."""
import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = 'docs/audits/evidence/PPA_WU05B20_MULTILEVEL_REFERENCE_REPLAY.json.gz'
IDENTITY = 'b9722a11a7684247b90cd34e3c38e27337fbd7a9d36e43888f9893ec8bd6b368'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def validate(record):
    assert record['production_mutation'] is False
    assert record['runtime_admitted'] is False
    assert record['aggregate_frost_migration_complete'] is False
    assert record['independent_oracle_passed'] is False
    assert len(record['precision_findings']['candidate']) == 645
    assert record['independent_comparison_unit_rate_criterion'] == 2e-12
    assert record['cases_per_variant_optimization'] == 9216
    assert record['complete_source_case_attempts'] == 55296
    assert sha(record['inputs'].encode()) == record['input_sha256']
    for path, identity in record['source_sha256'].items():
        assert sha((ROOT/path).read_bytes()) == identity, path
    for variant, complete, negative in [('original',8488,728),('corrected',8488,728),('candidate',9216,0)]:
        output = record['outputs'][variant]
        assert len(output.splitlines()) == complete
        positive = {int(line.split()[0]) for line in output.splitlines()}
        assert len(positive) == complete
        negative_sets = []
        for opt in (0,2):
            key = f'{variant}/o{opt}'
            receipt = record['receipts'][key]
            assert receipt['stdout_sha256'] == sha(output.encode())
            assert receipt['completed_cases'] == complete and receipt['negative_cases'] == negative
            failed = record['failures'][key]
            assert len(failed) == negative and all(f['exit_code'] == -8 for f in failed)
            rejected = {f['case'] for f in failed}
            assert not positive & rejected
            assert positive | rejected == set(range(1,9217))
            assert sum(a['complete_rows'] for a in receipt['attempts']) == complete
            negative_sets.append(rejected)
        assert negative_sets[0] == negative_sets[1]
    assert record['affected_same_compartment_cases'] == 923
    assert record['byte_exact_unaffected_B17_controls'] == 8293
    assert record['maxima']['corrected_nodal_scalar_residual'] < 1e-14
    manifest = json.loads((ROOT/'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-03/manifest.json').read_text())
    parent = (ROOT/manifest['parent']['path']).read_bytes()
    assert sha(parent) == manifest['parent']['sha256']
    assert parent.count(manifest['patch']['old'].encode()) == 1
    candidate = parent.replace(manifest['patch']['old'].encode(),manifest['patch']['new'].encode())
    assert sha(candidate) == manifest['candidate_sha256'] == record['candidate_source_sha256']
    assert candidate.decode().replace('\r\n','\n') == record['candidate_source']
    for variant in ('original','corrected','candidate'):
        for opt in (0,2):
            receipt = record['supplements'][f'single_level/{variant}/o{opt}']
            assert receipt['exit_code'] == (0 if variant == 'candidate' else -8)
    for opt in (0,2):
        r = record['supplements'][f'B17_4536/o{opt}']
        assert r['exit_code'] == 0 and r['cases'] == 4536 and r['immutable_output_identity']
    assert record['hash_and_overwrite_guards_passed'] is True
    witness = record['witnesses']['exact_cancellation']
    assert witness['retained_raw'] == [.01,-.01]
    assert witness['final_scalar'] == [.01,-.002] and witness['final_bottom'] == -.002
    assert abs(witness['net_bottom_minus_nodal']+.01) < 1e-14
    assert set(record['witnesses']) == {'joint_distribution','exact_cancellation','below_threshold','above_threshold'}
    return {'work_unit':'PPA-WU05B20','status':'COMPLETE_REFERENCE_AUDIT_RUNTIME_OWNER_DECISION_REQUIRED',
            'cases_per_variant_optimization':9216,'original_native_failures_per_opt':728,
            'B17_native_failures_per_opt':728,'candidate_native_failures':0,
            'candidate_precision_screen_failures':645,'independent_oracle_passed':False,
            'affected_same_compartment_cases':923,'byte_exact_unaffected_B17_controls':8293,
            'B17_complete_preservation_cases_per_opt':4536,'O0_O2_identity':True,
            'maxima':record['maxima'],'witnesses':record['witnesses'],
            'production_source_tree':record['production_source_tree'],
            'candidate_reference_sha256':record['candidate_source_sha256'],
            'qualified':False,'admitted':False,'runtime_admitted':False,
            'aggregate_frost_migration_complete':False,
            'evidence':{'path':EVIDENCE,'sha256':IDENTITY,'bytes':1787077}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--summary',type=Path)
    args = ap.parse_args()
    data = (ROOT/EVIDENCE).read_bytes()
    assert sha(data) == IDENTITY
    record = json.loads(gzip.decompress(data))
    summary = validate(record)
    # Seven deliberate negative mutations must be rejected, not laundered.
    mutations = [lambda r:r.update(runtime_admitted=True),
                 lambda r:r.update(independent_oracle_passed=True),
                 lambda r:r['failures']['original/o0'].pop(),
                 lambda r:r['receipts']['candidate/o2'].update(stdout_sha256='wrong'),
                 lambda r:r['supplements']['B17_4536/o2'].update(exit_code=1),
                 lambda r:r['precision_findings'].update(candidate=[]),
                 lambda r:r.update(candidate_source_sha256='wrong')]
    for mutation in mutations:
        bad = copy.deepcopy(record);mutation(bad)
        try:
            validate(bad)
        except AssertionError:
            pass
        else:
            raise AssertionError('negative mutation accepted')
    assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip() == summary['production_source_tree']
    assert not subprocess.check_output(['git','diff','--name-only',record['baseline'],'--','src'],cwd=ROOT,text=True).strip()
    summary['evidence_verifier_negative_tests'] = len(mutations)
    if args.summary:
        args.summary.write_text(json.dumps(summary,indent=2)+'\n')
    print('B20_COMPLETE_NEGATIVE_REFERENCE_EVIDENCE=PASS_NOT_RUNTIME_QUALIFIED')
    print(json.dumps({k:v for k,v in summary.items() if k!='witnesses'},sort_keys=True))


if __name__ == '__main__':
    main()
