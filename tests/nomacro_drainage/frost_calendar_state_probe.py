"""Actual short Frost calendar month seam and original exact cold/output control."""
import argparse,json,math,subprocess,sys
from decimal import Decimal,localcontext
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from explicit_bottom9_runtime import m,own
from frost_calendar_output import metadata
from original_output_files import records


def budgets(folder,kind,expected_days):
    rows=[json.loads(line,parse_float=Decimal) for line in (folder/'daily.jsonl').read_text().splitlines()]
    assert len(rows)==expected_days;water=Decimal(0);chemical=Decimal(0);prefix_max=Decimal(0);flows=[Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec=80
        for day,row in enumerate(rows,1):
            assert row['day']==day and row['committed'] is True
            before,after,flow=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm']
            residual=sum(before)-sum(after)+sum(flow[:7])-sum(flow[7:]);water=max(water,abs(residual))
            assert abs(residual)<=Decimal('1e-10') and abs(row['kernel_residual_cm'])<=Decimal('1e-10')
            if kind=='cde':
                ledger=row['solute_ledger_mg_cm2'];start=row['solute_start_mg_cm2'];end=row['solute_end_mg_cm2']
                residual=end-start-sum(ledger[2:5])+sum(ledger[5:8]);chemical=max(chemical,abs(residual))
                assert abs(residual)<=Decimal('1e-10') and abs(end-ledger[0])<=Decimal('1e-10')
                flows=[a+b for a,b in zip(flows,ledger[2:8])];prefix=end-rows[0]['solute_start_mg_cm2']-sum(flows[:3])+sum(flows[3:]);prefix_max=max(prefix_max,abs(prefix));assert abs(prefix)<=Decimal('1e-10')
    witness=[list(map(float,line.split()[1:])) for line in (folder/'original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_FROST_WITNESS ')]
    candidates=[folder/'original/result_output.bin',folder/'original/result_output.csv']
    output=next((path for path in candidates if path.is_file()),None)
    assert output is not None,'Short calendar witness audit requires actual original CSV/binary output'
    events=records(output);assert len(witness)==len(events)
    assert all(len(value)==6 and all(map(math.isfinite,value)) for value in witness)
    assert all(value[-1]==1 for value in witness[1:])
    stamp=lambda row:row[:19].decode('ascii').strip() if isinstance(row,bytes) else row.split(',')[0].strip()
    return dict(days=expected_days,daily_water_max_cm=str(water),daily_cde_max_mg_cm2=str(chemical),every_prefix_cde_max_mg_cm2=str(prefix_max),actual_frost_output_events=len(events),actual_partial_frost_output_dates=[stamp(event) for event,value in zip(events,witness) if 0<value[0]<1],accumulated_water_equivalence_claimed=False)


def main():
    p=argparse.ArgumentParser()
    for name in ('build-record','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--days',type=int,default=6);a=p.parse_args();assert a.days>=6;a.output.mkdir()
    report=json.loads(a.build_record.read_text());assert report['returncode']==0
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    head=git('rev-parse','HEAD').decode().strip();assert not git('diff',report['actual_source'],head,'--','app','src','tools','reference')
    project=m.e.load(report['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1');build=Path(report['build_root']);m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING_ACTUAL_FROST_CALENDAR_SHORT_PROBE_NOT_QUALIFIED',actual_controller_source=head,actual_compiler_source=report['actual_source'],actual_build_root=str(build),input_root=report['input_root'],output=metadata(project),compiler_executions=0,model_periods_replayed_from_parent=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',a.days,{2,4,a.days},120);save()
        q['own']=own(build,a.reference_work,project,a.output/'trajectory',data,2,a.days,a.output/'own-2');save()
        q['independent_short_budgets']=budgets(a.output/'trajectory','cde' if project.solute else 'water',a.days)
        assert git('rev-parse','HEAD').decode().strip()==head
        q['status']='ACTUAL_FROST_CALENDAR_SHORT_ORIGINAL_BUDGETS_EXACT_NATIVE_COLD_AND_USER_OUTPUT_PASS_NOT_QUALIFIED'
    except Exception as error:q.update(status='FAILED_ACTUAL_FROST_CALENDAR_SHORT_PROBE_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
