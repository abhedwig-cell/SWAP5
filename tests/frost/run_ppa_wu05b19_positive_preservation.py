#!/usr/bin/env python3
"""Complete unchanged positive DIVDRA process/binding smoke programs, not fixed-base admission gates."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument('--record', required=True)
args = ap.parse_args()
baseline = 'ca856e88e582d468a6f40971ce1f2a75e5089c40'
common = ['src/solver/mod_soil_water_solver_contract.f90', 'src/solver/mod_process_hydraulic_view.f90', 'src/process/mod_drainage_spatial_distribution.f90']
binding = ['src/runtime/mod_fmr_divdra_runtime_binding.f90', 'src/solver/mod_b110_source_sink_provider.f90']
programs = {32: common + ['tests/fci/fci32_divdra_admission_smoke.f90'], 33: common + binding + ['tests/fci/fci33_divdra_runtime_admission_smoke.f90']}
files = list(dict.fromkeys(f for sources in programs.values() for f in sources))
for relative in files:
    assert subprocess.check_output(['git', 'show', baseline + ':' + relative], cwd=ROOT) == (ROOT / relative).read_bytes(), relative
build = Path(tempfile.mkdtemp(prefix='ppa-wu05b19-positive-preservation-'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
outputs = {}
for number, sources in programs.items():
    for optimization in (0, 2):
        out = build / f'fci{number}' / f'o{optimization}'
        out.mkdir(parents=True)
        subprocess.run(['gfortran', '-std=f2008', '-ffree-line-length-none', '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', f'-O{optimization}', '-J', str(out), '-I', str(out), *[str(ROOT / p) for p in sources], '-o', str(out / 'test')], check=True)
        with (out / 'output.txt').open('w') as stdout:
            subprocess.run([str(out / 'test')], stdout=stdout, check=True)
        marker = 'FCI32_DIVDRA_ADMISSION_SMOKE=PASS' if number == 32 else 'FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS'
        assert marker in (out / 'output.txt').read_text()
        outputs[f'fci{number}/o{optimization}'] = {'stdout_sha256': sha(out / 'output.txt'), 'executable_sha256': sha(out / 'test'), 'exit_code': 0}
    assert (build / f'fci{number}/o0/output.txt').read_bytes() == (build / f'fci{number}/o2/output.txt').read_bytes()
    print(f'B19_COMPLETE_UNCHANGED_POSITIVE_FCI{number}_O0_O2=PASS', flush=True)
result = {'work_unit': 'PPA-WU05B19', 'status': 'COMPLETE_POSITIVE_PROCESS_BINDING_PRESERVATION_NOT_FIXED_BASE_ADMISSION', 'build': str(build), 'source_sha256': {f: sha(ROOT / f) for f in files}, 'outputs': outputs, 'O0_O2_byte_identity': True}
Path(args.record).write_text(json.dumps(result, indent=2) + '\n')
