"""Aquifer candidate refusal, actual external transactions and private origins."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('aquifer_runs',Path(__file__).with_name('aquifer.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m
from daily_coupling import CoupledDailyColumn


def controls(build,reference,project,full,out):
    out.mkdir();meta,case=m.validate_bundle(build,reference,project);data=m.rows(full)
    first=199;source=full/f'accepted-column-1-day-{first}.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'aquifer',origin=source,day=first,adopt_native=True)
    trial=column.prepare();assert trial.budget['aquifer_state']!=data[first-1]['aquifer_state']
    column.discard(trial);assert column.day==first
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'aquifer',origin=column.checkpoint,day=first+1)
    endpoint=recovered.prepare()
    assert m.physical([{k:v for k,v in endpoint.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[first+1]])
    for field in ('aquifer_state','aquifer_ledger_mg_cm2','soil_aquifer_residual_mg_cm2'):
        assert endpoint.budget[field]==data[first+1][field]
    recovered.discard(endpoint)
    checks=[]
    for attack in ('concentration','capacity','stock','transfer','surface','decay','nonfinite','negative-count'):
        target=out/attack;target.mkdir();origin=out/(attack+'-origin')
        receipt=m.h.verify_checkpoint(source,first,meta['binding'],origin)
        with contextlib.ExitStack() as stack:
            host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                [m.h.ColumnStart('original',first,origin,receipt)],runtime=True,checkpoint_enabled=True,
                binding=meta['binding'],model=project.model,project=project)
            col=host.columns[0];before=(col.day,col.solute_stock,col.stocks.copy(),col.aquifer_state.copy());receive=m.h.receive
            def corrupt(process,*args,**kwargs):
                disposition,response=receive(process,*args,**kwargs)
                if process is col.worker and 'HYBRID_AQUIFER_CUMULATIVE' in response:
                    values=response['HYBRID_AQUIFER_CUMULATIVE'].copy()
                    index={'concentration':0,'capacity':1,'stock':2,'transfer':3,'surface':4,'decay':5,'nonfinite':0,'negative-count':6}[attack]
                    values[index]='NaN' if attack=='nonfinite' else '-1' if attack=='negative-count' else str(float(values[index])+1)
                    response['HYBRID_AQUIFER_CUMULATIVE']=values
                return disposition,response
            try:
                m.h.receive=corrupt
                try:host.step(1,checkpoint=True)
                except ValueError as error:
                    assert 'aquifer' in str(error).lower(),str(error)
                    checks.append(dict(attack=attack,refused=True,error=str(error)))
                else:raise AssertionError('Corrupted aquifer accepted: '+attack)
            finally:m.h.receive=receive
            assert before==(col.day,col.solute_stock,col.stocks,col.aquifer_state)
            assert not list(target.glob('accepted-*.zip'))
    # Two independent native states alternate in the same real host.
    target=out/'independent';target.mkdir();starts=[199,530];origins=[]
    for index,start in enumerate(starts):
        origin=target/('origin'+str(index));receipt=m.h.verify_checkpoint(full/f'accepted-column-1-day-{start}.zip',start,meta['binding'],origin)
        origins.append(m.h.ColumnStart('original',start,origin,receipt,name='column'+str(index)))
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
            origins,runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        for turn in range(3):
            for column,start in enumerate(starts,1):
                actual=host.step(column);expected=data[start+turn]
                assert m.physical([actual])==m.physical([expected])
                assert actual['aquifer_state']==expected['aquifer_state']
        host.close()
    assert m.sha(source)==digest
    return dict(status='AQUIFER_TRANSACTIONS_REFUSALS_INDEPENDENT_ORIGINS_PASS',checks=checks,
                discard_replay_exact=True,disk_recovery_exact=True,committed_state_unchanged=True,
                independent_steps=6,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--input-root',type=Path,required=True);p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir();result={}
    for opt in ('O0','O2'):
        key='sorption-decay-'+opt
        result[opt]=controls(a.evidence/(key+'-build'),a.reference_work,m.e.load(a.input_root/'sorption-decay'),a.evidence/(key+'-full'),a.output/opt)
        (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(opt,result[opt]['status'],flush=True)


if __name__=='__main__':main()
