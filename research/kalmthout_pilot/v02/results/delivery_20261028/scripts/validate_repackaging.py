"""Independent full-array comparison of four grid products to preserved sources."""
from pathlib import Path
import argparse, datetime as dt, hashlib, json
import numpy as np
from netCDF4 import Dataset, num2date

KEYS=('GPP','soil_moisture','ET','soil_temperature')

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def plain(v):return np.asarray(np.ma.filled(v[:],np.nan))
def iso_time(v, values):return np.array([x.isoformat() for x in num2date(values,v.units,v.calendar)])

def main(source,root):
    checks=[]
    paths=sorted((root/'products').glob('*.nc'))
    if len(paths)!=4:raise ValueError('Expected exactly four final NetCDF files')
    expected_dates=[(dt.date(2025,1,1)+dt.timedelta(days=i)).isoformat() for i in range(639)]
    for key in KEYS:
        p=next(f for f in paths if f.name==f'Kalmthoutseheide_SWAP_WOFOST_{key}_20250101_20261001.nc')
        with Dataset(p) as out:
            assert out.export_complete==1
            assert list(np.asarray(out['simulation_date'][:]))==expected_dates
            assert out[key]._FillValue==-999 and out[key].missing_value==-999
            assert out[key].units=={'ET':'mm d-1','GPP':'umol m-2 s-1','soil_moisture':'kg m-3','soil_temperature':'degree_Celsius'}[key]
            assert tuple(out[key].dimensions)==(('time','depth','y','x') if key.startswith('soil_') else ('time','y','x'))
            assert len(out.dimensions['time'])==639 and len(out.dimensions['x'])==64 and len(out.dimensions['y'])==64
            assert out.time_coverage_end=='2026-10-02T00:00:00Z'
            assert np.array_equal(np.diff(out['x'][:]),np.full(63,250)) and np.array_equal(np.diff(out['y'][:]),np.full(63,250))
            assert out['crs'].epsg_code=='EPSG:32631'
            time=plain(out['time']);bounds=plain(out['time_bounds']);assert np.array_equal(bounds[:,1],time)
            assert np.array_equal(bounds[:,0],np.arange(639)) and np.array_equal(bounds[:,1],np.arange(1,640))
            assert len(set(KEYS)&set(out.variables))==1
            pos=0;finite=0;missing=0
            for year in (2025,2026):
                src=source/f'SYMPHONICA_Kalmthout_V02_daily_{year}.nc'
                with Dataset(src) as s:
                    n=len(s.dimensions['time']);rows=np.asarray(s['row'][:])-1;cols=np.asarray(s['col'][:])-1
                    assert np.array_equal(out['x'][:][cols],s['easting'][:]) and np.array_equal(out['y'][:][rows],s['northing'][:])
                    assert np.array_equal(out['cell'][:][rows,cols],s['cell'][:])
                    for name in ('vegetation_class','crop_model','water_fraction','dominant_land_fraction','landcover_input_flags','parent_cell_500m','native_model'):
                        assert np.array_equal(out[name][:][rows,cols],s[name][:])
                    if key.startswith('soil_'):
                        assert np.array_equal(out['depth'][:],s['depth'][:]) and np.array_equal(out['requested_depth'][:],s['requested_depth'][:])
                    if key=='GPP':assert np.array_equal(plain(out['crop_carbon_fraction'])[rows,cols],plain(s['crop_carbon_fraction']),equal_nan=True)
                    assert np.array_equal(iso_time(out['time'],time[pos:pos+n]),iso_time(s['time'],s['time'][:]))
                    for start in range(0,n,16):
                        count=min(16,n-start);old=np.ma.filled(s[key][start:start+count],np.nan)
                        new=np.ma.filled(out[key][pos+start:pos+start+count],np.nan)
                        # Inverse geographic lookup, independent of the writer's forward reshape.
                        if key.startswith('soil_'):new=np.moveaxis(new[:,:,rows,cols],1,2)
                        else:new=new[:,rows,cols]
                        assert np.array_equal(old,new,equal_nan=True),(key,year,start)
                        finite+=int(np.isfinite(new).sum());missing+=int(np.isnan(new).sum())
                        for flag in ('GASST_flag',) if key=='GPP' else ('canopy_reset_flag',) if key=='ET' else ():
                            assert np.array_equal(out[flag][pos+start:pos+start+count][:,rows,cols],s[flag][start:start+count])
                        if key=='GPP':
                            crop=np.asarray(s['crop_model'][:]);assert np.isnan(new[:,crop=='prescribed']).all()
                            assert np.isfinite(new[:,crop!='prescribed']).all()
                    pos+=n
            checks.append({'variable':key,'file':p.name,'all_values_exact_equal_including_missing':True,'finite_values':finite,'missing_values':missing,'all_time_and_metadata_checks':'PASS','bytes':p.stat().st_size,'sha256':sha(p)})
    receipt={'status':'PASS','checks':checks,'scope':'Repackaging, daily selection, grid orientation, time normalisation, exact scientific values and flags; no new model physics or external field validation.'}
    (root/'metadata/repackaging_validation.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('root',type=Path);a=p.parse_args();main(a.source,a.root)
