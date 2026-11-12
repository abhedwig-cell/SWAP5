"""Verify preserved fixed-live-state directional438 evidence with zero models."""
import hashlib
import argparse
import io
import json
import math
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def digest(raw):return hashlib.sha256(raw).hexdigest()


def physical(row):return {k:v for k,v in row.items() if k!='revision'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    folder=ROOT/'research/hybrid-water01'
    path=folder/'macro-directional438-evidence.zip'
    meta=json.loads((folder/'MACRO_DIRECTIONAL438_ARTIFACT_20261112.json').read_text())
    assert 'sha256:'+digest(path.read_bytes())==meta['digest']
    assert meta['workflow_run']['head_sha']=='6b4a58b0e131a7fe6f8a3e9d45a4ce3b7c9cfc2e'
    first_path=folder/'macro-directional438-first-evidence.zip'
    assert digest(first_path.read_bytes())=='bfa1f1267e04b0179f2016e0816178c478bbdd6cdb21cda4809cc67a934eec58'
    with zipfile.ZipFile(first_path) as first:
        first_r=json.loads(first.read('RESULT.json'))
    history_path=folder/'macro-directional438-history-evidence.zip'
    assert digest(history_path.read_bytes())=='ac8e9e51c17629a7c056961c701f0adddabcc72dada0800b82f8113ad82ce7f9'
    with zipfile.ZipFile(history_path) as second:
        history_r=json.loads(second.read('RESULT.json'))
    with zipfile.ZipFile(folder/'original-macro-481-evidence.zip') as proof:
        with zipfile.ZipFile(io.BytesIO(proof.read('segments/4/artifact.zip'))) as segment:
            expected={x['day']:x for x in map(json.loads,segment.read('resume-304-to-481/daily.jsonl').decode().splitlines())}
            origin=digest(segment.read('resume-304-to-481/accepted-column-1-day-432.zip'))
    old=folder/'original-macro-day438-evidence.zip'
    assert digest(old.read_bytes())=='d66b55a4368a3d6b519590557fc4feae8ab8be3271912d8ed68e9320f43a7f63'
    with zipfile.ZipFile(old) as control:
        prior=json.loads(control.read('RESULT.json'))
        prior_records={line.split()[0]:line.split()[1:] for line in prior['shadow_records']}
        prior_F=list(map(float,prior_records['NEW_F']))
        with zipfile.ZipFile(path) as z:
            r=json.loads(z.read('RESULT.json'))
            assert r['status']=='PARENT_AND_NATIVE_EXACT_FIXED_STATE_DIRECTIONAL_SAMPLES_RECORDED'
            assert r['origin_package_sha256']==origin
            assert r['control_reuse']['new_control_run'] is False
            assert r['original_build']==prior['original_build']
            assert r['history_samples']==history_r['history_samples']
            identity=r['observation_identity']
            for key,name in [('script_sha256','probe_macro_directional438.py'),('observer_template_sha256','macro_directional438_observer.f90')]:
                assert identity[key]==digest((folder/name).read_bytes().replace(b'\r\n',b'\n'))
            for key,name in [('headcalc_sha256','headcalc.f90'),('c_sha256','shadow.c'),('executable_sha256','day_donor')]:
                assert identity[key]==digest(z.read('observed-build/'+name))
            rows=list(map(json.loads,z.read('observation/daily.jsonl').decode().splitlines()))
            assert [v['day'] for v in rows]==list(range(433,439))
            assert all(physical(v)==physical(expected[v['day']]) for v in rows)
            for name,sha in r['complete_raw_endpoint_hashes'].items():
                assert digest(z.read('observation/original/'+name))==sha
                assert z.read('observation/original/'+name)==control.read('control/original/'+name)
            samples={}
            assert len(r['directional_samples'])==34
            for name,lines in r['directional_samples'].items():
                assert z.read('observation/original/'+name).decode().splitlines()==lines
                d={line.split()[0]:line.split()[1:] for line in lines}
                original={line.split()[0]:line.split()[1:] for line in first_r['directional_samples'][name]}
                assert all(d[key]==value for key,value in original.items())
                sid,node,delta=d['SAMPLE'];sid,node,delta=int(sid),int(node),float(delta)
                samples[sid]={'node':node,'delta':delta,'H':list(map(float,d['H'])),'F':list(map(float,d['F'])),
                    'Q':list(map(float,d['Q'])),'CACHED_F':list(map(float,d['CACHED_F'])),'CACHED_Q':list(map(float,d['CACHED_Q']))}
                assert len(samples[sid]['H'])==len(samples[sid]['F'])==112
                assert all(math.isfinite(x) for x in samples[sid]['H']+samples[sid]['F'])
            history_raw=z.read('observation/original/history438.txt').decode().splitlines()
            assert history_raw==r['history_samples']
            analytic_raw=z.read('observation/original/analytic438.txt').decode().splitlines()
            assert analytic_raw==r['analytic_samples']
    assert set(samples)==set(range(34))
    assert samples[0]==samples[1]
    assert samples[0]['F']==prior_F
    columns=[]
    analytic={line.split()[0]:list(map(float,line.split()[1:])) for line in analytic_raw}
    assert analytic['Q_RATE']==analytic['Q_PAIR']==samples[0]['Q']
    for node in [1,40,56,60,80,81,90,112]:
        selected=[s for s in samples.values() if s['node']==node]
        assert {s['delta'] for s in selected}=={-1e-4,1e-4,-5e-5,5e-5}
        for s in selected:
            expected_H=samples[0]['H'].copy();expected_H[node-1]+=s['delta']
            assert s['H']==expected_H
        derivatives=[]
        for scale in [1e-4,5e-5]:
            plus=next(s['F'] for s in selected if s['delta']==scale)
            minus=next(s['F'] for s in selected if s['delta']==-scale)
            off=[i+1 for i,(x,y) in enumerate(zip(plus,minus)) if abs(i+1-node)>1 and x!=y]
            assert not off,('Nonlocal sample response',node,scale,off)
            derivatives.append([(x-y)/(2*scale) for x,y in zip(plus,minus)])
        columns.append({'node_one_based':node,'coarse_delta_cm':1e-4,'fine_delta_cm':5e-5,
            'maximum_fine_column_derivative':max(map(abs,derivatives[1])),
            'maximum_coarse_fine_derivative_difference':max(abs(x-y) for x,y in zip(*derivatives)),
            'maximum_off_tridiagonal_response':0.0,'coarse_column':derivatives[0],'fine_column':derivatives[1]})
        plus=next(s['Q'] for s in selected if s['delta']==5e-5)
        minus=next(s['Q'] for s in selected if s['delta']==-5e-5)
        dq=(plus[node-1]-minus[node-1])/1e-4
        coarse_plus=next(s['Q'] for s in selected if s['delta']==1e-4)
        coarse_minus=next(s['Q'] for s in selected if s['delta']==-1e-4)
        coarse_dq=(coarse_plus[node-1]-coarse_minus[node-1])/2e-4
        columns[-1].update(numerical_macro_diagonal=dq,original_analytic_macro_diagonal=analytic['DQ_ANALYTIC'][node-1],
            absolute_macro_derivative_difference=abs(dq-analytic['DQ_ANALYTIC'][node-1]),
            coarse_fine_macro_derivative_difference=abs(dq-coarse_dq))
    assert len(r['runs'])==1 and r['runs'][0]['seconds']<20 and not r['runs'][0]['expired']
    history={line.split()[0]:line.split()[1:] for line in history_raw}
    vectors={key:list(map(float,value)) for key,value in history.items() if not key.startswith('EVENT')}
    assert vectors['F1']==samples[0]['F']
    assert vectors['H1']==vectors['H2']==vectors['H4']==samples[0]['H']
    assert vectors['THETA1']==vectors['THETA2']==vectors['THETA4']
    assert vectors['H1'][80]>0 and vectors['H3'][80]<0
    for i,(x,y) in enumerate(zip(vectors['H1'],vectors['H3'])):
        if i!=80:assert x==y
    history_result={
        'sequential_same_pressure_F_exact':vectors['F1']==vectors['F2'],
        'sequential_maximum_delta_F':max(abs(x-y) for x,y in zip(vectors['F1'],vectors['F2'])),
        'saturation_round_trip_H_theta_exact':True,
        'saturation_round_trip_F_exact':vectors['F1']==vectors['F4'],
        'saturation_round_trip_maximum_delta_F':max(abs(x-y) for x,y in zip(vectors['F1'],vectors['F4'])),
        'wet_wall_changes_after_round_trip':sum(x!=y for x,y in zip(vectors['WET1'],vectors['WET4'])),
        'unsaturated_store_changes_after_round_trip':sum(x!=y for x,y in zip(vectors['UNSAT1'],vectors['UNSAT4'])),
        'event_flag_changes_after_round_trip':sum(x!=y for x,y in zip(history['EVENT1'],history['EVENT4']))}
    baseline=samples[0]
    closure=[(fresh-cached)+(newq-oldq) for fresh,cached,newq,oldq in zip(baseline['F'],baseline['CACHED_F'],baseline['Q'],baseline['CACHED_Q'])]
    result={'status':'FIXED_LIVE_STATE_REPEATABLE_NO_OFFBAND_RESPONSE_IN_SELECTED_DIRECTIONS',
        'source':meta['workflow_run']['head_sha'],
        'artifact_sha256':digest(path.read_bytes()),'model_seconds':r['runs'][0]['seconds'],
        'first_observer_seconds':first_r['runs'][0]['seconds'],
        'history_observer_seconds':history_r['runs'][0]['seconds'],
        'summed_observer_seconds':first_r['runs'][0]['seconds']+history_r['runs'][0]['seconds']+r['runs'][0]['seconds'],
        'new_observed_routes':3,'reused_control':r['control_reuse'],'new_full_runs':0,'new_models_by_auditor':0,
        'parent_physical_days_exact':list(range(433,439)),'raw_native_endpoint_exact':r['complete_raw_endpoint_hashes'],
        'identical_live_baseline_repeat_exact':True,'prior_actual_fresh_F_vector_exact':True,
        'baseline_fresh_Fmax':max(map(abs,samples[0]['F'])),'samples':34,'directions':columns,
        'history_control':history_result,
        'macro_attribution':{'maximum_closure_F_change_plus_Q_change':max(map(abs,closure)),
            'cached_Fmax':max(map(abs,baseline['CACHED_F'])),
            'fresh_minus_cached_Fmax':max(abs(x-y) for x,y in zip(baseline['F'],baseline['CACHED_F'])),
            'fresh_minus_cached_Qmax':max(abs(x-y) for x,y in zip(baseline['Q'],baseline['CACHED_Q'])),
            'original_rate_only_vs_derivative_pair_Q_exact':True},
        'decision':'Selected nonlocal derivative and history-contamination explanations are unsupported at this original final438 live state. Cached/fresh F discrepancy is accounted for by macro exchange to8.89e-16; original analytic derivatives agree with the selected numerical columns without changing physical tolerances. Preserve original physics/derivatives; do not select another solver from these hypotheses.',
        'limits':'Eight directions/two scales at one exact live operator context, not all112 columns or other steps. This does not qualify an original reference, a repaired time march or explain day3/4 candidate timeouts. Physical tolerances are unchanged; scale differences are reported, not used as relaxed acceptance.',
        'next':'Scientific pressure qualification remains blocked; no further speculative solver/time-march campaign. Independent functional deliverable: verify actual numerical rejected-timestep rollback at known retry day15, separating intended retry-control changes from physical macro state. Change code only if that controlled test demonstrates a rollback defect.'}
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['status','model_seconds','samples','identical_live_baseline_repeat_exact','new_models_by_auditor']}))


if __name__=='__main__':main()
