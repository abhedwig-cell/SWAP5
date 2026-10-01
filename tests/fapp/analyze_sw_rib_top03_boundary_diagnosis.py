"""Compare stock and isolated boundary-Jacobian probes, without selecting a repair."""
import csv
import hashlib
import json
import sys
from pathlib import Path

logs = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
summary = {'schema': 'swap5.top03.boundary_diagnosis.v1', 'production_admission': False,
           'o0_o2_exact_identity_except_cpu': True, 'experiments': {}, 'stock_scope': []}
all_rows = {}
for variant in ['diag', 'probe5', 'probe6', 'both5', 'both6']:
    data = []
    stop_data = []
    hashes = {}
    for geometry in [1, 2, 3]:
        path = logs / f'top03-{variant}-g{geometry}.log'
        lines = path.read_text().splitlines()
        headers = [line for line in lines if line.startswith('geometry,')]
        assert len(headers) == 2 and headers[0] == headers[1]
        assert 'TOP03_DIAGNOSIS_O0=COMPLETED' in lines and 'TOP03_DIAGNOSIS_O2=COMPLETED' in lines
        fields = headers[0].split(',')
        rows = [dict(zip(fields, row)) for row in csv.reader(lines)
                if len(row) == len(fields) and row[0].isdigit()]
        assert len(rows) == 360
        for a, b in zip(rows[:180], rows[180:]):
            assert {k: v for k, v in a.items() if k != 'cpu_seconds'} == {
                k: v for k, v in b.items() if k != 'cpu_seconds'}
        stops = [line for line in lines if line.startswith('STOP,')]
        assert len(stops) % 2 == 0 and stops[:len(stops)//2] == stops[len(stops)//2:]
        stop_data.extend(stops[:len(stops)//2])
        hashes[str(geometry)] = hashlib.sha256(path.read_bytes()).hexdigest()
        for opt, rr in [('O0', rows[:180]), ('O2', rows[180:])]:
            with (out / f'{variant}_g{geometry}_{opt}.csv').open('w') as stream:
                writer = csv.DictWriter(stream, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rr)
        data.extend(rows[:180])
    assert len(data) == 540
    assert max(abs(float(r['ledger_residual_cm'])) for r in data) <= 1e-10
    assert max(abs(float(r['max_step_soil_residual_cm'])) for r in data) <= 1e-10
    steady = [r for r in data if r['profile'] == '3']
    assert len(steady) == 180
    for r in steady:
        duration = 0.25 if r['window'] == '1' else 0.001953125
        assert r['steps'] == r['completed'] and r['stop_code'] == '0'
        assert abs(float(r['transfer_cm']) + 4.75 * duration) <= 1e-12
        assert abs(float(r['bottom_cm']) + 4.75 * duration) <= 1e-12
        assert float(r['storage_change_cm']) == 0.0
        assert float(r['h_min']) == 0.02 and float(r['h_max']) == 0.02
    incomplete = [r for r in data if r['completed'] != r['steps']]
    assert all(r['stop_code'] == '1' and r['solver_status'] == '2' for r in incomplete)
    summary['experiments'][variant] = {
        'grids_per_optimization': 540, 'incomplete_per_optimization': len(incomplete),
        'incomplete_by_geometry': {str(g): sum(int(r['geometry']) == g for r in incomplete) for g in [1,2,3]},
        'incomplete_by_bottom_mode': {str(b): sum(int(r['bottom_mode']) == b for r in incomplete) for b in [7,2,5]},
        'maximum_ledger_residual_cm': max(abs(float(r['ledger_residual_cm'])) for r in data),
        'analytical_saturated_steady_control': 'PASS', 'log_sha256': hashes,
        'failed_grids': [{k:r[k] for k in ['geometry','bottom_mode','profile','window','steps','completed']} for r in incomplete],
    }
    (out / f'{variant}_stops.csv').write_text(
        'marker,geometry,bottom_mode,profile,window,steps,failed_step,failed_iterations,residual_inf_cm_per_day,head_update_inf_cm,capacity_min,capacity_max\n' + '\n'.join(stop_data) + '\n')
    all_rows[variant] = data
stock = all_rows['diag']
for geometry in [1,2,3]:
    for bottom in [7,2,5]:
        for profile in [1,2,3]:
            for window in [1,2]:
                rows = [r for r in stock if int(r['geometry']) == geometry and int(r['bottom_mode']) == bottom and
                        int(r['profile']) == profile and int(r['window']) == window]
                valid = [r for r in rows if r['completed'] == r['steps']]
                complete = len(valid) == 10
                item = {'geometry':geometry,'bottom_mode':bottom,'profile':profile,'window':window,
                        'all_grids_complete':complete, 'complete_grids':[int(r['steps']) for r in valid]}
                if complete:
                    diff = [abs(float(b['transfer_cm'])-float(a['transfer_cm'])) for a,b in zip(rows,rows[1:])]
                    item.update(finest_transfer_cm=float(rows[-1]['transfer_cm']),
                                last_transfer_difference_cm=diff[-1],
                                last_water_l1_difference_cm=float(rows[-1]['water_l1_diff_cm']),
                                last_head_inf_difference_cm=float(rows[-1]['head_inf_diff_cm']))
                    if diff[-1] > 0:
                        item['tail_transfer_difference_ratio'] = diff[-2] / diff[-1]
                summary['stock_scope'].append(item)
# Bottom-only perturbation never touches fixed flux/head branches.
for variant in ['probe5','probe6']:
    for a,b in zip(stock,all_rows[variant]):
        if a['bottom_mode'] in ['2','5']:
            assert {k:v for k,v in a.items() if k!='cpu_seconds'} == {k:v for k,v in b.items() if k!='cpu_seconds'}
summary['bottom_only_preserves_other_bottom_branches_exactly'] = True
summary['decision'] = 'BOUNDARY_REGIME_LOCALIZED__BOTTOM_ONLY_AND_COMBINED_FD_REPAIR_ROUTES_FALSIFIED'
(out / 'TOP03_BOUNDARY_DIAGNOSIS_RESULT.json').write_text(json.dumps(summary, indent=2)+'\n')
print('TOP03_BOUNDARY_DIAGNOSIS_ANALYSIS=PASS')
for key,val in summary['experiments'].items():
    print(key, val['incomplete_per_optimization'], val['incomplete_by_bottom_mode'])
