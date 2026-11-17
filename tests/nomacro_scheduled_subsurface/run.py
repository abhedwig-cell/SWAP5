"""Execute original scheduled SSDI with conserved water and exact native restart.

Uses the existing real production daily-host and mixture qualification helpers.
No model formula, alternate allocation or relaxed guard is implemented here.
"""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('original_mixtures', ROOT/'tests/nomacro_mixtures/run.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
from daily_coupling import CoupledDailyColumn, validate_bundle


def assignment(text, name, value):
    text, count = re.subn(r'(?mi)^([ \t]*'+name+r'[ \t]*=[ \t]*)[^!\r\n]+', lambda match: match[1]+str(value)+' ', text)
    assert count == 1, name
    return text


def fixture(case, kind):
    shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook', case)
    path = case/'swap.swp'
    text = path.read_text(encoding='cp1252')
    for name, value in dict(SWSOLU=0, SWIRFIX=0, SWMONTH=0).items():
        text = assignment(text, name, value)
    text = assignment(text, 'INLIST_CSV', "'WATBAL,ETTERMS,GWL,CROP,WOFOST,GRASS'")
    text += '\nNUM_DECIMALS = 12\n'
    path.write_text(text, encoding='cp1252')
    # Every actual future crop is covered, including rotation initialization.
    for path in case.glob('*.crp'):
        body = path.read_text(encoding='cp1252')
        for name, value in dict(SWSALINITY=0, SCHEDULE=1, ISUAS=2, TCS=6, DCS=2,
                                IRGTHRESHOLD=0.01, IRR_RATE=0.1).items():
            body = assignment(body, name, value)
        body = assignment(body, 'SS_IRR_Z', '-15.0' if kind == 'point' else '-10.0 -20.0')
        body, count = re.subn(r'(?m)^([ \t]*[02]\.0[ \t]+)60\.0', r'\g<1>1.0', body)
        assert count == 2
        path.write_text(body, encoding='cp1252')
    return m.e.inspect(case)


def controls(build, reference, project, out, data):
    meta, _ = validate_bundle(build, reference, project)
    foreign = out/'foreign-policy'; foreign.mkdir()
    changed = json.loads((build/'BUILD.json').read_text())
    changed['identity']['scheduled_subsurface_irrigation']['policy'] = 'foreign'
    (foreign/'BUILD.json').write_text(json.dumps(changed))
    try:
        validate_bundle(foreign, reference, project)
    except ValueError as error:
        assert 'Foreign original scheduled subsurface irrigation policy' in str(error)
    else:
        raise AssertionError('Foreign scheduled SSDI policy accepted')
    # Changed physical inventory must be refused by the real kernel before commit.
    target = out/'mass-refused'; target.mkdir()
    with contextlib.ExitStack() as stack:
        host = m.h.DailyHost(stack, m.h.executable(build,'day_donor'), m.h.executable(build,'day_kernel'),
                            Path(project.input_directory), target, [m.h.ColumnStart()],
                            runtime=True, checkpoint_enabled=True, project=project)
        stocks = host.columns[0].stocks.copy(); send = m.h.send
        def inconsistent(process, line):
            values = line.split()
            if process is host.host and len(values) == project.nodes+12:
                values[2] = str(float(values[2])+1); line = ' '.join(values)
            return send(process, line)
        try:
            m.h.send = inconsistent; rejected = host.step(1)
        finally:
            m.h.send = send
        assert not rejected['committed'] and rejected['revision'] == 0
        assert host.columns[0].stocks == stocks and host.columns[0].day == 0
        assert not list(target.glob('accepted-*.zip'))
        host.close()
    column = CoupledDailyColumn(build, reference, out/'external', project, 'scheduled-ssdi')
    first = column.prepare(); column.discard(first)
    replay = column.prepare(); assert replay.budget == first.budget
    column.accept(replay)
    recovered = CoupledDailyColumn(build, reference, out/'recovered', project, 'scheduled-ssdi',
                                   origin=column.checkpoint, day=1)
    second = recovered.prepare()
    assert m.physical([{k:v for k,v in second.budget.items() if k != 'candidate_only'}|{'committed':True}]) == m.physical([data[1]])
    recovered.discard(second)
    return dict(foreign_policy_refused=True, inconsistent_mass_refused=True,
                external_discard_replay_exact=True, external_disk_recovery=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-work', type=Path, required=True)
    parser.add_argument('--configuration', choices=['point','interval'], required=True)
    parser.add_argument('--short-only', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    reference = args.reference_work.resolve(); m.user_prepare.validate(reference)
    case = out/'input'; descriptor = fixture(case, args.configuration)
    project = m.e.load(case)
    result = dict(status='RUNNING', source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  configuration=args.configuration, inputs=descriptor, profiles={}, events=[],
                  physical_equations='UNCHANGED_ORIGINAL', science='NOT_QUALIFIED', water_guard_cm=1e-10)
    def save(): (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            build = out/(opt+'-build')
            command = [sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                       '--experimental-project',str(case),'--reference-work',str(reference),'--build-only',
                       '--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            started = time.perf_counter(); run = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (out/(opt+'-build.stdout')).write_text(run.stdout); (out/(opt+'-build.stderr')).write_text(run.stderr)
            result['events'].append(dict(command=command,seconds=time.perf_counter()-started,returncode=run.returncode))
            assert run.returncode == 0, run.stderr
            short = out/(opt+'-short')
            brief, data = m.trajectory(build,reference,project,short,5,{2,4},30)
            brief['own'] = m.own(build,reference,project,short,data,2,4,out/(opt+'-short-own'))
            result['profiles'][opt] = dict(short=brief); save()
            print(args.configuration,opt,'SHORT_EXACT_NATIVE_PASS',flush=True)
            if args.short_only: continue
            full = out/(opt+'-full')
            # Daily native cuts permit causal own continuations around any real
            # irrigation event without repeating the continuous trajectory.
            report, data = m.trajectory(build,reference,project,full,1096,set(range(1,1097)),60)
            report['short'] = brief; result['profiles'][opt] = report; save()
            active = [i+1 for i,row in enumerate(data) if row['external_flux_cm'][5] > 0]
            assert active and all(row['external_flux_cm'][3] == 0 for row in data)
            report['subsurface_exposure'] = dict(days=active,total_cm=sum(row['external_flux_cm'][5] for row in data))
            starts = sorted({2,365,530}|{max(1,active[0]-1),max(1,active[len(active)//2]-1),max(1,active[-1]-1)})
            report['own'] = [m.own(build,reference,project,full,data,start,start+2,out/(opt+'-own'+str(start))) for start in starts if start+2<=1096]
            target = out/(opt+'-controls'); target.mkdir()
            report['controls'] = controls(build,reference,project,target,data); save()
            print(args.configuration,opt,'FULL_NATIVE_TRANSACTIONS_PASS',flush=True)
        result['status'] = 'SHORT_O0_O2_PASS' if args.short_only else 'FULL_O0_O2_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error)); raise
    finally:
        save()


if __name__ == '__main__':
    main()
