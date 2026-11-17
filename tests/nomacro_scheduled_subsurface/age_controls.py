"""Active pond/age transactions, candidate refusal and independent origins."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('age_runtime',Path(__file__).with_name('age_runtime.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m
from daily_coupling import CoupledDailyColumn


def controls(build,reference,project,full,out):
    out.mkdir();meta,case=m.validate_bundle(build,reference,project);data=m.rows(full)
    source=full/'accepted-column-1-day-365.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'original-age',origin=source,day=365,adopt_native=True)
    column.accept(column.prepare())
    trial=column.prepare();assert trial.budget['age_ledger_cm_day'][1]>0 and trial.budget['age_ledger_cm_day'][7]>0
    column.discard(trial);assert column.day==366
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-age',origin=column.checkpoint,day=367)
    endpoint=recovered.prepare();assert endpoint.budget['age_ledger_cm_day'][1]>0
    assert m.physical([{k:v for k,v in endpoint.budget.items() if k!='candidate_only'}|{'committed':True}])==m.physical([data[367]])
    recovered.discard(endpoint)
    foreign=out/'foreign';foreign.mkdir();changed=json.loads((build/'BUILD.json').read_text())
    changed['identity']['conserved_original_age']['policy']='foreign'
    (foreign/'BUILD.json').write_text(json.dumps(changed))
    try:m.validate_bundle(foreign,reference,project)
    except ValueError as error:assert 'Foreign original age source/state policy' in str(error)
    else:raise AssertionError('Foreign age policy accepted')
    attacks={'soil-stock':0,'pond-stock':1,'total-stock':2,'soil-production':3,'pond-production':4,
             'external-input':5,'drainage':6,'bottom':7,'root':8,'runoff':9,'internal-infiltration':10,'nonfinite':0,
             'effluent-mean':19,'effluent-negative-volume':3,'effluent-nonfinite':11,'effluent-orphan':8}
    checks=[];active=full/'accepted-column-1-day-367.zip';active_digest=m.sha(active)
    for attack,index in attacks.items():
        target=out/attack;target.mkdir();origin=out/(attack+'-origin')
        receipt=m.h.verify_checkpoint(active,367,meta['binding'],origin)
        with contextlib.ExitStack() as stack:
            host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                [m.h.ColumnStart('original',367,origin,receipt)],runtime=True,checkpoint_enabled=True,
                binding=meta['binding'],model=project.model,project=project)
            col=host.columns[0];before=(col.day,col.stocks.copy(),col.age_state.copy(),col.age_effluent.copy());receive=m.h.receive
            def corrupt(process,*args,**kwargs):
                disposition,response=receive(process,*args,**kwargs)
                key='HYBRID_AGE_EFFLUENT' if attack.startswith('effluent') else 'HYBRID_AGE_CUMULATIVE'
                if process is col.worker and key in response:
                    values=response[key].copy()
                    values[index]='NaN' if 'nonfinite' in attack else '-1' if attack=='effluent-negative-volume' else str(float(values[index])+1)
                    response[key]=values
                return disposition,response
            try:
                m.h.receive=corrupt
                try:host.step(1,checkpoint=True)
                except ValueError as error:
                    assert 'age' in str(error).lower(),str(error);checks.append(dict(attack=attack,status='REFUSED',error=str(error)))
                else:raise AssertionError('Inconsistent age accepted: '+attack)
            finally:m.h.receive=receive
            assert before==(col.day,col.stocks,col.age_state,col.age_effluent)
            assert not list(target.glob('accepted-*.zip'))
    target=out/'independent';target.mkdir();starts=[365,530];origins=[]
    for index,start in enumerate(starts):
        origin=target/('origin'+str(index));receipt=m.h.verify_checkpoint(full/f'accepted-column-1-day-{start}.zip',start,meta['binding'],origin)
        origins.append(m.h.ColumnStart('original',start,origin,receipt,name='column'+str(index)))
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
            origins,runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        for turn in range(3):
            for column,start in enumerate(starts,1):assert m.physical([host.step(column)])==m.physical([data[start+turn]])
        host.close()
    assert m.sha(source)==digest and m.sha(active)==active_digest
    return dict(status='ORIGINAL_AGE_ACTIVE_POND_TRANSACTIONS_REFUSALS_AND_ORIGINS_PASS',checks=checks,
                active_pond_day=367,discard_replay_exact=True,disk_recovery_exact=True,
                independent_steps=6,committed_state_unchanged=True,origins_unchanged=True,foreign_policy_refused=True)


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','input-root','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();result={}
    for opt in ('O0','O2'):
        result[opt]=controls(a.evidence/('100-'+opt+'-build'),a.reference_work,m.e.load(a.input_root/'100'),a.evidence/('100-'+opt+'-full'),a.output/opt)
        (a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(opt,result[opt]['status'],flush=True)


if __name__=='__main__':main()
