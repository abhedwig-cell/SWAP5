#!/usr/bin/env python3
"""Record complete versions and the positive local vegetation delta, using native ledgers."""
import argparse
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path


def read_csv(path):
    return {r['cell_id']: r for r in csv.DictReader(path.open())}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path)
    args=p.parse_args();root=args.root
    accepted={'SUCCESS','COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG'}
    summaries={};hashes={}
    def digest(path):
        path=path.resolve()
        if path not in hashes:hashes[path]=hashlib.sha256(path.read_bytes()).hexdigest()
        return hashes[path]
    for name in ('model','heath_variant','model_european','model_local'):
        folder=root/name;rows=read_csv(folder/'cell_register.csv');statuses=Counter()
        for identity in rows:
            case=folder/'cells'/identity
            m=json.loads((case/'cell_manifest.json').read_text())
            r=json.loads((case/'run_receipt.json').read_text())
            assert r['status'] in accepted,(name,identity,r['status'])
            assert r['returncode']==100
            assert r['input_sha256']==m['input_sha256']
            assert all(digest(case/key)==val for key,val in r['input_sha256'].items())
            statuses[r['status']]+=1
            if name=='heath_variant':
                parent=root/'model/cells'/identity
                assert (case/'swap.swp').read_bytes()==(parent/'swap.swp').read_bytes()
        summaries[name]=dict(cells=len(rows),status_counts=dict(statuses),all_selected_cases_complete=True,
                             scope='229-cell vegetation delta' if name=='heath_variant' else '4096-cell full regional grid',
                             full_grid_complete=len(rows)==4096)
    common=read_csv(root/'exports_european/cell_period_balances.csv')
    local=read_csv(root/'exports_local/cell_period_balances.csv')
    changed=[];fields=('TACT_mm','TPOT_mm','EACT_mm','EIC_mm','RUNOFF_mm','net_bottom_outflow_mm','storage_change_mm')
    for identity,a in common.items():
        b=local[identity]
        physical_change=a['model_vegetation_class']!=b['model_vegetation_class']
        values={key:float(b[key])-float(a[key]) for key in fields}
        assert physical_change or all(abs(val)<1e-9 for val in values.values()),identity
        if physical_change:
            changed.append(dict(cell_id=identity,common_vegetation=a['model_vegetation_class'],local_vegetation=b['model_vegetation_class'],**{'delta_'+k:v for k,v in values.items()}))
    assert len(changed)==73
    target=root/'exports_local/local_minus_european.csv'
    with target.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(changed[0]));w.writeheader();w.writerows(changed)
    stats={key:dict(mean_changed_cells_mm=sum(r['delta_'+key] for r in changed)/73,
                   min_changed_cells_mm=min(r['delta_'+key] for r in changed),
                   max_changed_cells_mm=max(r['delta_'+key] for r in changed),
                   domain_area_mean_delta_mm=sum(r['delta_'+key] for r in changed)/4096) for key in fields}
    final=dict(status='COMPLETE_INITIAL_REGIONAL_MODEL_NOT_CALIBRATED',period=['2024-01-01','2026-10-01'],days=1005,
               grid_cells=4096,cell_size_m=250,domain_area_km2=256,versions=summaries,
               european_heath_cells=156,local_heath_cells=229,local_additional_heath_cells=73,
               local_comparison=stats,physical_delta='Only vegetation changes in73 additional BWK-majority-heath cells between European and local versions; no boundary or soil changes.',
               warning='Free drainage and shallow wetland head are explicit priors, not validated groundwater boundaries. Year-boundary accounting flags remain visible.',
               preparation_receipts='native_runs_completed=0 in original preparation/inventory receipts records their preparation stage; this completion receipt and native execution receipts record the final state.')
    (root/'completion_receipt.json').write_text(json.dumps(final,indent=2)+'\n')
    for name in ('model_european','model_local'):
        (root/name/'execution_summary.json').write_text(json.dumps(summaries[name],indent=2)+'\n')
    receipt=root/'heath_variant/vegetation_variant_receipt.json';r=json.loads(receipt.read_text())
    r.update(native_runs_completed=229,execution_status='COMPLETE_VEGETATION_DELTA_NOT_CALIBRATED')
    receipt.write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps(final,indent=2))


if __name__=='__main__':main()
