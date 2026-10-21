"""Fresh small original/candidate surface closure, independent of column objects."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--candidate',type=Path,required=True)
    ap.add_argument('--compiler-manifest',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--mass',action='store_true',help='Three-source exact empty-pond mass limit and actual original failure')
    a = ap.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    stage = out / 'source'
    stage.mkdir()
    (stage / 'src').symlink_to(ROOT / 'src',target_is_directory=True)
    (stage / 'tests').symlink_to(ROOT / 'tests',target_is_directory=True)
    (stage / 'generated').mkdir()
    alias = stage / 'generated/candidate.f90'
    text = a.candidate.read_text()
    original = 'mod_b111_pond_solute_exchange' if a.mass else 'mod_b110_dynamic_top_boundary_provider'
    replacement = 'mod_perf01_candidate_pond_solute_exchange' if a.mass else 'mod_perf01_candidate_surface_boundary'
    assert text.startswith('module ' + original + '\n') and text.count(original) in {1,2}
    alias.write_text(text.replace(original,replacement))
    spec = importlib.util.spec_from_file_location('closure',ROOT / 'tests/support/augment_bartholomeus_backend_sources.py')
    closure = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(closure)
    fixture = 'tests/performance/test_perf01_empty_pond_mass.f90' if a.mass else 'tests/performance/test_perf01_empty_pond_replay.f90'
    sources,_ = closure.strict_closure(stage,[fixture],extra_sources=[fixture,'generated/candidate.f90'])
    fc = json.loads(a.compiler_manifest.read_text())['compiler_command']
    report = dict(candidate_sha256=sha(a.candidate),provider_count=len(sources),
                  source_sha256={str(p.relative_to(stage)):sha(p) for p in sources},events=[],runs={})
    for opt in ['O0','O2']:
        b = out / opt
        b.mkdir()
        flags = ['-' + opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',
                 '-J' + str(b),'-I' + str(b)]
        exe = b / 'test'
        for command in [fc + flags + list(map(str,sources)) + ['-o',str(exe)],[str(exe)]]:
            start = time.monotonic()
            p = subprocess.run(command,cwd=b,capture_output=True)
            i = len(report['events'])
            for stream in ['stdout','stderr']:
                (out / f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
            report['events'].append(dict(command=command,returncode=p.returncode,seconds=time.monotonic()-start))
            (out / 'RESULT.json').write_text(json.dumps(report,indent=2) + '\n')
            p.check_returncode()
        report['runs'][opt] = p.stdout.decode()
        marker = 'EMPTY_POND_EXACT_MASS_LIMIT_AND_INCUMBENT_NEGATIVE_ROUNDOFF_PASS' if a.mass else 'EMPTY_POND_CONSERVATION_BOUNDS_SPLIT_SOURCE_CONTINUITY_PASS=45'
        assert marker in report['runs'][opt]
    assert report['runs']['O0'] == report['runs']['O2']
    assert all(sha(stage / p) == h for p,h in report['source_sha256'].items())
    report['status'] = 'FRESH_SMALL_ORIGINAL_COUNTEREXAMPLE_AND_CANDIDATE_SURFACE_CONSTRAINT_PASS'
    (out / 'RESULT.json').write_text(json.dumps(report,indent=2) + '\n')
    print(json.dumps(dict(status=report['status'],providers=report['provider_count'],runs=report['runs'])))


if __name__ == '__main__':
    main()
