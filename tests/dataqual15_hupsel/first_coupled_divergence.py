"""Locate the first coupled Hupsel differences from retained complete trajectories.

Archive verification remains owned by verify_sprint03.py and verify_union_c3_hupsel.py.
This consumer recomputes first detections and first crossings of the UNCHANGED
frozen scientific limits. A supplementary native search experiment is diagnostic
only and does not replace the failed full-period qualification.
"""
import argparse,collections,csv,hashlib,io,json,math,tarfile
from pathlib import Path
from scientific_followup import ROOT,native_data,rows

CAP=ROOT/'integration/dataqual15_hupsel/SPRINT03_SCIENCE_EVIDENCE.tar.xz'

def daily_budget(path):
    grouped=collections.defaultdict(list)
    for r in rows(path.read_bytes()):
        grouped[int(math.ceil(float(r['t1_day'])-1e-9))].append(r)
    result=[]
    for day,parts in sorted(grouped.items()):
        assert float(parts[0]['t0_day'])==day-1 and float(parts[-1]['t1_day'])==day
        for a,b in zip(parts,parts[1:]):assert a['t1_day']==b['t0_day']
        r={k:math.fsum(float(p[k])for p in parts)for k in parts[0]if k not in ['window','t0_day','t1_day']}
        r['day']=day
        for key in ['water_start_cm','solute_start_mg_cm2']:r[key]=float(parts[0][key])
        for key in ['water_end_cm','solute_end_mg_cm2']:r[key]=float(parts[-1][key])
        result.append(r)
    return result

def analyze(experiment=None,baseline=None):
    native,crop,points,control,accounting,swp=native_data()
    with tarfile.open(CAP)as t:
        read=lambda n:rows(t.extractfile(n).read())
        literal=read('science/dtmax-0.04/result_output.csv')
        fine=read('original/dtmax-0.0003125/result_output.csv')
        prior=read('original/dtmax-0.000625/result_output.csv')
        bounds=json.loads(t.extractfile('science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json').read())
    assert literal==control
    out=dict(status='FIRST_COUPLED_DIFFERENCES_MEASURED_NOT_WHOLE_SCIENCE_PASS',
        full_native_days=1096,scientific_equivalence=False,production_changed=False,
        archive_sha256=hashlib.sha256(CAP.read_bytes()).hexdigest(),
        finest_reference_dtmax_day=.0003125,unchanged_frozen_limits=True,fields={})
    mapping={'water_global':('water_end_cm',None),'drainage':('drainage_cm','DRN'),
        'actual_transpiration':('actual_transpiration_cm','TACT'),
        'potential_transpiration':('potential_transpiration_cm','TPOT'),
        'oxygen':('oxygen_reduction_cm','TREDWET'),'drought':('drought_reduction_cm','TREDDRY')}
    def ref(r,key):return math.fsum(float(r[k])for k in ['WTOT','PD_VOL','IC_VOL'])if key is None else float(r[key])
    def record(series,key,donor_key):
        observations=[dict(day=int(r['day']),native=float(r[key]),reference=ref(fine[int(r['day'])],donor_key),
            difference=float(r[key])-ref(fine[int(r['day'])],donor_key),
            last_reference_refinement=ref(prior[int(r['day'])],donor_key)-ref(fine[int(r['day'])],donor_key))for r in series]
        return observations
    def summarize(observations,bound):
        first=lambda limit:next((r for r in observations if abs(r['difference'])>limit),None)
        return dict(floor=bound['floor'],frozen_limit=bound['limit'],
            first_above_printing_floor=first(bound['floor']),first_outside_frozen_limit=first(bound['limit']))
    for field,(n,d)in mapping.items():out['fields'][field]=summarize(record(native,n,d),bounds[field])
    for n in ['wrt','wlv','wst','wso','lai','rd','dvs','tsum','pwrt','pwlv','pwst','pwso','rdpot']:
        active=[r for r in crop if float(fine[int(r['day'])]['DVS'])>=0 and int(r['day'])>=524]
        field='crop_'+n;out['fields'][field]=summarize(record(active,n,n.upper()),bounds[field])
    days=[1,120,494,523,524,525,526,527,528,530,537,538,566,583,584,591,1096]
    out['selected_daily_observations']={field:[r for r in record(native,n,d)if r['day']in days]for field,(n,d)in mapping.items()}
    if experiment:
        run=json.loads((experiment/'RESULT.json').read_text())
        assert run['returncode']==0 and not run['censored']and run['completed_days']>=538
        diag=daily_budget(experiment/'budget.csv');dcrop=rows((experiment/'crop.csv').read_bytes())
        first=diag[0]['day'];last=diag[-1]['day']
        assert diag[0]==native[first-1], 'Search-only experiment must retain pre-crop hydrology exactly'
        assert diag[:max(0,524-first)]==native[first-1:523], 'First cause must precede its intervention'
        if baseline:
            assert daily_budget(baseline/'budget.csv')==native[first-1:last], 'Paired baseline changed historical trajectory'
            assert rows((baseline/'crop.csv').read_bytes())==[r for r in crop if first<=int(r['day'])<=last]
            assert (baseline/'checkpoint-523.bin').read_bytes()==(experiment/'checkpoint-523.bin').read_bytes(), 'Common accepted pre-growth state differs'
        out['search_only_experiment']=dict(status='COUPLED_SEARCH_CONTROL_NOT_PRODUCTION_ADMISSION',
            completed_days=run['completed_days'],seconds=run['seconds'],
            no_checkpoint_rebinding=not any(v not in ['-'] for v in run['command'][2:3]),
            maximum_water_residual_cm=run['maximum_water_residual_cm'],
            maximum_solute_residual_mg_cm2=run['maximum_solute_residual_mg_cm2'],
            prefix_through523_daily_budgets_exact=True,first_day=first,last_day=last,common_pre_growth_checkpoint_exact=bool(baseline),fields={})
        for field,(n,d)in mapping.items():
            observations=record(diag,n,d);base=record(native[first-1:last],n,d)
            out['search_only_experiment']['fields'][field]=dict(
                day524=next(r for r in observations if r['day']==524),
                maximum_524_538_error=max(abs(r['difference'])for r in observations if 524<=r['day']<=538),
                baseline_maximum_524_538_error=max(abs(r['difference'])for r in base if 524<=r['day']<=538))
        for n in ['wrt','wlv','wst','wso','lai','rd']:
            observations=record([r for r in dcrop if int(r['day'])>=524],n,n.upper())
            base=record([r for r in crop if 524<=int(r['day'])<=538],n,n.upper())
            out['search_only_experiment']['fields']['crop_'+n]=dict(day524=observations[0],
                maximum_524_538_error=max(abs(r['difference'])for r in observations),
                baseline_maximum_524_538_error=max(abs(r['difference'])for r in base))
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--experiment',type=Path);p.add_argument('--baseline',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=analyze(a.experiment,a.baseline);a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['fields'],indent=2))
