"""Actual ordinary policy/source refusals before worker startup or publication."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT/'tests/nomacro_scheduled_subsurface'), str(ROOT/'tests/nomacro_mixtures')]
import implicit_conductivity_runtime as runtime
from ordinary_implicit_pond_tangent import BODY

m = runtime.m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('profile', 'reference-work', 'other-head', 'output'):
        parser.add_argument('--'+key, type=Path, required=True)
    args = parser.parse_args()
    report = json.loads((args.profile/'RESULT.json').read_text(encoding='utf-8'))
    original = Path(report['build_root'])
    project = m.e.load(Path(report['input_root']), original_output=True)
    meta, _ = m.validate_bundle(original, args.reference_work, project)
    original_sha = m.sha(original/'BUILD.json')
    args.output.mkdir()
    result = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'],
        cwd=ROOT, text=True).strip(), actual_build_sha256=original_sha,
        model_executions=0, compilations=0, refusals=[])
    def save():
        (args.output/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    save()
    policy = meta['identity']['ordinary_implicit_pond_switch']
    attacks = [('policy-'+key, key) for key in policy]
    attacks += [(key, None) for key in ('top-deadband', 'top-missing-chain', 'top-inexact-root',
                                       'top-unrelated', 'head-double-chain', 'head-unrelated', 'head-wrong-form')]
    for label, field in attacks:
        target = args.output/label
        target.mkdir()
        for path in original.iterdir():
            if path.name == 'BUILD.json' or path.suffix.lower() in ('.f90', '.dll', '.so'):
                shutil.copyfile(path, target/path.name)
        bad = copy.deepcopy(meta)
        if field is not None:
            for identity in (bad['identity'], bad['binding']['build']):
                identity['ordinary_implicit_pond_switch'][field] = 'foreign'
            expected = 'Foreign ordinary implicit positive-pond reference policy'
        else:
            name = 'boundtop.f90' if label.startswith('top-') else 'headcalc.f90'
            path = target/name
            text = path.read_text(encoding='cp1252')
            if label == 'top-deadband':
                old = '      if (h0 <= 0.0d0) then'
                assert text.count(old) == 1
                text = text.replace(old, '      if (h0 <= 1.0d-6) then', 1)
                expected = 'Foreign actual ordinary implicit positive-pond switch'
            elif label == 'top-missing-chain':
                assert text.count(BODY) == 1
                text = text.replace(BODY, '', 1)
                expected = 'Foreign actual ordinary implicit pond root/derivative provider'
            elif label == 'top-inexact-root':
                old = 'do iteration=1,128'
                assert text.count(old) == 1
                text = text.replace(old, 'do iteration=1,64', 1)
                expected = 'Foreign actual ordinary implicit pond root/derivative provider'
            elif label == 'top-unrelated':
                text += '\n! actual foreign original top source\n'
                expected = 'Foreign complete original ordinary implicit top source'
            elif label == 'head-double-chain':
                old = 'dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)'
                assert text.count(old) == 1
                text = text.replace(old, old+'*2d0', 1)
                expected = 'Foreign actual ordinary implicit coupled HeadCalc provider'
            elif label == 'head-wrong-form':
                other = args.other_head.read_text(encoding='cp1252')
                assert other != text
                text = other
                expected = 'Foreign actual ordinary implicit coupled HeadCalc provider'
            else:
                text += '\n! actual foreign original HeadCalc source\n'
                expected = 'Foreign actual ordinary implicit coupled HeadCalc provider'
            path.write_text(text, encoding='cp1252')
            # Do not rely on the mutable source inventory alone: make it agree
            # with the changed file, then require the independent source guard.
            for identity in (bad['identity'], bad['binding']['build']):
                identity['donor_generated'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        (target/'BUILD.json').write_text(json.dumps(bad, indent=2)+'\n', encoding='utf-8')
        try:
            m.validate_bundle(target, args.reference_work, project)
        except ValueError as error:
            assert expected in str(error), (label, str(error))
            assert not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
            result['refusals'].append(dict(field=label, expected=expected, actual=str(error),
                before_worker=True, no_publication=True))
        else:
            raise AssertionError('Foreign actual ordinary source/policy accepted: '+label)
        save()
    assert m.sha(original/'BUILD.json') == original_sha
    result.update(status='ACTUAL_ORDINARY_SOURCE_AND_POLICY_REFUSALS_BEFORE_WORKER_PASS',
                  actual_refusals=len(result['refusals']), original_BUILD_unchanged=True)
    save()
    print(result['status'], result['actual_refusals'])


if __name__ == '__main__':
    main()
