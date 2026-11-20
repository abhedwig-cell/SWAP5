"""Seal actual secondary observations once, retaining failed control attempts."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from weather_surface_seal import archive, sha


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('evidence', 'output', 'provider', 'work'):
        p.add_argument('--'+key, type=Path, required=True)
    a = p.parse_args()
    for opt in ('O0', 'O2'):
        directories, builds, profiles = [], {}, {}

        def add(prefix, root, include=True):
            q = json.loads((root/'RESULT.json').read_text())
            build = Path(q['build_root'])
            digest = sha((build/'BUILD.json').read_bytes())
            assert q['status'] == 'ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS'
            assert digest == q['trajectory']['build_sha256']
            if build not in builds:
                builds[build] = prefix+'-build'
            profiles[prefix] = dict(actual_build_prefix=builds[build],
                                    actual_build_sha256=digest, producer_source=q['source'],
                                    actual_profile_root=str(root))
            if include:
                directories.append((prefix, root))

        for case, prefix in [('water', 'full-water'), ('fixed', 'full-cde')]:
            add(prefix, a.evidence/f'secondary-pond-full-{case}-{opt}-v1')
        batch = a.evidence/f'SECONDARY_SHORT_ACTUAL_COMPOSITION_{opt}_V1.json'
        selected = json.loads(batch.read_text())
        assert selected['actual_contexts'] == 9 and selected['actual_native_cold_windows'] == 27
        directories += [('short-original', a.evidence/f'secondary-pond-short-{opt}-v1'),
                        ('short-recovered', a.evidence/f'secondary-pond-short-recovered-{opt}-v1')]
        for label, name in sorted(selected['profiles'].items()):
            root = Path(name)
            parent = 'short-recovered' if root.parent.name.startswith('secondary-pond-short-recovered-') else 'short-original'
            add(parent+'/'+label, root, False)
        for kind in ('water', 'cde'):
            add('primary-'+kind, a.evidence/f'secondary-primary-postimage-{kind}-{opt}-v1')
        case = 'water' if opt == 'O0' else 'automatic'
        add('explicit-off', a.evidence/f'secondary-explicit-off-{case}-{opt}-v1')
        directories.append(('components', a.evidence/f'secondary-pond-component-{opt}-v1'))
        for s, h in ((0, 0), (1, 2)):
            directories.append((f'ordinary-current-s{s}-h{h}',
                                a.evidence/f'secondary-ordinary-current-s{s}-h{h}-{opt}-v1'))
        index = a.evidence/f'SECONDARY_{opt}_ACTUAL_COMPILED_ALIASES_V1.json'
        assert not index.exists()
        index.write_text(json.dumps(dict(status='ACTUAL_SECONDARY_SOURCE_BUILD_CUSTODY_WITH_UNCHANGED_REUSE',
                                         profiles=profiles), indent=2)+'\n')
        files = [('ACTUAL_COMPILED_ALIASES.json', index), ('SHORT_ACTUAL_COMPOSITION.json', batch),
                 ('UNSELECTED_POSTIMAGES.json', a.evidence/'SECONDARY_UNSELECTED_ACTUAL_POSTIMAGES_V1.json')]
        q = archive(a.output, f'EXTENDED_DRAINAGE_SECONDARY_POND_WINDOWS_{opt}_RAW_ARCHIVE',
                    directories, files, [(prefix, root) for root, prefix in builds.items()])
        print(opt, q['bytes'], q['sha256'], flush=True)
    files = [('provider-PREPARED.json', a.provider/'PREPARED.json'),
             ('numeric-controller.tar', a.evidence/'SECONDARY_NUMERIC_CONTROLLER_V1.tar'),
             ('current-controller.tar', a.evidence/'SECONDARY_CURRENT_CONTROLLER_V1.tar')]
    for opt in ('O0', 'O2'):
        files += [(f'full-{opt}-job.log', a.evidence/f'SECONDARY_FULL_UBUNTU_{opt}_JOB.log'),
                  (f'full-{opt}-independent.json', a.evidence/f'SECONDARY_FULL_UBUNTU_{opt}_INDEPENDENT_AUDIT_V1.json')]
    q = archive(a.output, 'EXTENDED_DRAINAGE_SECONDARY_POND_WINDOWS_SOURCE_RAW_ARCHIVE',
                [('source-numeric', a.evidence/'secondary-pond-windows-source-v1'),
                 ('source-current', a.evidence/'secondary-pond-windows-source-v2'),
                 ('scope', a.evidence/'secondary-pond-public-scope-v1')], files)
    print('SOURCE', q['bytes'], q['sha256'], flush=True)
    names = ['implicit-secondary-replay280-O0-v1', 'implicit-secondary-replay280-O2-v1',
             'implicit-secondary-nodal-O0-v1', 'implicit-secondary-backtracking-O0-v1',
             'implicit-secondary-zero-pond-O0-v1', 'implicit-secondary-zero-pond-O0-v2',
             'implicit-secondary-zero-pond-O2-v1', 'implicit-secondary-pond-switch-observation-O0-v1',
             'implicit-secondary-zero-pond-seasonal-O0-v1',
             'implicit-secondary-zero-pond-seasonal-O0-v2',
             'implicit-secondary-zero-pond-seasonal-O2-v2',
             'implicit-secondary-zero-pond-tail-O0-v1']
    names += [f'implicit-secondary-pond-switch-component-{opt}-{variant}-v1'
              for opt in ('O0', 'O2') for variant in ('original', 'zero')]
    files = [(p.name, p) for p in sorted((a.work/'implicit-secondary-diagnostic-v1').glob('*.py'))]
    files += [(p.name, p) for p in sorted((a.work/'implicit-secondary-diagnostic-v1').glob('*.f90'))]
    files += [(n, a.evidence/n) for n in ('IMPLICIT_SECONDARY_REFERENCE_SWITCH_RESEARCH_V1.json',
                                        'IMPLICIT_SECONDARY_POND_SWITCH_COMPONENT_AUDIT_V1.json')]
    files += [('launchers/'+p.name, p) for pattern in ('run-secondary-*.py', 'resume-secondary-*.py')
              for p in sorted(a.work.glob(pattern))]
    q = archive(a.output, 'EXTENDED_DRAINAGE_SECONDARY_POND_DIAGNOSTICS_RAW_ARCHIVE',
                [(n, a.evidence/n) for n in names], files)
    print('DIAGNOSTICS', q['bytes'], q['sha256'], flush=True)


if __name__ == '__main__':
    main()
