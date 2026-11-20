"""Independent secondary raw/source/archive observations, without model execution."""
import argparse
import json
from pathlib import Path
import zipfile

import implicit_evidence as prior
import secondary_pond_forensics as science
from calendar_evidence import capsule, differences, extracted
from calendar_publisher import publisher_equivalence
from extended_forensics import require

PREFIX = 'EXTENDED_DRAINAGE_SECONDARY_POND_'


def source_binding(build, cap, provider):
    prior.source_binding(build, cap, provider)
    extended = build['identity']['extended_drainage']
    require(extended['zero_pond_switch_renderer_sha256'] ==
            cap['members']['app/hybrid_water/extended_implicit_pond_switch.py']['sha256'] and
            extended['original_positive_head_deadband_preserved'] is False,
            'Actual secondary reference-correction source binding differs')


def period(root, z, prefix, bp, opt, days, cap, provider, proof):
    directory = root/prefix
    q = json.loads((directory/'RESULT.json').read_text())
    build = json.loads((root/bp/'BUILD.json').read_text())
    require(q['parameters']['days'] == days and q['parameters']['optimization'] == opt and
            q['functional_completion'] == 'PARTIAL' and q['whole_scientific_equivalence'] ==
            'NOT_QUALIFIED' and q['public_admission'] is False,
            'Actual secondary period/optimization/authority differs')
    prior.compiled(z, bp+'/', build, opt)
    source_binding(build, cap, provider)
    prior.corrected_source(proof, opt, root/bp)
    report = science.audit_root(directory, root/bp)
    rows = prior.prior.lines((directory/'trajectory/daily.jsonl').read_bytes())
    return report, build, rows


def source_controls(root, prefix, build, bp):
    directory = root/prefix/'source-controls'
    q = json.loads((directory/'RESULT.json').read_text())
    require(q['status'] == 'ACTUAL_FIVE_SECONDARY_SOURCE_AND_POLICY_REFUSALS_BEFORE_WORKER_PASS' and
            q['actual_build_sha256'] == prior.prior.digest((root/bp/'BUILD.json').read_bytes()),
            'Actual secondary source-control bundle or completion differs')
    fields = {'zero_pond_switch_renderer_sha256', 'zero_pond_reference_correction',
              'original_positive_head_deadband_preserved', 'actual-boundtop-deadband',
              'actual-boundtop-unrelated'}
    require({v['field'] for v in q['refusals']} == fields and len(q['refusals']) == 5,
            'Actual secondary source-control denominator differs')
    for item in q['refusals']:
        target = directory/item['field']
        require(item['before_worker'] is True and item['no_publication'] is True and
                item['expected'] in item['error'] and not list(target.rglob('donor.stdout')) and
                not list(target.rglob('accepted-*.zip')), 'Foreign source entered worker/publication')
        actual = json.loads((target/'BUILD.json').read_text())
        field = item['field']
        if field.startswith('actual-boundtop'):
            require(actual == build, 'Actual source mutant rebound its build')
            original = (root/bp/'boundtop.f90').read_text(encoding='cp1252')
            expected = (original.replace('if (h0 <= 0.0d0) then', 'if (h0 <= 1.0d-6) then', 1)
                        if field.endswith('deadband') else
                        original+'\n! deliberately foreign actual boundary source\n')
            require((target/'boundtop.f90').read_text(encoding='cp1252') == expected,
                    'Actual foreign boundary payload differs')
            try:
                science.boundtop((target/'boundtop.f90').read_bytes(),
                                  bool(build['identity']['original_output'].get('swhyst')))
            except ValueError:
                pass
            else:
                raise ValueError('Independent observer accepted foreign boundary source')
        else:
            require(set(differences(build, actual)) ==
                    {'identity.extended_drainage.'+field, 'binding.build.extended_drainage.'+field} and
                    actual['identity']['extended_drainage'][field] ==
                    actual['binding']['build']['extended_drainage'][field] == 'foreign',
                    'Actual policy mutation changed its declared context')
    return dict(actual_before_worker_source_policy_refusals=5)


