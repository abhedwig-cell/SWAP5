"""Actual corrected fixed chemical SSDI; use existing production/native harness."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('scheduled_controls',Path(__file__).with_name('run.py'))
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
m=s.m
from fixed_irrigation_cases import create
from daily_coupling import CoupledDailyColumn,validate_bundle


def controls(build,reference,project,full,data,out,*,policy_key='conserved_subsurface_solute',policy_error='Foreign conserved subsurface solute policy'):
    out.mkdir();meta,case=validate_bundle(build,reference,project)
    foreign=out/'foreign';foreign.mkdir()
    changed=json.loads((build/'BUILD.json').read_text())
    changed['identity'][policy_key]['policy']='foreign'
    (foreign/'BUILD.json').write_text(json.dumps(changed))
    try:validate_bundle(foreign,reference,project)
    except ValueError as error:assert policy_error in str(error)
    else:raise AssertionError('Foreign chemical source accepted')
    active=next(row['day'] for row in data if row['solute_ledger_mg_cm2'][3]>0)
    first=active-1
    source=full/f'accepted-column-1-day-{first}.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'fixed-chemical',origin=source,day=first,adopt_native=True)
    trial=column.prepare();assert trial.budget['solute_ledger_mg_cm2'][3]>0
    column.discard(trial);assert column.day==first and m.sha(source)==digest
    replay=column.prepare();assert replay.budget==trial.budget
    column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'fixed-chemical',origin=column.checkpoint,day=active)
    endpoint=recovered.prepare()
    assert m.physical([{k:v for k,v in endpoint.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[active]])
    recovered.discard(endpoint)
    origin=out/'origin';receipt=m.h.verify_checkpoint(source,first,meta['binding'],origin)
    refused=out/'refused';refused.mkdir()
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,refused,
                          [m.h.ColumnStart('original',first,origin,receipt)],checkpoint_enabled=True,runtime=True,
                          binding=meta['binding'],model=project.model,project=project)
        stock=host.columns[0].solute_stock;water=host.columns[0].stocks.copy();receive=m.h.receive
        def corrupt(process,*args,**kwargs):
            disposition,response=receive(process,*args,**kwargs)
            if process is host.columns[0].worker and 'HYBRID_SOLUTE_LEDGER' in response:
                values=response['HYBRID_SOLUTE_LEDGER'].copy();values[0]=str(float(values[0])+1)
                response['HYBRID_SOLUTE_LEDGER']=values
            return disposition,response
        try:
            m.h.receive=corrupt
            try:host.step(1,checkpoint=True)
            except ValueError as error:assert 'solute candidate exceeds unchanged1e-10 mass guard' in str(error)
            else:raise AssertionError('Inconsistent active chemical source accepted')
        finally:m.h.receive=receive
        assert host.columns[0].day==first and host.columns[0].solute_stock==stock and host.columns[0].stocks==water
        assert not list(refused.glob('accepted-*.zip'))
        # A refused protocol exchange deliberately leaves the host unusable.
        # ExitStack terminates its processes; normal close is forbidden here.
    return dict(actual_irrigation_day=active,foreign_policy_refused=True,active_discard_replay_exact=True,active_disk_recovery=True,
                inconsistent_chemical_mass_refused=True,committed_state_unchanged=True,origin_unchanged=m.sha(source)==digest)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--configuration',choices=['point','interval'],required=True)
    p.add_argument('--inline',action='store_true')
    p.add_argument('--salinity',action='store_true')
    p.add_argument('--short-only',action='store_true')
    p.add_argument('--reuse-build-from',type=Path)
    p.add_argument('--resume',action='store_true')
    args=p.parse_args();out=args.output.resolve();out.mkdir(exist_ok=args.resume)
    if args.salinity and args.short_only:raise ValueError('Salinity composition requires its active growing-season event')
    reference=args.reference_work.resolve()
    if not (reference/'PREPARED.json').exists():m.user_prepare.prepare(reference)
    m.user_prepare.validate(reference)
    case=args.reuse_build_from.resolve()/'input' if args.reuse_build_from else out/'input'
    if not args.reuse_build_from and not args.resume:
        create(case,'water-file-subsurface'+('-interval' if args.configuration=='interval' else ''),inline=args.inline)
        path=case/'swap.swp';text=path.read_text(encoding='cp1252')
        for name,value in dict(SWSOLU=1,SWMONTH=0,INLIST_CSV="'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'").items():
            text=s.assignment(text,name,value)
        path.write_text(text+'\nNUM_DECIMALS = 12\n',encoding='cp1252')
        if args.salinity:
            irrigation=case/('swap.swp' if args.inline else 'fixed-irrigation.irg')
            body=irrigation.read_text(encoding='cp1252');assert '2002-01-05' in body
            irrigation.write_text(body.replace('2002-01-05','2002-05-25'),encoding='cp1252')
            for crop in case.glob('*.crp'):
                body=s.assignment(crop.read_text(encoding='cp1252'),'SWSALINITY',1)
                # Isolate the stress response: original maize compensation can
                # completely replace uptake from the saline compartment.
                body=s.assignment(body,'SWCOMPENSATE',0)
                crop.write_text(body,encoding='cp1252')
    project=m.e.load(case)
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                configuration=args.configuration,inline=args.inline,salinity=args.salinity,inputs=m.e.inspect(case),profiles={},
                chemical_guard_mg_cm2=1e-10,water_guard_cm=1e-10,science='NOT_QUALIFIED')
    if args.resume:
        previous=json.loads((out/'RESULT.json').read_text())
        assert previous['inputs']==json.loads(json.dumps(m.e.inspect(case)))
        result['retained_failure']=dict(status=previous['status'],error=previous.get('error'))
        result['original_execution_source']=previous['source_commit']
    def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            build=(args.reuse_build_from.resolve() if args.reuse_build_from else out)/(opt+'-build')
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                     '--experimental-project',str(case),'--reference-work',str(reference),'--build-only',
                     '--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            if args.reuse_build_from or (args.resume and (build/'BUILD.json').exists()):
                validate_bundle(build,reference,project)
                result['profiles'][opt]=dict(build_reused=str(build),compilation='NOT_REPEATED')
            else:
                started=time.perf_counter();run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                (out/(opt+'-build.stdout')).write_text(run.stdout);(out/(opt+'-build.stderr')).write_text(run.stderr)
                result['profiles'][opt]=dict(build_seconds=time.perf_counter()-started,returncode=run.returncode);save()
                assert run.returncode==0,run.stderr
            last=8 if args.short_only else 1096
            active_start=144 if args.salinity else 4
            full=out/(opt+'-full')
            if args.resume and (full/'daily.jsonl').exists():
                data=m.rows(full);assert len(data)==last
                report=dict(status='FULL_PASS' if last==1096 else 'SHORT_PASS',days=last,budgets=m.check(data),
                            model_seconds='UNKNOWN_RETAINED_PRIOR_EXECUTION',build_sha256=m.sha(build/'BUILD.json'))
            else:
                report,data=m.trajectory(build,reference,project,full,last,{2,4,6,active_start,active_start+2,365,367,last},60)
            water=sum(row['external_flux_cm'][5] for row in data)
            mass=sum(row['solute_ledger_mg_cm2'][3] for row in data)
            assert abs(water-2.4)<1e-12,(water,mass)
            assert abs(mass-water*20)<1e-10,(water,mass)
            report.update(irrigation_water_cm=water,irrigation_mass_mg_cm2=mass)
            if args.salinity and not args.short_only:
                reduction=sum(row['uptake_terms_cm'][4] for row in data)
                assert reduction>0,'Selected salinity coupling never active'
                report['actual_salinity_reduction_cm']=reduction
            suffix='-recovery' if args.resume else ''
            report['own']=[m.own(build,reference,project,full,data,start,start+2,out/(opt+'-own'+str(start)+suffix))
                           for start in ((2,4) if args.short_only else (2,active_start,365))]
            result['profiles'][opt].update(report);save()
            report['controls']=controls(build,reference,project,full,data,out/(opt+'-controls'+suffix))
            result['profiles'][opt].update(report);save()
            print(args.configuration,opt,'SOURCE_MASS_NATIVE_PASS',flush=True)
        result['status']='SHORT_O0_O2_PASS' if args.short_only else 'FULL_O0_O2_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
