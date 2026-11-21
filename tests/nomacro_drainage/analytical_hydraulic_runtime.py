"""Actual original analytical family with qualified explicit trial search and native budgets."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import shutil
import re

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tests/nomacro_scheduled_subsurface'), str(ROOT / 'tools/solute')]
import original_output_matrix as thermal
from original_output_baseline import assignment


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'build-root', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--kind', choices=('water', 'cde'), required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    p.add_argument('--hydraulic-model',type=int,choices=range(3,12),required=True)
    p.add_argument('--phase', choices=('short', 'year', 'full'), default='short')
    p.add_argument('--reuse-build', type=Path)
    p.add_argument('--existing-input', type=Path)
    a = p.parse_args(); a.output.mkdir()
    inputs = a.existing_input or a.output / 'input'
    if a.existing_input is None:
        shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',inputs)
        path=inputs/'swap.swp';text=path.read_text(encoding='cp1252')
        for key,value in dict(SWSOLU=int(a.kind=='cde'),SWCSV=3,NPRINTDAY=1,SWMONTH=0,PERIOD=1,SWODAT=0,SWRES=1).items():
            text=assignment(text,key,value)
        if a.kind=='cde':text=assignment(text,'CPRE','0.01')
        text+=f'\niHWCKmodel = {a.hydraulic_model}\nALFA_2 = .005 .003\nNPAR_2 = 1.5 1.6\nOMEGA_1 = .8 .8\nH0 = -1e6 -1e6\n'
        path.write_text(text,encoding='cp1252')
        if a.kind=='water':
            for crop in inputs.glob('*.crp'):
                crop.write_text(assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',0),encoding='cp1252')
    m = thermal.m; policy = 'original-adaptive-day-seed-v1'
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        kind=a.kind, optimization=a.optimization, phase=a.phase, hydraulic_model=a.hydraulic_model, input_root=str(inputs),
        build_root=str(a.reuse_build or a.build_root / 'bundle'), canonical_admission=False,
        inventory={str(v.relative_to(inputs)): hashlib.sha256(v.read_bytes()).hexdigest()
                   for v in sorted(inputs.rglob('*')) if v.is_file()})
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    save()
    try:
        project = m.e.load(inputs, original_output=True, time_step_policy=policy)
        assert project.solute == (a.kind == 'cde')
        build = a.reuse_build or a.build_root / 'bundle'
        if a.reuse_build is None:
            command = [sys.executable, '-B', str(ROOT / 'tools/solute/run_water.py'), '--model', project.model,
                '--experimental-project', str(inputs), '--original-output', '--experimental-time-step-policy', policy,
                '--reference-work', str(a.reference_work), '--build-only', '--donor-opt', a.optimization,
                '--kernel-opt', a.optimization, '--output', str(build)]
            start = time.perf_counter()
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=180)
            (a.output / 'build.stdout.txt').write_text(result.stdout, encoding='utf-8')
            (a.output / 'build.stderr.txt').write_text(result.stderr, encoding='utf-8')
            q['build'] = dict(returncode=result.returncode, seconds=time.perf_counter()-start, command=command)
            save(); result.check_returncode()
        meta,_=m.validate_bundle(build, a.reference_work, project)
        assert meta['identity'].get('model7_terminal_water')
        assert bool(meta['identity'].get('model7_capacity'))==(a.hydraulic_model==7)
        days = {'short':35,'year':367,'full':1096}[a.phase]
        windows = [(2, 4), (19, 23), (30, 34)]
        if a.phase in ('year','full'): windows += [(199,201),(364,367)]
        if a.phase=='full': windows += [(530,532),(1094,1096)]
        cuts = {days} | {d for pair in windows for d in pair}
        trajectory = a.output / 'trajectory'
        q['trajectory'], data = m.trajectory(build, a.reference_work, project, trajectory, days, cuts, 180)
        q['own'] = []
        for start, end in windows:
            q['own'].append(thermal.own(build, a.reference_work, project, trajectory, data, start, end,
                a.output / ('own-' + str(start))))
            save()
        q['status'] = 'CANDIDATE_ACTUAL_ANALYTICAL_FAMILY_'+str(a.hydraulic_model)+'_' + a.kind.upper() + '_' + a.phase.upper() + '_PASS_NOT_ADMITTED'
        print(q['status'], q['trajectory'], flush=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally:
        save()


if __name__ == '__main__': main()
