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
                                TCSFIX=0, IRGTHRESHOLD=0.01, IRR_RATE=0.1).items():
            body = assignment(body, name, value)
        body = assignment(body, 'SS_IRR_Z', '-15.0' if kind == 'point' else '-10.0 -20.0')
        body, count = re.subn(r'(?mi)^([ \t]*DVS_DC2[ \t]+FID[^\n]*\n)(?:[ \t]*[\d.]+[ \t]+[\d.]+[^\n]*\n){2}',
                             r'\g<1>     0.0 1.0\n     2.0 1.0\n', body)
        assert count == 1
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


def active_own(build, reference, project, full, data, out):
    """Use the retained day530 to expose an actually active later event.

    A full period already passed. Replay only its short selected suffix, verify
    every physical/CSV row against that period, then compare complete native
    payloads between warm and cold execution around real irrigation.
    """
    meta, case = validate_bundle(build,reference,project)
    active = next(row['day'] for row in data[532:] if row['external_flux_cm'][5]>0)
    first, last = active-1, active+1
    origin = out/'origin530'
    receipt = m.h.verify_checkpoint(full/'accepted-column-1-day-530.zip',530,meta['binding'],origin)
    warm = out/'warm'; warm.mkdir()
    def continuation():
        with contextlib.ExitStack() as stack:
            host = m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,warm,
                                [m.h.ColumnStart('original',530,origin,receipt)],checkpoint_enabled=True,
                                runtime=True,binding=meta['binding'],model=project.model,project=project)
            rows = [host.step(1,checkpoint=day in (first,last)) for day in range(531,last+1)]
            host.close()
            return rows
    actual, seconds = m.bounded(30,continuation)
    m.check(actual); assert m.physical(actual) == m.physical(data[530:last])
    assert m.csvlines(warm/'original/result_output.csv')[-(last-530):] == m.csvlines(full/'original/result_output.csv')[532:last+2]
    source = warm/f'accepted-column-1-day-{first}.zip'; digest = m.sha(source)
    cold_origin = out/'cold-origin'; cold_receipt = m.h.verify_checkpoint(source,first,meta['binding'],cold_origin)
    cold = out/'cold'; cold.mkdir()
    result, cold_seconds = m.bounded(30,lambda: m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,cold,last,
        checkpoint_day=first,origin=cold_origin,origin_receipt=cold_receipt,runtime=True,publish_day=last,
        checkpoint_binding=meta['binding'],model=project.model,project=project))
    assert result['first_refusal'] is None
    rows = m.rows(cold); m.check(rows); assert m.physical(rows) == m.physical(data[first:last])
    assert m.csvlines(cold/'original/result_output.csv')[-2:] == m.csvlines(full/'original/result_output.csv')[first+2:last+2]
    with m.zipfile.ZipFile(warm/f'accepted-column-1-day-{last}.zip') as a, m.zipfile.ZipFile(cold/f'accepted-column-1-day-{last}.zip') as b:
        for name in ('result.end','macro.bin'): assert a.read(name) == b.read(name),name
    assert m.sha(source) == digest
    return dict(start=first,end=last,actual_irrigation_day=active,full_period_physical_csv_suffix_exact=True,
                exact_native=True,origin_unchanged=True,warm_seconds=seconds,cold_seconds=cold_seconds)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-work', type=Path, required=True)
    parser.add_argument('--configuration', choices=['point','interval'], required=True)
    parser.add_argument('--short-only', action='store_true')
    parser.add_argument('--reuse-from', type=Path, help='Validate existing same-source/input O0/O2 builds; never rebind them')
    parser.add_argument('--resume', action='store_true', help='Consume completed same-source periods; finish missing checks only')
    args = parser.parse_args()
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=args.resume)
    reference = args.reference_work.resolve(); m.user_prepare.validate(reference)
    if args.reuse_from:
        case = args.reuse_from.resolve()/'input'; descriptor = m.e.inspect(case)
        original = json.loads((args.reuse_from/'RESULT.json').read_text())
        assert original['configuration'] == args.configuration
    elif args.resume:
        case = out/'input'; descriptor = m.e.inspect(case)
    else:
        case = out/'input'; descriptor = fixture(case, args.configuration)
    project = m.e.load(case)
    result = dict(status='RUNNING', source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                  configuration=args.configuration, inputs=descriptor, profiles={}, events=[],
                  physical_equations='UNCHANGED_ORIGINAL', science='NOT_QUALIFIED', water_guard_cm=1e-10)
    def save(): (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.resume:
        previous = json.loads((out/'RESULT.json').read_text())
        assert previous['configuration']==args.configuration and previous['inputs']==descriptor
        result = previous
        result['controller_commit'] = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        result.setdefault('retained_failures',[]).append(dict(status=previous['status'],error=previous.get('error')))
        result.update(status='RESUMING'); result.pop('error',None)
    save()
    try:
        for opt in ('O0','O2'):
            build = out/(opt+'-build')
            if args.reuse_from:
                build = args.reuse_from.resolve()/(opt+'-build')
            command = [sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                       '--experimental-project',str(case),'--reference-work',str(reference),'--build-only',
                       '--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            if args.reuse_from or (args.resume and (build/'BUILD.json').exists()):
                validate_bundle(build,reference,project)
                result['events'].append(dict(validated_existing_build=str(build), compilation='NOT_REPEATED'))
            else:
                started = time.perf_counter(); run = subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(opt+'-build.stdout')).write_text(run.stdout); (out/(opt+'-build.stderr')).write_text(run.stderr)
                result['events'].append(dict(command=command,seconds=time.perf_counter()-started,returncode=run.returncode))
                assert run.returncode == 0, run.stderr
            short = out/(opt+'-short')
            if args.resume and 'short' in result['profiles'].get(opt,{}):
                brief = result['profiles'][opt]['short']
            else:
                brief, data = m.trajectory(build,reference,project,short,5,{2,4},30)
                brief['own'] = m.own(build,reference,project,short,data,2,4,out/(opt+'-short-own'))
                result['profiles'][opt] = dict(short=brief); save()
            print(args.configuration,opt,'SHORT_EXACT_NATIVE_PASS',flush=True)
            if args.short_only: continue
            full = out/(opt+'-full')
            cuts = {2,4,365,367,530,532,1096}|set(range(120,163))
            if args.resume and result['profiles'][opt].get('days')==1096:
                report = result['profiles'][opt]; data = m.rows(full); m.check(data)
                assert len(data)==1096
            else:
                report, data = m.trajectory(build,reference,project,full,1096,cuts,60)
                report['short'] = brief; result['profiles'][opt] = report; save()
            active = [i+1 for i,row in enumerate(data) if row['external_flux_cm'][5] > 0]
            assert active and all(row['external_flux_cm'][3] == 0 for row in data)
            report['subsurface_exposure'] = dict(days=active,total_cm=sum(row['external_flux_cm'][5] for row in data))
            starts = (2,365,530)
            if 'own' not in report:
                report['own'] = [m.own(build,reference,project,full,data,start,start+2,out/(opt+'-own'+str(start))) for start in starts]
                save()
            if 'active_own' not in report:
                target = out/(opt+'-active'); target.mkdir()
                report['active_own'] = active_own(build,reference,project,full,data,target); save()
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
