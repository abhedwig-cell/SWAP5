"""Actual closed/Gardner source feedback with immutable original inputs and cold state."""
import argparse,hashlib,io,json,re,subprocess,sys,time,zipfile
from contextlib import ExitStack
from decimal import Decimal,localcontext
from datetime import date
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from original_output_baseline import assignment
from explicit_bottom9_runtime import m,own
from frost_boundary_convergence import require_convergence
PARENT='fa77380ecce3317775bd1129b5de007fcbcf2e1f'
P='integration/f-ci/nomacro-complete01/'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
git=lambda *args:subprocess.check_output(['git',*args],cwd=R)


def prepare(spec,output,donor=None):
    """Only the declared closed boundary/drainage selectors change."""
    output.mkdir()
    name='INITIAL_PROFILE_CALENDAR_WINDOWS_RAW_V1'
    prefix=spec['actual_original_input_prefix']
    with ExitStack() as stack:
        archive=Archive(GitArchiveSource(R,PARENT),name,stack)
        original={n[len(prefix):]:archive.get(n) for n in archive.names if n.startswith(prefix)}
        assert original and 'swap.swp' in original
        authority=dict(actual_git_source=PARENT,actual_original_scientific_producer=spec['actual_original_input_producer'],archive=name,archive_sha256=archive.record['sha256'],prefix=prefix,original_members={n:dict(bytes=len(v),sha256=SHA(v)) for n,v in original.items()})
        for n,raw in original.items():
            target=output/n;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    text=original['swap.swp'].decode('cp1252');values=dict(SWDRA=0,SWBOTB=6)
    for key,value in values.items():text=assignment(text,key,value)
    (output/'swap.swp').write_bytes(text.encode('cp1252'))
    return dict(authority=authority,additional_original_parameter_authority=None,declared_selectors=values,physical_parameter_tables_unchanged=True,current_swp_sha256=SHA((output/'swap.swp').read_bytes()))


