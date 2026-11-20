"""Select publication replay only when its actual dependency surface changed."""
import os
from pathlib import Path


def unchanged():
    import frost_drainage_verify as frost
    frost.guard_previous_source()
    # These complete trees include every publication program, parameter,
    # preregistration and compiled source. Their actual canonical bytes survive.
    if frost.git('diff', frost.PARENT, 'HEAD', '--', 'src', 'tests/publication',
                 'docs/publication', 'docs/publications', 'docs/verification',
                 'docs/performance/evidence', 'tools/vq', 'tests/fsi/fsi04_real_headcalc_stubs.f90'):
        return False
    paths = frost.git('diff', '--no-renames', '--name-status', frost.PARENT, 'HEAD', '--', 'reference').decode().splitlines()
    expected = {'reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-OVERLAP-01/' + n
                for n in ('README.md', 'divdra.f90', 'manifest.json')}
    if set(paths) != {'A\t' + p for p in expected}:
        return False
    return all(frost.blob('HEAD', p) == frost.blob(frost.RUNTIME, p) for p in expected)


if __name__ == '__main__':
    replay = True
    if os.environ.get('GITHUB_EVENT_NAME') == 'pull_request':
        try:
            replay = not unchanged()
        except Exception as error:
            print('PUBLICATION_SCOPE_REQUIRES_REPLAY', repr(error))
    print('PUBLICATION_REPLAY_SELECTED=' + str(replay).lower())
    if not replay:
        print('UNCHANGED_ACTUAL_CANONICAL_PUBLICATION_DEPENDENCIES; NO_FRESH_PUBLICATION_SCIENCE_CLAIM')
    if os.environ.get('GITHUB_OUTPUT'):
        with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as stream:
            stream.write('replay=' + str(replay).lower() + '\n')
