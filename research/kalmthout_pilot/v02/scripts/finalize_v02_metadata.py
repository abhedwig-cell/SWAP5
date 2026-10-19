"""Retain the spatial input flags alongside the completed daily NetCDF arrays."""
from pathlib import Path
import argparse,csv,json
import numpy as np
from netCDF4 import Dataset
from run_v02 import sha

p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args();root=a.root;out=root/'daily_netcdf';rows=list(csv.DictReader((root/'cell_register.csv').open()))
summary=json.loads((root/'execution_summary_v02.json').read_text());assert summary['full_grid_complete']
for row in rows:
    case=root/'cells'/row['cell_id'];receipt=json.loads((case/'v02_run_receipt.json').read_text());row['status']=receipt['status']
    extra=['NUMERICAL_HEAT_AIR_TOP_NO_SPINUP','THERMAL_ORGMAT_FROM_SOC_FACTOR_1_724']
    if row['crop_model']!='prescribed':extra+=['CO2_CORRECTION_OFF','MAIZE_PROXY_NOT_OBSERVED_ROTATION' if row['crop_model']=='maize' else 'WOFOST_GRASS_STANDARD_MANAGEMENT_PRIOR']
    row['flags']=';'.join(dict.fromkeys(row['flags'].split(';')+extra))
    mp=case/'cell_manifest.json';m=json.loads(mp.read_text());m['flags']=list(dict.fromkeys(m['flags']+extra));tmp=mp.with_suffix('.metadata.tmp');tmp.write_text(json.dumps(m,indent=2)+'\n');tmp.replace(mp)
with (root/'cell_register.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
grid_path=root/'grid_250m.geojson';grid=json.loads(grid_path.read_text());by_id={r['cell_id']:r for r in rows}
for feature in grid['features']:
    row=by_id[feature['properties']['cell_id']]
    feature['properties'].update({k:row[k] for k in ('native_model','status','crop_model','heat_module','flags')})
grid_path.write_text(json.dumps(grid)+'\n')
prep=root/'preparation.json';r=json.loads(prep.read_text());r['current_execution_summary']='execution_summary_v02.json';r['current_execution_status']='COMPLETE_WITH_EXPLICIT_CANOPY_FLAGS';prep.write_text(json.dumps(r,indent=2)+'\n')
files=[]
for p in sorted(out.glob('*.nc')):
    with Dataset(p,'a') as d:
        assert d.export_complete==1 and d.full_grid_complete==1
        for key in ('water_fraction','dominant_land_fraction'):
            v=d[key] if key in d.variables else d.createVariable(key,'f4',('cell',))
            v.units='1';v[:]=[float(r[key]) for r in rows]
        for key in ('row','col'):
            v=d[key] if key in d.variables else d.createVariable(key,'i2',('cell',));v[:]=[int(r[key]) for r in rows];v.index_base=1
        for key,source in (('landcover_input_flags','flags'),('parent_cell_500m','parent_500m'),('native_model','native_model')):
            v=d[key] if key in d.variables else d.createVariable(key,str,('cell',));v[:]=np.array([r[source] for r in rows],dtype=object)
        d.spatial_limitations='Dominant terrestrial column only; water_fraction and landcover_input_flags retain mixed-water, urban-surrogate, soil-imputation and boundary-prior limitations. Not a complete lake or urban water balance.'
    files.append({'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)})
assert len(files)==3
p=out/'netcdf_export_receipt.json';r=json.loads(p.read_text());r['files']=files;r['spatial_flags_included']=True;r['wall_seconds_includes_wait_for_native_runs']=True;p.write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(files))
