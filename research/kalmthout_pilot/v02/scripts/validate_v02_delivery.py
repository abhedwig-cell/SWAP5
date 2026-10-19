"""Validate complete NetCDF payloads, native availability and selected exact round trips."""
from pathlib import Path
from collections import Counter
import argparse,csv,json
import numpy as np
from netCDF4 import Dataset
from run_v02 import SCALARS,sha

parser=argparse.ArgumentParser();parser.add_argument('root',type=Path);args=parser.parse_args()
root=args.root;out=root/'daily_netcdf'
register=list(csv.DictReader((root/'cell_register.csv').open()))
assert len(register)==4096
receipts=[json.loads((root/'cells'/r['cell_id']/'v02_run_receipt.json').read_text()) for r in register]
assert all(r['status'] in ('SUCCESS','COMPLETED_WITH_CANOPY_RESET_FLAG') for r in receipts)
summary=json.loads((root/'execution_summary_v02.json').read_text());assert summary['full_grid_complete']
selected={0,7,20,27,196,1023,2047,3071,4095}
for kind in ('prescribed','grass','maize'):
    selected.add(next(i for i,r in enumerate(register) if r['crop_model']==kind))
checks=[]
for year,days in ((2024,366),(2025,365),(2026,274)):
    p=out/f'Kalmthout_SW431_V02_daily_{year}.nc'
    with Dataset(p) as d:
        assert d.export_complete==1 and d.full_grid_complete==1
        assert len(d.dimensions['time'])==days and len(d.dimensions['cell'])==4096 and len(d.dimensions['depth'])==5
        assert list(d['cell'][:])==[r['cell_id'] for r in register]
        assert list(d['landcover_input_flags'][:])==[r['flags'] for r in register]
        assert list(d['native_model'][:])==[r['native_model'] for r in register]
        assert np.array_equal(d['depth'][:],[-10.5,-22.5,-42.5,-82.5,-162.5])
        assert np.array_equal(d['requested_depth'][:],[-10,-20,-40,-80,-160])
        for key in SCALARS+['WC','T']:
            a=d[key][:];assert a.shape==((days,4096,5) if key in ('WC','T') else (days,4096))
            if key not in ('GASST','GWL'):assert not np.ma.getmaskarray(a).any() and np.isfinite(a).all(),(year,key)
        rain=d['RAIN'][:];assert np.all(np.isfinite(rain));assert np.max(np.ptp(rain,axis=1))<1e-6
        gas=d['GASST'][:];flags=d['GASST_flag'][:];prescribed=np.array([r['crop_model']=='prescribed' for r in register]);assert np.ma.getmaskarray(gas[:,prescribed]).all()
        assert np.all(flags[:,prescribed]==2)
        assert np.all(np.ma.filled(gas[:,~prescribed],-1)>=-1e-8)
        bal=d['BALDEV'][:];independent=d['independent_balance_residual'][:];reset=d['canopy_reset_flag'][:]
        assert np.max(np.abs((independent-bal)[reset==0]))<1e-6
        for j in sorted(selected):
            with (root/'cells'/register[j]['cell_id']/'result_output.csv').open() as f:
                rows=[r for r in csv.DictReader(l for l in f if not l.startswith('*')) if r['DATE'].startswith(str(year))]
            assert len(rows)==days
            for key in SCALARS:
                expected=np.array([float(r[key]) for r in rows])
                if key=='GASST':
                    if prescribed[j]:expected[:]=np.nan
                    else:expected[expected==-999.999]=0.
                if key=='GWL':expected[expected==999]=np.nan
                actual=np.ma.filled(d[key][:,j],np.nan);assert np.array_equal(actual,expected,equal_nan=True),(year,j,key)
            for key,prefix in (('WC','WC['),('T','T[')):
                names=[k for k in rows[0] if k.startswith(prefix)]
                expected=np.array([[float(r[k]) for k in names] for r in rows],dtype='f4')
                assert np.array_equal(d[key][:,j,:],expected),(year,j,key)
        checks.append({'year':year,'days':days,'cells':4096,'all_requested_arrays_complete':True,'roundtrip_selected_cells':len(selected),'scalar_roundtrip':'exact including documented missing-value interpretation','WC_T_roundtrip':'exact after declared float32 conversion','temperature_min_C':float(np.min(d['T'][:])),'temperature_max_C':float(np.max(d['T'][:])),'flagged_cell_days':int(np.count_nonzero(reset)),'max_independent_residual_mm':float(np.max(np.abs(independent))*10),'file_bytes':p.stat().st_size,'sha256':sha(p)})
flags=[f for r in receipts for f in r['audit']['canopy_reset_flags']]
report={'status':'COMPLETE_WITH_EXPLICIT_PHYSICAL_LIMITATIONS','grid_cells':4096,'days':1005,'crop_counts':dict(Counter(r['crop_model'] for r in register)),'native_status_counts':dict(Counter(r['status'] for r in receipts)),'native_run_wall_seconds':summary['wall_seconds'],'canopy_reset_events':len(flags),'max_flagged_reset_mm':max((abs(f['residual_cm'])*10 for f in flags),default=0),'canopy_reset_transitions':dict(Counter(f['transition'] for f in flags)),'NetCDF':checks,'native_csv_bytes':sum((root/'cells'/r['cell_id']/'result_output.csv').stat().st_size for r in register),'netcdf_total_bytes':sum(c['file_bytes'] for c in checks)}
(root/'delivery_validation_v02.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
