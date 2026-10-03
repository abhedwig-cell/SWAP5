"""Evaluate the separately preregistered opt-in practical A28 coupled envelope."""
import json,re,sys
from pathlib import Path

exact_path,approx_path,exact_log,approx_log,out_path=map(Path,sys.argv[1:6])
exact=json.loads(exact_path.read_text());approx=json.loads(approx_path.read_text())
logs=[exact_log.read_text(),approx_log.read_text()]
assert exact['windows']==approx['windows'] and exact['dt_day']==approx['dt_day']
assert exact['h0_cm']==approx['h0_cm'] and exact['rain_cm_day']==approx['rain_cm_day']
assert len(exact['rows'])==exact['windows'] and len(approx['rows'])==approx['windows']

def trial_metrics(log):
    trials=re.findall(r'A28_FD_TRIAL .*?completed=([TF]) status=(\d+) attempts=(\d+) retries=(\d+) solver_rejections=(\d+) temporal_rejections=(\d+).*?mass_cm=\s*([+-]?[\d.]+(?:[Ee][+-]?\d+)?)',log)
    return {
        'trials':len(trials),
        'failed_trials':sum(t[0]!='T' or int(t[1])!=0 for t in trials),
        'solver_rejections':sum(int(t[4]) for t in trials),
        'temporal_rejections':sum(int(t[5]) for t in trials),
        'max_retries_per_trial':max((int(t[3]) for t in trials),default=0),
        'max_abs_trial_mass_residual_cm':max((abs(float(t[6])) for t in trials),default=0.),
        'sample_passes':len(re.findall(r'^A28_FD_SAMPLE_PASS',log,re.M)),
        'sample_failures':len(re.findall(r'^A28_FD_SAMPLE_FAIL|^A28_FD_LADDER_SAMPLE_FAIL',log,re.M)),
    }

trial=[trial_metrics(s) for s in logs]
rows=zip(exact['rows'],approx['rows'],strict=True)
rows=list(rows)
head_path=[r[0]['head_m'] for r in rows]
head_range=max([exact['reference_head_m'],*head_path])-min([exact['reference_head_m'],*head_path])
head_drift=max(abs(a['head_m']-b['head_m']) for a,b in rows)
flux_peak={k:max(abs(a[k]) for a,_ in rows) for k in ('q1','q2','qw')}
flux_drift={k:max(abs(a[k]-b[k]) for a,b in rows) for k in ('q1','q2','qw')}
flux_norm={k:(flux_drift[k]/flux_peak[k] if flux_peak[k]>0 else None) for k in flux_peak}
gross_exchange={k:sum(abs(a[k])*exact['dt_day']*86400 for a,_ in rows) for k in ('q1','q2','qw')}
cumulative_exchange_delta={k:abs(sum((a[k]-b[k])*exact['dt_day']*86400 for a,b in rows)) for k in ('q1','q2','qw')}
cumulative_exchange_norm={k:(cumulative_exchange_delta[k]/gross_exchange[k] if gross_exchange[k]>0 else None) for k in gross_exchange}
tile_ledgers={}
storage_norm={};rfm_norm={};rfm_peak_change={}
for j,key in enumerate(('q1','q2')):
    ledger_key=f'ledger{j+1}'
    gross=sum(abs(a[key])*exact['dt_day']*86400*100 for a,_ in rows)
    surface=sum(a['rain_cm_day']*exact['dt_day'] for a,_ in rows)
    tile_ledgers[ledger_key]={
        'exact_final_m':exact['rows'][-1][ledger_key],
        'a28_final_m':approx['rows'][-1][ledger_key],
        'difference_m':abs(exact['rows'][-1][ledger_key]-approx['rows'][-1][ledger_key]),
        'gross_exact_transfer_cm':gross,
        'surface_input_cm':surface,
    }
    tile_ledgers[ledger_key]['normalized_cumulative_difference']=tile_ledgers[ledger_key]['difference_m']*100/gross if gross>0 else None
    exact_storage=[];approx_storage=[];exact_rfm=[];approx_rfm=[]
    for a,b in rows:
        exact_storage.append((a['matrix'][j]-exact['initial_matrix_cm'][j])+(a['rfm'][j]-exact['initial_rfm_cm'][j]))
        approx_storage.append((b['matrix'][j]-approx['initial_matrix_cm'][j])+(b['rfm'][j]-approx['initial_rfm_cm'][j]))
        exact_rfm.append(a['rfm'][j]-exact['initial_rfm_cm'][j]);approx_rfm.append(b['rfm'][j]-approx['initial_rfm_cm'][j])
    gross_cm=gross+surface
    storage_difference=max(abs(a-b) for a,b in zip(exact_storage,approx_storage,strict=True))
    storage_norm[ledger_key]=storage_difference/gross_cm if gross_cm>0 else None
    rfm_peak_change[ledger_key]=max((abs(x) for x in exact_rfm),default=0.)
    rfm_difference=max(abs(a-b) for a,b in zip(exact_rfm,approx_rfm,strict=True))
    rfm_norm[ledger_key]=rfm_difference/rfm_peak_change[ledger_key] if rfm_peak_change[ledger_key]>0 else None

