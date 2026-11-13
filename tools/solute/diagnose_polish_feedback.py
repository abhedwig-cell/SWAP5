"""Private numerical-policy discriminator, never a release build or reference.

Keep every Newton iteration and mass guard. Exclude just one final confirmation
iteration from subsequent adaptive time-step feedback, outside the Fortran DO.
No checkpoint produced here may be rebound to a supported build.
"""
import argparse
import json
import math
import shutil
import subprocess
import time
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
for name in ('bundle', 'reference', 'full', 'observer', 'output'):
    p.add_argument('--'+name, type=Path, required=True)
p.add_argument('--days', type=int, default=5)
p.add_argument('--receipt-guard',action='store_true',help='Private absolute day-receipt projection')
p.add_argument('--no-feedback',action='store_true',help='Test receipt guard without adaptive feedback change')
p.add_argument('--primary-feedback',action='store_true',help='Use first original convergence count for original adaptive controller')
p.add_argument('--quadmath',action='store_true',help='Private GNU quadmath rounded elementary functions; no feedback change')
p.add_argument('--same-core',action='store_true',help='Single private observation of unchanged core, no feedback modification')
a = p.parse_args()
a.output.mkdir()
meta = json.loads((a.bundle/'BUILD.json').read_text())
results = {}
candidate='same-core' if a.same_core else 'quadmath' if a.quadmath else 'primary-feedback' if a.primary_feedback else 'receipt-only' if a.no_feedback else 'receipt-feedback' if a.receipt_guard else 'polish-feedback'
for mode in ((candidate,) if a.same_core else ('baseline',candidate)):
    out = a.output/mode
    out.mkdir()
    source = (a.bundle/'headcalc.f90').read_text(encoding='cp1252')
    if mode != 'baseline' and not a.no_feedback and not a.quadmath and not a.same_core:
        assert source.count('\nsubroutine headcalc\n') == 1
        source = source.replace('\nsubroutine headcalc\n',
                                '\nsubroutine rc1_headcalc_impl(rc1_polish_only)\n', 1)
        source = source.replace('   implicit none',
                                '   implicit none\n   integer, intent(out) :: rc1_polish_only', 1)
        source = source.replace('   mass_polish_at = 0',
                                '   rc1_polish_only = 0\n   mass_polish_at = 0', 1)
        anchor = '         itnumb(min(100,numbit),1)'
        assert source.count(anchor) == 1
        source = source.replace(anchor,
            '         if (mass_polish_at>0 .and. numbit==mass_polish_at+1) rc1_polish_only=1\n'+anchor)
        source = source.replace('end subroutine headcalc', 'end subroutine rc1_headcalc_impl')
        if a.primary_feedback:
            source=source.replace('         if (mass_polish_at>0 .and. numbit==mass_polish_at+1) rc1_polish_only=1\n','')
            anchor='      if (budget_enabled .and. .not.flnonconv) then'
            assert source.count(anchor)==1
            source=source.replace(anchor,'      if (.not.flnonconv .and. rc1_polish_only==0) rc1_polish_only=numbit\n'+anchor)
        feedback=('   if (rc1_polish_only>0 .and. numbit<maxit) numbit=rc1_polish_only'
                  if a.primary_feedback else '   if (rc1_polish_only==1 .and. numbit<maxit) numbit=numbit-1')
        source += '''
subroutine headcalc
   use variables, only: numbit, maxit
   implicit none
   integer :: rc1_polish_only
   call rc1_headcalc_impl(rc1_polish_only)
FEEDBACK
end subroutine headcalc
'''.replace('FEEDBACK',feedback)
    if mode != 'baseline' and a.receipt_guard:
        source=source.replace('   use hybrid_step_budget, only: projected_water_residual',
            '   use hybrid_step_budget, only: projected_water_residual\n   use rc1_day_receipt_probe, only: projected_day_receipt')
        assert source.count('budget_total+budget_step')==1
        assert source.count('budget_total + budget_step')==1
        source=source.replace('abs(budget_total+budget_step)',
            'max(abs(budget_total+budget_step),abs(projected_day_receipt()))')
        source=source.replace('abs(budget_total + budget_step)',
            'max(abs(budget_total + budget_step),abs(projected_day_receipt()))')
        shutil.copyfile(Path(__file__).with_name('platform_day_receipt.f90'),out/'platform_day_receipt.f90')
    (out/'headcalc.f90').write_text(source, encoding='cp1252')
    for name in ('swap_main', 'swap_csv_output'):
        shutil.copyfile(a.observer/(name+'.f90'), out/(name+'.f90'))
    names=(['platform_day_receipt'] if mode!='baseline' and a.receipt_guard else [])+['headcalc','swap_csv_output','swap_main']
    for name in names:
        command = ['gfortran', *meta['identity']['donor_flags'], '-I',str(out),'-I', str(a.bundle),
                   '-I', str(a.reference/'build/swap-obj'), '-I', str(a.reference/'build/ttutil-obj'),
                   '-c', name+'.f90']
        c = subprocess.run(command, cwd=out, capture_output=True, text=True, timeout=30)
        (out/(name+'-compile.log')).write_text(c.stdout+c.stderr)
        assert c.returncode == 0, c.stderr
    objects = []
    for original in sorted((a.reference/'build/swap-obj').glob('*.o')):
        candidates = [out/original.name, a.bundle/original.name, original]
        objects.append(str(next(q for q in candidates if q.exists())))
    exe = out/'diagnostic.exe'
    math_objects=[]
    if mode!='baseline' and a.quadmath:
        math_source=Path(__file__).with_name('platform_quadmath_probe.c').resolve()
        c=subprocess.run(['gcc','-O2','-fno-builtin','-c',str(math_source),'-o',str(out/'quadmath_probe.o')],capture_output=True,text=True,timeout=30)
        assert c.returncode==0,c.stderr
        math_objects=[str(out/'quadmath_probe.o'),'-lquadmath']
    c = subprocess.run(['gfortran', '-o', str(exe), *objects,
                        *([str(out/'platform_day_receipt.o')] if mode!='baseline' and a.receipt_guard else []),
                        str(a.bundle/'hybrid_step_budget.o'),
                        str(a.reference/'build/ttutil-obj/libttutil.a'),*math_objects],
                       capture_output=True, text=True, timeout=30)
    assert c.returncode == 0, c.stderr
    case = out/'case'
    case.mkdir()
    for name in meta['inputs']:
        (case/name).parent.mkdir(exist_ok=True, parents=True)
        shutil.copyfile(a.full/'original'/name, case/name)
    payload = ''.join(f'{day} -1\n' for day in range(1,a.days+1))+'0 -1\n'
    started=time.perf_counter()
    with (out/'stdout').open('wb') as stdout, (out/'stderr').open('wb') as stderr:
        try:
            c = subprocess.run([str(exe), './swap.swp'], cwd=case, input=payload.encode(),
                               stdout=stdout, stderr=stderr, timeout=60)
        except subprocess.TimeoutExpired:
            (a.output/'RESULT.json').write_text(json.dumps(dict(status='CENSORED_MODEL_CAP',
                failed_mode=mode,cap_seconds=60,completed_modes=results),indent=2)+'\n')
            raise
    model_seconds=time.perf_counter()-started
    assert c.returncode == 100, c.returncode
    frames = {}
    for line in (out/'stdout').read_text(encoding='cp1252').splitlines():
        if line.startswith(('RC1_HIST ', 'RC1_HEAD ', 'RC1_HEAT ', 'HYBRID_UPTAKE ',
                            'HYBRID_STOCK_FLUX ', 'HYBRID_EXTERNAL_FLUX ',
                            'HYBRID_SOLUTE_LEDGER ')):
            tag, *values = line.split()
            frames.setdefault(tag, []).append(list(map(float, values)))
    assert all(len(v)==a.days+1 for v in frames.values())
    water, solute = [], []
    for day in range(1,a.days+1):
        stocks = frames['HYBRID_STOCK_FLUX'][day]
        flow = frames['HYBRID_EXTERNAL_FLUX'][day]
        water.append(math.fsum([*flow[:7], *(-q for q in flow[7:]),
                               *stocks[6:], *(-q for q in stocks[:6])]))
        end,delta,rain,irrig,bottom,drain,decay,root,reported = frames['HYBRID_SOLUTE_LEDGER'][day]
        start = frames['HYBRID_SOLUTE_LEDGER'][day-1][0]
        solute.append(math.fsum([end,-start,-rain,-irrig,-bottom,drain,decay,root]))
        assert abs(reported)<=1e-10
    hist = frames['RC1_HIST'][-1]
    results[mode] = dict(days=a.days, model_wall_seconds=model_seconds,solves=sum(hist),
        iterations=sum((i+1)*v for i,v in enumerate(hist)),
        max_water_residual=max(map(abs,water)), max_solute_residual=max(map(abs,solute)),
        unchanged_guards_pass=max(map(abs,water+solute))<=1e-10)
    (out/'FRAMES.json').write_text(json.dumps(frames)+'\n')
(a.output/'RESULT.json').write_text(json.dumps(dict(status='EXPERIMENTAL_NOT_ADMITTED',
    receipt_guard=a.receipt_guard,adaptive_feedback=not(a.no_feedback or a.quadmath or a.same_core),
    primary_feedback=a.primary_feedback,
    quadmath=a.quadmath,
    hypothesis=('Common compiler arithmetic policy' if a.same_core else 'Math runtime seeds' if a.quadmath else 'Pure final polish iteration unnecessarily restricts adaptive step growth'),
    results=results), indent=2)+'\n')
print(json.dumps(results), flush=True)