def scope(root):
    directory = root/'scope'
    q = json.loads((directory/'RESULT.json').read_text())
    require(q['status'] == 'ACTUAL_FIVE_CURRENT_SECONDARY_PUBLIC_EXCLUSIONS_REFUSED_BEFORE_COMPILER_WORKER_PUBLICATION'
            and q['accepted_origin_unchanged'] is True, 'Current public exclusions incomplete')
    require({v['label'] for v in q['controls']} ==
            {'compatibility', 'AGE', 'history3', 'primary-mode1', 'examined-Ksat'} and
            len(q['controls']) == 5, 'Current public exclusion denominator differs')
    for item in q['controls']:
        target = directory/item['label']
        require(item['returncode'] == 2 and item['no_compiler_source_or_executable'] is True and
                item['no_worker_or_publication'] is True and item['expected_refusal'] in
                (target/'actual.stderr').read_text(), 'Excluded public input reached compilation/worker')
        observed = {str(p.relative_to(target/'input')).replace('\\', '/'):
                    prior.prior.digest(p.read_bytes()) for p in (target/'input').rglob('*') if p.is_file()}
        require(observed == item['input_sha256'], 'Actual scope-refusal input bytes differ')
    return dict(actual_before_compiler_scope_refusals=5)


def windows(path, opt):
    proof = path.parent
    with extracted(proof/(PREFIX+'WINDOWS_SOURCE_RAW_ARCHIVE.zip')) as (sources, _):
        numeric = capsule(sources, 'source-numeric')
        current = capsule(sources, 'source-current')
        provider = json.loads((sources/'provider-PREPARED.json').read_text())
        scope_report = scope(sources)
    reports = {}
    with extracted(path) as (root, z):
        aliases = json.loads(z.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
        selection = json.loads(z.read('SHORT_ACTUAL_COMPOSITION.json'))
        require(selection['actual_contexts'] == 9 and selection['actual_native_cold_windows'] == 27,
                'Actual consolidated secondary short selection differs')
        for prefix, item in aliases.items():
            q = json.loads(z.read(prefix+'/RESULT.json'))
            require(prior.prior.digest(z.read(item['actual_build_prefix']+'/BUILD.json')) ==
                    item['actual_build_sha256'] == q['trajectory']['build_sha256'] and
                    item['producer_source'] == q['source'], 'Actual secondary source/build phase rebound')
        for prefix in ('full-water', 'full-cde'):
            bp = aliases[prefix]['actual_build_prefix']
            report, build, rows = period(root, z, prefix, bp, opt, 1096, numeric, provider, proof)
            report['controls'] = prior.controls(root, prefix, build, rows, current, compiled_prefix=bp)
            report['source-controls'] = source_controls(root, prefix, build, bp)
            reports[prefix] = report
        expected = {f'{mode}-{case}-h{h}' for mode, case, h in
                    [('automatic', c, h) for c in ('water', 'fixed') for h in (0, 1, 2)] +
                    [('prescribed', 'water', 0), ('prescribed', 'fixed', 0), ('prescribed', 'fixed', 2)]}
        require(set(selection['profiles']) == expected, 'Secondary interaction domains differ')
        expected_aliases = {'full-water', 'full-cde', 'primary-water', 'primary-cde', 'explicit-off'}
        expected_aliases |= {('short-recovered/' if 'short-recovered-' in name else 'short-original/')+label
                             for label, name in selection['profiles'].items()}
        require(set(aliases) == expected_aliases and len(aliases) == 14,
                'Actual selected secondary compiler inventory differs')
        for label, original_path in sorted(selection['profiles'].items()):
            prefix = ('short-recovered/' if 'short-recovered-' in original_path else 'short-original/')+label
            bp = aliases[prefix]['actual_build_prefix']
            report, build, _ = period(root, z, prefix, bp, opt, 35, current, provider, proof)
            require(build['identity']['extended_drainage']['domain'][4] ==
                    (1 if label.startswith('prescribed-') else 2) and
                    build['identity']['original_output'].get('swhyst', 0) == int(label[-1]),
                    'Actual secondary level/history selection differs')
            reports[prefix] = report
        original = json.loads(z.read('short-original/RESULT.json'))
        recovered = json.loads(z.read('short-recovered/RESULT.json'))
        require(original['status'] == 'FAILED' and recovered['status'] ==
                'ACTUAL_MISSING_SECONDARY_HISTORY_CONTEXTS_RECOVERED_WITH_UNCHANGED_BUILDS_PASS' and
                len(original['failures']) == (2 if opt == 'O0' else 1),
                'Original before-worker guard refusals/recovery were relabelled')
        for item in original['failures']:
            prefix = 'short-original/'+item['label']
            q = json.loads(z.read(prefix+'/RESULT.json'))
            require(q['status'] == 'FAILED' and 'Foreign actual secondary implicit zero-pond boundary provider'
                    in z.read('short-original/'+item['label']+'-producer.stderr').decode() and
                    prefix+'/trajectory/daily.jsonl' not in z.namelist(),
                    'Initial source guard failure ran a model or changed cause')
        reports['components'] = science.component(root/'components')
        with extracted(proof/f'EXTENDED_DRAINAGE_IMPLICIT_WINDOWS_{opt}_RAW_ARCHIVE.zip') as (oldroot, old):
            oldaliases = json.loads(old.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
            before = oldaliases['full-water']['actual_build_prefix']
            reports['primary-water'] = prior.current_postimage(root/'primary-water', oldroot/'full-water',
                root/aliases['primary-water']['actual_build_prefix'], oldroot/before)
            prefix = 'explicit-off';bp = aliases[prefix]['actual_build_prefix']
            build = json.loads(z.read(bp+'/BUILD.json'));prior.prior.build_files(z, bp+'/', build)
            before = oldaliases['final-off']['actual_build_prefix']
            oldbuild = json.loads(old.read(before+'/BUILD.json'))
            require({p.name: p.read_bytes() for p in (root/bp).glob('*.f90')} ==
                    {p.name: p.read_bytes() for p in (oldroot/before).glob('*.f90')} and
                    build['inputs'] == oldbuild['inputs'] and build['project'] == oldbuild['project'],
                    'Actual explicit-off input/Fortran changed')
            require(set(differences(oldbuild['identity'], build['identity'])) <=
                    {'extended_drainage.source_sha256', 'restart_publisher.library_sha256'},
                    'Explicit-off physical/compiler identity changed')
            if build['identity']['restart_publisher']['library_sha256'] != oldbuild['identity']['restart_publisher']['library_sha256']:
                publisher_equivalence(oldroot/before/'restart_publish.dll', root/bp/'restart_publish.dll')
            require(prior.prior.physical(prior.prior.lines(z.read(prefix+'/trajectory/daily.jsonl'))) ==
                    prior.prior.physical(prior.prior.lines(old.read('final-off/trajectory/daily.jsonl'))),
                    'Actual explicit-off physical continuation changed')
            for day in (2, 4):
                require(prior.prior.package(z.read(prefix+f'/trajectory/accepted-column-1-day-{day}.zip'))[1] ==
                        prior.prior.package(old.read(f'final-off/trajectory/accepted-column-1-day-{day}.zip'))[1],
                        'Actual explicit-off complete native changed')
            import calendar_forensics, history_forensics
            reports['explicit-off'] = (history_forensics if opt == 'O2' else calendar_forensics).audit_root(root/prefix, root/bp)
        with extracted(proof/f'EXTENDED_DRAINAGE_IMPLICIT_CORRECTED_WINDOWS_{opt}_RAW_ARCHIVE.zip') as (oldroot, old):
            before = json.loads(old.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']['full-cde-h2']['actual_build_prefix']
            reports['primary-cde'] = prior.current_postimage(root/'primary-cde', oldroot/'full-cde-h2',
                root/aliases['primary-cde']['actual_build_prefix'], oldroot/before)
        with zipfile.ZipFile(proof/f'EXTENDED_DRAINAGE_IMPLICIT_PRECORRECTION_WINDOWS_{opt}_RAW_ARCHIVE.zip') as old:
            oldaliases = json.loads(old.read('ACTUAL_COMPILED_ALIASES.json'))['profiles']
            for s, h in ((0, 0), (1, 2)):
                prefix = f'ordinary-current-s{s}-h{h}'
                reports[prefix] = prior.ordinary_current(root, prefix, old, f'ordinary-s{s}-h{h}', oldaliases)
    reports['scope'] = scope_report
    return reports


def ubuntu_full(path, opt):
    record = json.loads(path.with_suffix('.json').read_text())
    require(record['repacked'] is False and record['actual_job_conclusion'] == 'failure',
            'Original full Ubuntu job was repacked or relabelled')
    reports = {}
    with extracted(path) as (root, z):
        cap = capsule(root)
        provider = json.loads((root/'provider-PREPARED.json').read_text())
        for prefix in ('water', 'cde'):
            report, build, rows = period(root, z, prefix, prefix+'-build', opt, 1096,
                                         cap, provider, path.parent)
            if prefix == 'water':
                report['controls'] = prior.controls(root, prefix, build, rows, cap)
            reports[prefix] = report
    return reports


def ubuntu_current(path, opt):
    record = json.loads(path.with_suffix('.json').read_text())
    require(record['repacked'] is False and record['actual_job_conclusion'] == 'success',
            'Current portable postimage job incomplete/repacked')
    reports = {}
    with extracted(path) as (root, z), extracted(path.with_name(PREFIX+f'FULL_UBUNTU_{opt}_RAW_ARCHIVE.zip')) as (full, _):
        cap = capsule(root)
        provider = json.loads((root/'provider-PREPARED.json').read_text())
        for prefix in ('water', 'cde'):
            report, build, rows = period(root, z, prefix, prefix+'-build', opt, 35, cap, provider, path.parent)
            report['controls'] = prior.controls(root, prefix, build, rows, cap)
            report['current-full-postimage'] = prior.current_postimage(root/prefix, full/prefix,
                root/(prefix+'-build'), full/(prefix+'-build'))
            reports[prefix] = report
        reports['source-controls'] = source_controls(root, 'water',
            json.loads(z.read('water-build/BUILD.json')), 'water-build')
        reports['components'] = science.component(root/'components')
        for label, oldname, oldprefix in [('primary-water', f'EXTENDED_DRAINAGE_IMPLICIT_UBUNTU_{opt}_RAW_ARCHIVE.zip', 'water'),
                ('primary-cde', f'EXTENDED_DRAINAGE_IMPLICIT_CORRECTED_UBUNTU_{opt}_RAW_ARCHIVE.zip', 'cde')]:
            with extracted(path.with_name(oldname)) as (old, _):
                reports[label] = prior.current_postimage(root/label, old/oldprefix,
                    root/(label+'-build'), old/(oldprefix+'-build'))
    return reports


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    parser.add_argument('--phase', choices=('windows', 'ubuntu-full', 'ubuntu-current'), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    callback = {'windows': windows, 'ubuntu-full': ubuntu_full, 'ubuntu-current': ubuntu_current}[args.phase]
    result = callback(args.archive, args.optimization)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(dict(status='INDEPENDENT_SECONDARY_POND_SOURCE_RAW_ARCHIVE_PASS', metrics=result), stream, indent=2)
    print('INDEPENDENT_SECONDARY_POND_SOURCE_RAW_ARCHIVE_PASS', args.phase, args.optimization)
