"""Active fixed gift discard/replay and actual young-water reader refusals."""
import argparse
import json
from pathlib import Path
import shutil
import age_fixed as f
from daily_coupling import CoupledDailyColumn

m=f.m


def active_metrics(rows):
    water=sum(row['external_flux_cm'][3]+row['external_flux_cm'][5] for row in rows)
    assert abs(water-2.4)<1e-11 and abs(rows[4]['external_flux_cm'][3]+rows[4]['external_flux_cm'][5]-2.4)<1e-11
    assert all(row['age_state_cm_day'][5]==0 and row['age_ledger_cm_day'][2]==0 for row in rows)
    before=rows[3]['age_state_cm_day'][0]/rows[3]['stock_end_cm'][0]
    after=rows[4]['age_state_cm_day'][0]/rows[4]['stock_end_cm'][0]
    assert before>after
    return dict(actual_fixed_irrigation_cm=water,active_day=5,external_input_age_cm_day=0.,soil_mean_age_before_day=before,soil_mean_age_after_day=after)


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();result=dict(status='RUNNING',profiles={},reader_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
            project=m.e.load(a.evidence/'inputs'/kind)
            for opt in ('O0','O2'):
                name=kind+'-'+opt;build=a.evidence/(name+'-build');full=a.evidence/(name+'-full');data=m.rows(full);target=a.output/name;target.mkdir()
                metrics=active_metrics(data);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
                column=CoupledDailyColumn(build,a.reference_work,target/'external',project,'fixed-young-age',origin=source,day=4,adopt_native=True)
                candidate=column.prepare();assert m.physical([{k:v for k,v in candidate.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[4]])
                column.discard(candidate);assert column.day==4
                replay=column.prepare();assert replay.budget==candidate.budget;column.accept(replay)
                recovered=CoupledDailyColumn(build,a.reference_work,target/'recovered',project,'fixed-young-age',origin=column.checkpoint,day=5)
                nextday=recovered.prepare();assert m.physical([{k:v for k,v in nextday.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[5]]);recovered.discard(nextday)
                assert m.sha(source)==digest
                result['profiles'][name]=dict(status='ACTIVE_FIXED_YOUNG_AGE_TRANSACTION_PASS',discard_replay_exact=True,disk_recovery_exact=True,origin_unchanged=True,metrics=metrics);save()
                # Actual original reader executes each malformed file. There is
                # no manufactured build/checkpoint identity in these controls.
                if kind not in ('surface','subsurface-interval'):continue
                for bad in ('1.0','1.0e-300','NaN','-1.0','1001.0'):
                    label=bad.replace('.','_').replace('-','m');inputs=target/('input-'+label);shutil.copytree(a.evidence/'inputs'/kind,inputs)
                    path=inputs/'fixed-irrigation.irg';text=path.read_text();assert '2002-01-05 24.0 0.0' in text;path.write_text(text.replace('2002-01-05 24.0 0.0','2002-01-05 24.0 '+bad))
                    invalid=m.e.load(inputs);out=target/('reader-'+label);out.mkdir()
                    try:m.bounded(20,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),inputs,out,1,runtime=True,model=project.model,project=invalid))
                    except (ValueError,RuntimeError) as error:
                        diagnostic='\n'.join(p.read_text(errors='replace') for pattern in ('swap.err','donor.stderr') for p in out.rglob(pattern))
                        assert any(token in diagnostic.lower() for token in ('young-water','nonfinite','irconc','nan')),(bad,diagnostic,str(error))
                        assert not list(out.glob('accepted-*.zip'));result['reader_refusals'].append(dict(profile=name,input=bad,status='REFUSED',diagnostic=diagnostic));save()
                    else:raise AssertionError('Non-young original age input accepted: '+bad)
        result['status']='FIXED_YOUNG_AGE_ACTIVE_TRANSACTIONS_AND_NATIVE_READERS_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
