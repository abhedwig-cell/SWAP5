"""Opt-in intact original nonlinear/macropore block without dated research gates.

Retains original task2 rate refresh, task3 Jacobian and flunsatok cache policy.
No original equation, convergence criterion or accepted-state routine is changed.
"""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import daily_host as h
from donor_sources import replace

POLICY = 'original-nonlinear-macro-block-explicit-integral-history-v1'


def render_headcalc(source):
    source=replace(source, "      if (iTask == 1 .OR. .NOT. flunsatok(3) .OR. &\n"
                          "          (t1900 >= 36252.9989d0 .AND. t1900 < 36253d0)) then\x20",
                          "      if (iTask == 1 .OR. .NOT. flunsatok(3)) then\x20")
    source=replace(source, 'budget_enabled .and. budget_start >= 36051d0 .and. swmacro == 1',
                          'budget_enabled .and. swmacro == 1')
    source=replace(source, '   integer, save                    :: iwarn, NStep',
        '   ! Original counters are explicit worker state and part of its restart.')
    source=replace(source, 'only: budget_enabled, budget_step, budget_total, budget_start, budget_retries',
        'only: budget_enabled, budget_step, budget_total, budget_start, budget_retries, &\n'
        '     iwarn => macro_iwarn, NStep => macro_nstep')
    if any(x in source for x in ('36051d0','36252.9989d0','36253d0')):
        raise ValueError('Calendar-scoped macro policy remains')
    return source


def render_macro_checkpoint(source):
    """Restore the original reset flags, not cold-start accounting resets."""
    # MACROINTEGRAL's local FrMpWalWetOld shadows the module's identically
    # named, already checkpointed field. Preserve its original cold ZERO value,
    # not the module field initialized from the current wet fraction.
    a=source.index('      SUBROUTINE MACROINTEGRAL ()')
    b=source.index('      end subroutine MacroIntegral',a)
    routine=replace(source[a:b],'      real(8) FrMpWalWetOld(MaDm,MaCp)',
        '      ! Previous integral quadrature endpoint belongs to explicit state.')
    routine=routine.replace('FrMpWalWetOld','hybrid_integral_wall_previous')
    source=source[:a]+routine+source[b:]
    source=replace(source,'   contains\n',
        '   real(8), save :: hybrid_integral_wall_previous(madm,macp) = 0d0\n\n   contains\n')
    source=replace(source, '    subroutine hybrid_macro_checkpoint(restoring, clock, old_step, canopy_stock)\n      use MOD_swap_mp',
        '    subroutine hybrid_macro_checkpoint(restoring, clock, old_step, canopy_stock)\n      use variables, only: flzerocumu, flzerointr\n      use hybrid_day_window, only: macro_iwarn, macro_nstep\n      use MOD_swap_mp')
    # A new native format refuses old cold-reset context rather than guessing it.
    if source.count("'S5MAC003'") != 2:
        raise ValueError('Unexpected native checkpoint format')
    source=source.replace("'S5MAC003'", "'S5MAC006'")
    source=replace(source, "        if (ios /= 0) error stop 'Incomplete macro checkpoint payload'",
        "        if (ios /= 0) error stop 'Incomplete macro checkpoint payload'\n"
        "        read(unit,iostat=ios) flzerocumu, flzerointr, macro_iwarn, macro_nstep, hybrid_integral_wall_previous\n"
        "        if (ios /= 0) error stop 'Missing macro reset context'")
    source=replace(source, '      end if\n      close(unit)\n      write(*,',
        '        write(unit) flzerocumu, flzerointr, macro_iwarn, macro_nstep, hybrid_integral_wall_previous\n      end if\n      close(unit)\n      write(*,')
    return source


def build_bundle(base,reference,target):
    """Recompile generated donor owners, retaining original physics objects/kernel."""
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
    p=target/'swap.f90';p.write_text(replace(p.read_text(encoding='cp1252'),
        '  integer :: budget_retries = 0',
        '  integer :: macro_iwarn = 0, macro_nstep = 0\n  integer :: budget_retries = 0'),encoding='cp1252')
    p=target/'macropore.f90';p.write_text(render_macro_checkpoint(p.read_text(encoding='cp1252')),encoding='cp1252')
    p=target/'swap_main.f90'
    p.write_text(replace(p.read_text(encoding='cp1252'),'budget_enabled = window >= 15','budget_enabled = .true.'),encoding='cp1252')
    commands=[['gfortran',*identity['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c',name] for name in ['swap.f90','macropore.f90','headcalc.f90','swap_main.f90']]
    replacements={Path(n).with_suffix('.o').name:target/Path(n).with_suffix('.o').name for n in identity['donor_generated']}
    commands.append(['gfortran','-o',str(h.executable(target,'day_donor')),
        *(str(replacements.get(p.name,p)) for p in sorted(objects.glob('*.o'))),str(target/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')])
    logs=[]
    for command in commands:
        completed=subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=45)
        logs.append({'command':command,'exit_code':completed.returncode,'stdout':completed.stdout,'stderr':completed.stderr})
        (target/'INCREMENTAL_BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
        if completed.returncode:raise ValueError('Generic macro candidate compilation failed')
    for name in ['headcalc.f90','swap_main.f90','macropore.f90','swap.f90']:identity['donor_generated'][name]=h.sha(target/name)
    policy=POLICY
    identity['macro_policy']={'name':policy,'generator_sha256':h.sha(Path(__file__)),
        'original_MACRORATE_object_sha256':h.sha(objects/'macrorate.o'),
        'native_macro_format':'S5MAC006-original-reset-flags-counters-integral-history',
        'objects_sha256':{n:h.sha(target/n) for n in ['headcalc.o','swap_main.o','macropore.o','swap.o']}}
    meta['identity']=identity;meta['binding']={**meta['binding'],'build':identity,'refresh_macro_final':False,'macro_policy':policy}
    meta['executable_sha256']['donor']=h.sha(h.executable(target,'day_donor'))
    (target/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n');return target