panel_counts={'64':approx['sorptivity_counts'][0],'32':approx['sorptivity_counts'][1],'16':approx['sorptivity_counts'][2]}
residual=max(abs(r['residual']) for r in exact['rows']+approx['rows'])
iteration_delta=max(b['iterations']-a['iterations'] for a,b in rows)
head_norm=head_drift/head_range if head_range>0 else None
strict_limits={'head_m':1e-12,'q1':1e-15,'q2':1e-15,'qw':1e-15,'ledger1_m':1e-12,'ledger2_m':1e-12,'matrix_cm':1e-10,'rfm_cm':1e-10}
strict_differences={
 'head_m':head_drift,
 'q1':flux_drift['q1'],'q2':flux_drift['q2'],'qw':flux_drift['qw'],
 'ledger1_m':tile_ledgers['ledger1']['difference_m'],'ledger2_m':tile_ledgers['ledger2']['difference_m'],
 'matrix_cm':max(abs(a['matrix'][j]-b['matrix'][j]) for a,b in rows for j in range(2)),
 'rfm_cm':max(abs(a['rfm'][j]-b['rfm'][j]) for a,b in rows for j in range(2)),
}
active_rfm_threshold_cm=1e-10
field_active=all(x>active_rfm_threshold_cm for x in rfm_peak_change.values())
panel_bands=sum(x>0 for x in panel_counts.values())
retry_ok=trial[0]['temporal_rejections']>0 and trial[1]['temporal_rejections']<=1.10*trial[0]['temporal_rejections']
criteria={
 'head_path_relative_to_exact_excursion':head_norm is not None and head_norm<=0.02,
 'peak_flux_differences_relative_to_exact_peak':all(v is not None and v<=0.02 for v in flux_norm.values()),
 'cumulative_exchange_relative_to_exact_gross_exchange':all(v is not None and v<=0.02 for v in cumulative_exchange_norm.values()),
 'tile_ledger_net_exchange_relative_to_exact_gross':all(v['normalized_cumulative_difference'] is not None and v['normalized_cumulative_difference']<=0.02 for v in tile_ledgers.values()),
 'matrix_plus_rfm_storage_path_relative_to_throughput':all(v is not None and v<=0.02 for v in storage_norm.values()),
 'active_rfm_storage_each_tile':field_active,
 'two_or_more_a28_panel_bands':panel_bands>=2,
 'coupling_residual_each_variant':residual<=1e-15,
 'zero_solver_rejections_and_failed_trials':all(x['solver_rejections']==0 and x['failed_trials']==0 and x['sample_failures']==0 for x in trial),
 'trial_mass_closure_each_variant':all(x['max_abs_trial_mass_residual_cm']<=1e-12 for x in trial),
 'retry_increase_at_most_10_percent':retry_ok,
 'no_coupling_iteration_regression':iteration_delta<=0,
}
output={
 'status':'PRACTICAL_PAIRED_GATE_PASS' if all(criteria.values()) else 'PRACTICAL_PAIRED_GATE_FAIL',
 'criteria':criteria,
 'windows':exact['windows'],
 'fd_trials':{'exact':trial[0],'a28':trial[1]},
 'metrics':{
   'head_excursion_m':head_range,'max_abs_head_difference_m':head_drift,'head_difference_fraction_of_excursion':head_norm,
   'peak_abs_flux_exact_m_s':flux_peak,'max_abs_flux_difference_m_s':flux_drift,'max_flux_difference_fraction_of_exact_peak':flux_norm,
   'gross_exchange_exact_m':gross_exchange,'cumulative_exchange_difference_m':cumulative_exchange_delta,'exchange_difference_fraction_of_gross_exact':cumulative_exchange_norm,
   'tile_ledger':tile_ledgers,'storage_path_difference_fraction':storage_norm,
   'rfm_peak_change_exact_cm':rfm_peak_change,'rfm_storage_difference_fraction':rfm_norm,
   'a28_panel_counts':panel_counts,'a28_total_panels':approx['panels'],'a28_consumer_head_range_cm':approx['consumer_head_range_cm'],
   'max_coupling_residual_m_s':residual,'coupling_iteration_delta_a28_minus_exact':iteration_delta,
   'execution_ratio_exact_over_a28':exact['execution_seconds']/approx['execution_seconds'],
 },
 'strict_equivalence_gate':{'status':'PASS' if all(strict_differences[k]<=strict_limits[k] for k in strict_limits) else 'FAIL','differences':strict_differences,'limits':strict_limits},
 'performance_claim':'Not admitted by this correctness-stage run; centered-FD sensitivity calibration remains outside production timing qualification.'
}
out_path.write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps(output,indent=2))
if output['status']!='PRACTICAL_PAIRED_GATE_PASS':raise SystemExit(1)