def ledger(folder,kind,days):
    rows=[json.loads(line,parse_float=Decimal) for line in (folder/'daily.jsonl').read_text().splitlines()]
    assert len(rows)==days;water=chemical=prefix=Decimal(0);flows=[Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec=80
        for day,row in enumerate(rows,1):
            assert row['day']==day and row['committed'] is True
            a,b,f=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm']
            residual=sum(a)-sum(b)+sum(f[:7])-sum(f[7:]);water=max(water,abs(residual))
            assert abs(residual)<=Decimal('1e-10') and abs(row['kernel_residual_cm'])<=Decimal('1e-10')
            if kind=='cde':
                v=row['solute_ledger_mg_cm2'];a=row['solute_start_mg_cm2'];b=row['solute_end_mg_cm2']
                residual=b-a-sum(v[2:5])+sum(v[5:8]);chemical=max(chemical,abs(residual))
                assert abs(residual)<=Decimal('1e-10') and abs(b-v[0])<=Decimal('1e-10')
                flows=[x+y for x,y in zip(flows,v[2:8])]
                residual=b-rows[0]['solute_start_mg_cm2']-sum(flows[:3])+sum(flows[3:]);prefix=max(prefix,abs(residual));assert abs(residual)<=Decimal('1e-10')
    return dict(days=days,water_daily_max_cm=str(water),cde_daily_max_mg_cm2=str(chemical),cde_every_prefix_max_mg_cm2=str(prefix))


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-output','reference-work']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--case',required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--days',type=int,choices=[8,35],default=35);p.add_argument('--input-only',action='store_true')
    a=p.parse_args();head=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    plan=json.loads(git('show',head+':'+P+'CLOSED_INITIALIZATION_STATE15_FINITE_CASE_PLAN_V1.json'))
    spec=next(v for v in plan['cases'] if v['name']==a.case);a.output.mkdir()
    q=dict(status='RUNNING_ACTUAL_CLOSED_INITIALIZATION_CALENDAR_FEEDBACK_NOT_QUALIFIED',actual_source=head,case=a.case,specification=spec,
           optimization=a.optimization,days=a.days,input_root=str(a.output/'inputs'),build_root=str(a.build_output/'bundle'),canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        q['inputs']=prepare(spec,Path(q['input_root']))
        policy='original-adaptive-event-closure-v1' if spec['frost'] else 'original-adaptive-day-seed-v1'
        project=m.e.load(q['input_root'],original_output=True,time_step_policy=policy)
        q['input_inventory']=m.e.inventory(Path(q['input_root']));q['time_step_policy']=policy;save()
        if a.input_only:q['status']='ACTUAL_CLOSED_INITIALIZATION_CALENDAR_PUBLIC_INPUT_ACCEPTED_ZERO_MODELS';return
        build=Path(q['build_root']);cmd=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,
            '--experimental-project',q['input_root'],'--original-output','--experimental-time-step-policy',policy,
            '--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        started=time.perf_counter()
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:
            done=subprocess.run(cmd,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=cmd,returncode=done.returncode,seconds=time.perf_counter()-started);save();done.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project);q['actual_BUILD_sha256']=SHA((build/'BUILD.json').read_bytes());save()
        windows=[(2,4),(7,8)] if a.days==8 else [(2,4),(7,9),(30,34)]
        cuts={a.days,*[d for pair in windows for d in pair]}
        first=date.fromisoformat(meta['project']['start_date']);seam=(date(first.year+1,1,1)-first).days
        if 2<seam<a.days:
            pair=(max(v for v in cuts if v<seam),min(v for v in cuts if v>seam))
            q['actual_calendar_derived_year_window']=dict(start_date=str(first),new_year_offset=seam,window=pair)
            if pair not in windows:windows.append(pair)
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',a.days,cuts,240);save()
        q['independent_budgets']=ledger(a.output/'trajectory',spec['kind'],a.days)
        if spec['snow']:
            q['actual_snow_maximum_stock_cm']=max(v['stock_end_cm'][2] for v in data)
            assert q['actual_snow_maximum_stock_cm']>0
        if spec['frost']:
            from frost_undrained_state_controls import active_frost_start
            q['actual_original_Frost_active_checkpoints']=[]
            for day in sorted(cuts):
                try:witness=active_frost_start(a.output/'trajectory'/f'accepted-column-1-day-{day}.zip',project)
                except AssertionError as error:
                    if str(error)!='Transaction start has no actual original Frost-active soil temperature':raise
                else:q['actual_original_Frost_active_checkpoints'].append(dict(day=day,**witness))
            assert q['actual_original_Frost_active_checkpoints']
        q['original_convergence']=require_convergence(a.output);q['native_samples']=[]
        for day in sorted(cuts):
            with zipfile.ZipFile(a.output/'trajectory'/f'accepted-column-1-day-{day}.zip') as z:
                raw=z.read('macro.bin');receipt=json.loads(z.read('checkpoint.json'))
                assert receipt['binding']==meta['binding'] and receipt['receipt']==data[day-1]
                assert all(SHA(z.read(n))==v for n,v in receipt['files'].items())
                assert raw[:8]==m.e.auxiliary_magic(project)
                q['native_samples'].append(dict(day=day,bytes=len(raw),sha256=SHA(raw),magic=raw[:8].decode()))
        q['cold']=[]
        for lo,hi in windows:q['cold'].append(own(build,a.reference_work,project,a.output/'trajectory',data,lo,hi,a.output/('own-'+str(lo))));save()
        from cde_clock_controls import transactions
        q['external_transactions']=transactions(build,a.reference_work,project,a.output/'trajectory',a.output/'transactions')
        assert all(v is True for v in q['external_transactions'].values())
        assert git('rev-parse','HEAD').decode().strip()==head
        q['status']='ACTUAL_CLOSED_INITIALIZATION_CALENDAR_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED'
    except Exception as error:q.update(status='FAILED_ACTUAL_CLOSED_INITIALIZATION_CALENDAR_FEEDBACK_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],a.case,a.optimization,flush=True)

if __name__=='__main__':main()
