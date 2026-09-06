#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import a23bs_prepare_execution_time_source as bs


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_a23bs(source: Path, output: Path, ttutil_prefs: Path) -> None:
    bs.build_a23br(source, output, ttutil_prefs)
    bs.rename_context_refs(output)
    bs.transform_variables(output / 'variables.f90')
    bs.transform_initialize(output / 'initialize.f90')
    bs.transform_timecontrol(output / 'timecontrol.f90')
    bs.transform_headcalc(output / 'headcalc.f90')
    bs.transform_integral(output / 'integral.f90')
    bs.transform_swap(output / 'swap.f90')
    bs.transform_initialize_integral_call(output / 'initialize.f90')


def rename_context_refs(root: Path) -> None:
    for p in root.glob('*.f90'):
        s = p.read_text(encoding='latin1')
        s = s.replace('mod_a23bs_worker_execution_context', 'mod_a23bt_worker_execution_context')
        s = s.replace('a23bs_', 'a23bt_')
        p.write_text(s, encoding='latin1', newline='')


def transform_timecontrol(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(
        r'^module MOD_timer\n! local, must save\n   real\(8\), save :: tcumold\nend module MOD_timer\n\n',
        '', s, count=1, flags=re.M,
    )
    s = s.replace('   use MOD_timer\n', '', 1)
    s = s.replace('      tcumold = 0.0d0\n', '', 1)

    start = s.index('   case (2)')
    end = s.index('   case (4)', start)
    dyn = s[start:end]
    repl = {
        'floutputshort': 'worker%reporting%output_short',
        'flbaloutput': 'worker%reporting%balance_output',
        'flheader': 'worker%reporting%header',
        'floutput': 'worker%reporting%output',
        'flzerointr': 'worker%reporting%reset_intermediate',
        'flzerocumu': 'worker%reporting%reset_cumulative',
        'nprintcount': 'worker%reporting%nprintcount',
        'ioutdatint': 'worker%reporting%ioutdatint',
        'ioutdat': 'worker%reporting%ioutdat',
        'cntper': 'worker%reporting%cntper',
        'outper': 'worker%reporting%outper',
        'tcumold': 'worker%reporting%tcumold',
    }
    for old in sorted(repl, key=len, reverse=True):
        dyn = re.sub(rf'\b{old}\b', repl[old], dyn, flags=re.I)
    s = s[:start] + dyn + s[end:]

    f0 = s.index('   function get_dtevent()')
    f1 = s.index('   end function get_dtevent', f0)
    frag = s[f0:f1]
    frag = re.sub(r'\bnprintcount\b', 'worker%reporting%nprintcount', frag, flags=re.I)
    s = s[:f0] + frag + s[f1:]
    path.write_text(s, encoding='latin1', newline='')


def transform_swap_output(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = s.replace(
        '   ioutdat    = 1\n!   call TimeControl(1, worker)\n',
        '   worker%reporting%ioutdat = 1\n!   call TimeControl(1, worker)\n',
        1,
    )
    old = '''!     output section (write to standard files and to optional files)\n      if (flOutput) then\n         call SwapOutput(2)\n         call SoilWaterOutput(2)\n         if (swtill == 1)     call DoTillage(3)\n         if (swsolu > 0)      call Solute(3)\n         if (swmacro == 1)    call MacroPoreOutput(2)\n      else\n         if (flOutputShort)   call SoilWaterOutput(2)\n      end if\n'''
    new = '''!     output section. A23BT transaction trials have no legacy output emission;\n!     the non-worker compatibility path retains the historical output behavior.\n      if (.not. present(worker)) then\n         if (flOutput) then\n            call SwapOutput(2)\n            call SoilWaterOutput(2)\n            if (swtill == 1)     call DoTillage(3)\n            if (swsolu > 0)      call Solute(3, .false., .false.)\n            if (swmacro == 1)    call MacroPoreOutput(2)\n         else\n            if (flOutputShort)   call SoilWaterOutput(2)\n         end if\n      end if\n'''
    if s.count(old) != 1:
        raise ValueError('swap output section anchor changed')
    s = s.replace(old, new, 1)
    path.write_text(s, encoding='latin1', newline='')


def transform_integral(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    old = '      subroutine integral(iTask, day_start_event)\n'
    new = '      subroutine integral(iTask, day_start_event, reset_intermediate, reset_cumulative)\n'
    if s.count(old) != 1:
        raise ValueError('integral signature anchor changed')
    s = s.replace(old, new, 1)
    old = '      integer, intent(in) :: iTask\n      logical, intent(in) :: day_start_event\n'
    new = '      integer, intent(in) :: iTask\n      logical, intent(in) :: day_start_event, reset_intermediate, reset_cumulative\n'
    if s.count(old) != 1:
        raise ValueError('integral declaration anchor changed')
    s = s.replace(old, new, 1)
    old = '      use variables,       only: flzerocumu, flzerointr, dt, epd, reva, qbot, qrot, runots,runon, q, volini, volact, pondini, pond, theta, ivolbeg, ipondbeg, issnowbeg, isicbeg, ithetabeg\n'
    new = '      use variables,       only: dt, epd, reva, qbot, qrot, runots,runon, q, volini, volact, pondini, pond, theta, ivolbeg, ipondbeg, issnowbeg, isicbeg, ithetabeg\n'
    if s.count(old) != 1:
        raise ValueError('integral reset use anchor changed')
    s = s.replace(old, new, 1)
    s = re.sub(r'\bflzerocumu\b', 'reset_cumulative', s, flags=re.I)
    s = re.sub(r'\bflzerointr\b', 'reset_intermediate', s, flags=re.I)
    path.write_text(s, encoding='latin1', newline='')


def transform_solute(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    old = (
        '      module subroutine solute_CDE(task)\n'
        '         integer, intent(in) :: task\n'
        '      end subroutine solute_CDE\n'
        '      module subroutine calc_AgeTracer(task)\n'
        '         integer, intent(in) :: task\n'
        '      end subroutine calc_AgeTracer\n'
    )
    new = (
        '      module subroutine solute_CDE(task, reset_intermediate, reset_cumulative)\n'
        '         integer, intent(in) :: task\n'
        '         logical, intent(in) :: reset_intermediate, reset_cumulative\n'
        '      end subroutine solute_CDE\n'
        '      module subroutine calc_AgeTracer(task, reset_intermediate, reset_cumulative)\n'
        '         integer, intent(in) :: task\n'
        '         logical, intent(in) :: reset_intermediate, reset_cumulative\n'
        '      end subroutine calc_AgeTracer\n'
    )
    if s.count(old) != 1:
        raise ValueError('solute module interface anchor changed')
    s = s.replace(old, new, 1)

    old = '   subroutine solute(task)\n\n   implicit none\n   integer, intent(in) :: task\n'
    new = '   subroutine solute(task, reset_intermediate, reset_cumulative)\n\n   implicit none\n   integer, intent(in) :: task\n   logical, intent(in) :: reset_intermediate, reset_cumulative\n'
    if s.count(old) != 1:
        raise ValueError('solute wrapper anchor changed')
    s = s.replace(old, new, 1)
    s = s.replace('call solute_CDE(task)', 'call solute_CDE(task, reset_intermediate, reset_cumulative)')
    s = s.replace('call calc_AgeTracer(task)', 'call calc_AgeTracer(task, reset_intermediate, reset_cumulative)')

    old = '      module subroutine solute_CDE(task)\n'
    if s.count(old) != 1:
        raise ValueError('solute_CDE implementation anchor changed')
    s = s.replace(old, '      module subroutine solute_CDE(task, reset_intermediate, reset_cumulative)\n', 1)
    marker = '      integer, intent(in)                 :: task\n'
    pos = s.index('      module subroutine solute_CDE(task, reset_intermediate, reset_cumulative)')
    decl = s.index(marker, pos)
    s = s[:decl+len(marker)] + '      logical, intent(in)                 :: reset_intermediate, reset_cumulative\n' + s[decl+len(marker):]
    old_use = '      use variables,           only: flzerointr, flzerocumu, q, dtmin, qtop, pond, qrot, qbot\n'
    if s.count(old_use) != 1:
        raise ValueError('CDE reset use anchor changed')
    s = s.replace(old_use, '      use variables,           only: q, dtmin, qtop, pond, qrot, qbot\n', 1)

    old = '      module subroutine calc_AgeTracer(task)\n'
    if s.count(old) != 1:
        raise ValueError('AgeTracer implementation anchor changed')
    s = s.replace(old, '      module subroutine calc_AgeTracer(task, reset_intermediate, reset_cumulative)\n', 1)
    pos = s.rindex('      module subroutine calc_AgeTracer(task, reset_intermediate, reset_cumulative)')
    marker = '      integer, intent(in) :: task\n'
    decl = s.index(marker, pos)
    s = s[:decl+len(marker)] + '      logical, intent(in) :: reset_intermediate, reset_cumulative\n' + s[decl+len(marker):]
    old_use = '      use variables,     only: flzerocumu, q, dtmin, pondm1, qtop, pond, runots, qrot, thetm1, nodgwl, gwl\n'
    if s.count(old_use) != 1:
        raise ValueError('AgeTracer reset use anchor changed')
    s = s.replace(old_use, '      use variables,     only: q, dtmin, pondm1, qtop, pond, runots, qrot, thetm1, nodgwl, gwl\n', 1)

    s = re.sub(r'\bflzerointr\b', 'reset_intermediate', s, flags=re.I)
    s = re.sub(r'\bflzerocumu\b', 'reset_cumulative', s, flags=re.I)
    path.write_text(s, encoding='latin1', newline='')


def transform_swap_reset_and_calls(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    s = re.sub(r'\bflzerointr,\s*', '', s, count=1, flags=re.I)
    old = '   flzerointr = .TRUE.\n   t          = tstart - timjan1\n'
    new = '   worker%reporting%reset_intermediate = .true.\n   worker%reporting%reset_cumulative = .false.\n   t          = tstart - timjan1\n'
    if s.count(old) != 1:
        raise ValueError('swap dynamic reset anchor changed')
    s = s.replace(old, new, 1)
    repl = {
        '      call integral(2, worker%time%day_start_event)\n':
            '      call integral(2, worker%time%day_start_event, worker%reporting%reset_intermediate, worker%reporting%reset_cumulative)\n',
        '      call integral(3, worker%time%day_start_event)\n':
            '      call integral(3, worker%time%day_start_event, worker%reporting%reset_intermediate, worker%reporting%reset_cumulative)\n',
        '         call integral (4, worker%time%day_start_event)\n':
            '         call integral (4, worker%time%day_start_event, worker%reporting%reset_intermediate, worker%reporting%reset_cumulative)\n',
        '      if (swsolu > 0) call Solute(2)\n':
            '      if (swsolu > 0) call Solute(2, worker%reporting%reset_intermediate, worker%reporting%reset_cumulative)\n',
        '   if (swsolu > 0) call Solute(1)\n':
            '   if (swsolu > 0) call Solute(1, .true., .true.)\n',
        '   if (swsolu > 0)           call Solute(9)\n':
            '   if (swsolu > 0)           call Solute(9, .false., .false.)\n',
    }
    for old, new in repl.items():
        if s.count(old) != 1:
            raise ValueError(f'swap call anchor changed: {old.strip()}')
        s = s.replace(old, new, 1)
    path.write_text(s, encoding='latin1', newline='')


def transform_initialize_integral(path: Path) -> None:
    s = path.read_text(encoding='latin1')
    old = '      call integral(1, .false.)\n'
    new = '      call integral(1, .false., .true., .true.)\n'
    if s.count(old) != 1:
        raise ValueError('initialize integral call anchor changed')
    s = s.replace(old, new, 1)
    path.write_text(s, encoding='latin1', newline='')


def audit(root: Path) -> dict:
    tc = (root / 'timecontrol.f90').read_text(encoding='latin1')
    sw = (root / 'swap.f90').read_text(encoding='latin1')
    integ = (root / 'integral.f90').read_text(encoding='latin1')
    solu = (root / 'solute.f90').read_text(encoding='latin1')
    if re.search(r'\breal\(8\),\s*save\s*::\s*tcumold\b', tc, re.I):
        raise ValueError('tcumold SAVE remains')
    if 'A23BT transaction trials have no legacy output emission' not in sw:
        raise ValueError('transaction output suppression missing')

    dyn = tc[tc.index('   case (2)'):tc.index('   case (4)', tc.index('   case (2)'))]
    mapping = {
        'floutputshort':'output_short', 'flbaloutput':'balance_output',
        'flheader':'header', 'floutput':'output',
        'flzerointr':'reset_intermediate', 'flzerocumu':'reset_cumulative',
    }
    for sym in ['nprintcount','cntper','ioutdat','ioutdatint','outper','tcumold',
                'floutputshort','flbaloutput','flheader','floutput','flzerointr','flzerocumu']:
        tmp = re.sub(r'worker%reporting%' + re.escape(mapping.get(sym, sym)), '', dyn, flags=re.I)
        if re.search(rf'\b{sym}\b', tmp, re.I):
            raise ValueError(f'dynamic reporting singleton remains: {sym}')

    for label, text in [('integral', integ), ('solute', solu)]:
        code = '\n'.join(line.split('!')[0] for line in text.splitlines())
        if re.search(r'\bflzerointr\b|\bflzerocumu\b', code, re.I):
            raise ValueError(f'{label} still depends on reporting reset globals')

    return {
        'transaction_trial_output_calls_suppressed': True,
        'qualified_reporting_schedule': 'NPRINTDAY=1 and FLPRINTDT=false',
        'worker_reporting_fields': [
            'nprintcount','cntper','ioutdat','ioutdatint','outper','tcumold',
            'output_short','balance_output','header','output',
            'reset_intermediate','reset_cumulative',
        ],
        'worker_reporting_reset_controls': ['reset_intermediate','reset_cumulative'],
        'kernel_contract': (
            'transaction trials are legacy-output-side-effect-free on the qualified path; '
            'reporting progression and reporting-driven accumulator resets are an ephemeral '
            'worker-side legacy shim, not column continuation state'
        ),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--ttutil-prefs', type=Path, required=True)
    ns = ap.parse_args()

    build_a23bs(ns.source, ns.output, ns.ttutil_prefs)
    rename_context_refs(ns.output)
    transform_timecontrol(ns.output / 'timecontrol.f90')
    transform_swap_output(ns.output / 'swap.f90')
    transform_integral(ns.output / 'integral.f90')
    transform_solute(ns.output / 'solute.f90')
    transform_swap_reset_and_calls(ns.output / 'swap.f90')
    transform_initialize_integral(ns.output / 'initialize.f90')
    info = audit(ns.output)
    info['parent_manifest_sha256'] = bs.PARENT_MANIFEST
    targets = ['timecontrol.f90','swap.f90','variables.f90','headcalc.f90','integral.f90','solute.f90','initialize.f90']
    info['postimage_sha256'] = {n: sha256_bytes((ns.output / n).read_bytes()) for n in targets}
    print(json.dumps(info, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
