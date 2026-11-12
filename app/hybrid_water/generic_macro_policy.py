"""Original coherent macropore rate/derivative evaluation, without calendar gates.

This is an explicit opt-in numerical policy; no original physical formula changes.
MACROPORE(3) calculates the full original rates AND their analytic derivatives.
The Jacobian consumes that same-candidate pair instead of freezing/replacing it.
"""
import copy
import json
from pathlib import Path
import re
import shutil
import subprocess

import daily_host as h
from donor_sources import replace

POLICY='original-macro-rate-derivative-pair-v1'


def render_headcalc(source):
    source=replace(source,'''      if (iTask == 1 .OR. .NOT. flunsatok(3) .OR. &
          (t1900 >= 36252.9989d0 .AND. t1900 < 36253d0)) then\x20
         call MACROPORE(2)
      else
         QMpLatSs = QMpLatSsSav
      end if''','''      ! Original task3 computes rates and analytic derivatives together.
      ! They belong to THIS residual candidate, including backtracking trials.
      call MACROPORE(3)''')
    source=replace(source,'budget_enabled .and. budget_start >= 36051d0 .and. swmacro == 1',
                         'budget_enabled .and. swmacro == 1')
    source=replace(source,'''   if (swmacro == 1 .AND. .NOT.flunsatok(3)) then
      call MACROPORE(3)
      dFdhM(1:NN) = dFdhM(1:NN) - dFdhMp(1:NN)
   end if''','''   if (swmacro == 1) then
      ! vector_F already evaluated these original derivatives at the same h.
      dFdhM(1:NN) = dFdhM(1:NN) - dFdhMp(1:NN)
   end if''')
    if any(x in source for x in ['36051d0','36252.9989d0','36253d0']):raise ValueError('Clock-gated candidate remains')
    return source


def build_bundle(base,reference,target,*,retain_early_budget_schedule=False):
    """Recompile only original HeadCalc/main, retaining exact original objects/kernel."""
    from daily_coupling import validate_bundle
    base,reference,target=map(Path,(base,reference,target))
    meta,_=validate_bundle(base,reference,h.ANDELST)
    if not all(meta['binding'][k] for k in ['budget_retry','shared_pond_transfer','refresh_macro_final']):
        raise ValueError('Expected the exact admitted corrected research source')
    identity=copy.deepcopy(meta['identity']);objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    if h.sha(Path(shutil.which('gfortran')))!=identity['compiler_sha256']:raise ValueError('Different compiler')
    for name,digest in identity['donor_objects'].items():
        if h.sha(objects/name)!=digest:raise ValueError('Foreign original provider: '+name)
    if h.sha(ttutil/'libttutil.a')!=identity['ttutil_library']:raise ValueError('Foreign TTUTIL')
    target.mkdir()
    for p in base.iterdir():
        if p.is_file() and (p.suffix.lower() in ('.o','.mod','.smod','.f90') or p.name.startswith('day_')):
            shutil.copyfile(p,target/p.name)
    p=target/'headcalc.f90';p.write_text(render_headcalc(p.read_text(encoding='cp1252')),encoding='cp1252')
    p=target/'swap_main.f90'
    if not retain_early_budget_schedule:
        p.write_text(replace(p.read_text(encoding='cp1252'),'budget_enabled = window >= 15','budget_enabled = .true.'),encoding='cp1252')
    commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',name] for name in ['headcalc.f90','swap_main.f90']]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
        *(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
    logs=[]
    for command in commands:
        completed=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=45)
        logs.append({'command':command,'exit_code':completed.returncode,'stdout':completed.stdout,'stderr':completed.stderr})
        (target/'INCREMENTAL_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if completed.returncode:raise ValueError('Generic macro candidate compilation failed')
    for name in ['headcalc.f90','swap_main.f90']:identity['donor_generated'][name]=h.sha(target/name)
    policy=POLICY+('-existing-early-budget-diagnostic' if retain_early_budget_schedule else '')
    identity['macro_policy']={'name':policy,'generator_sha256':h.sha(Path(__file__)),
        'original_MACRORATE_object_sha256':h.sha(objects/'macrorate.o'),
        'objects_sha256':{n:h.sha(target/n) for n in ['headcalc.o','swap_main.o']}}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity,'refresh_macro_final':False,'macro_policy':policy}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');return target
