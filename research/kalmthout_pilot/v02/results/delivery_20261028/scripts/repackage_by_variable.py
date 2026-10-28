"""Repackage immutable annual V02 candidates as four full-period regular grids.
No numerical conversion, interpolation or native rerun is performed.
"""
from pathlib import Path
import argparse, datetime as dt, hashlib, json
from contextlib import ExitStack, nullcontext
import numpy as np
from netCDF4 import Dataset, num2date, date2num

SOURCE_SHA = {
 'SYMPHONICA_Kalmthout_V02_daily_2025.nc': '9ff38882055753433201dc362a1b2e86ea351e41d2ad14e93f97e5a8c384f131',
 'SYMPHONICA_Kalmthout_V02_daily_2026.nc': '30111cab9490dda538f9161fc92893e5e2bf15c09adbb35ea390ee6e68f2df26',
}
VARIABLES = ('GPP', 'soil_moisture', 'ET', 'soil_temperature')
START, END = dt.date(2025,1,1), dt.date(2026,10,1)
UNITS = 'days since 2025-01-01 00:00:00'
CALENDAR = 'proleptic_gregorian'
FILL = -999.0
BASELINE = 'a045b6202fa39b6492c9c5aad5bb26ae7177cd44'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        while b := f.read(1024*1024): h.update(b)
    return h.hexdigest()


def attrs(src, dst, exclude=()):
    dst.setncatts({k:src.getncattr(k) for k in src.ncattrs() if k not in ('_FillValue', *exclude)})


def normalize_time(var, values, source):
    return date2num(num2date(values, var.units, getattr(var,'calendar',CALENDAR)), UNITS, CALENDAR)


def main(source, output):
    output.mkdir(parents=True, exist_ok=True)
    (output/'products').mkdir(exist_ok=True); (output/'metadata').mkdir(exist_ok=True)
    sources=[]
    for name, expected in SOURCE_SHA.items():
        p=source/name
        if sha(p)!=expected: raise ValueError('Source hash mismatch: '+name)
        sources.append(p)
    manifest=[]
    with ExitStack() as stack:
        handles={p:stack.enter_context(Dataset(p)) for p in sources}
        ref=handles[sources[0]]
        rows=np.asarray(ref['row'][:])-int(ref['row'].index_base)
        cols=np.asarray(ref['col'][:])-int(ref['col'].index_base)
        ny,nx=int(rows.max()+1),int(cols.max()+1)
        if ny*nx!=len(rows) or len(set(zip(rows.tolist(),cols.tolist())))!=len(rows):
            raise ValueError('Grid is incomplete or has duplicate positions')
        xx=np.empty(nx); yy=np.empty(ny)
        xx[cols]=ref['easting'][:];yy[rows]=ref['northing'][:]
        if not np.array_equal(xx[cols],ref['easting'][:]) or not np.array_equal(yy[rows],ref['northing'][:]):
            raise ValueError('Coordinates do not form a rectilinear grid')
        if not (np.all(np.diff(xx)==250) and np.all(np.diff(yy)==250)):raise ValueError('Unexpected grid spacing')
        dates=[];blocks=[]
        for p in sources:
            with nullcontext(handles[p]) as d:
                if d.export_complete!=1:raise ValueError('Incomplete export')
                for k in ('cell','row','col','depth','requested_depth','easting','northing','vegetation_class','crop_model','crop_carbon_fraction','water_fraction','dominant_land_fraction','landcover_input_flags'):
                    a=np.asarray(d[k][:]);b=np.asarray(ref[k][:])
                    same=np.array_equal(a,b,equal_nan=True) if a.dtype.kind in 'fc' else np.array_equal(a,b)
                    if not same:raise ValueError('Partition metadata differs: '+k)
                sd=np.asarray(d['simulation_date'][:]).astype(str)
                mask=np.array([START<=dt.date.fromisoformat(v)<=END for v in sd]);ids=np.flatnonzero(mask)
                dates.extend(sd[mask].tolist());blocks.append((p,ids))
        expected_dates=[(START+dt.timedelta(days=i)).isoformat() for i in range((END-START).days+1)]
        if dates!=expected_dates:raise ValueError('Duplicate, missing or unordered reporting days')
        for key in VARIABLES:
            name=f'Kalmthoutseheide_SWAP_WOFOST_{key}_20250101_20261001.nc'
            path=output/'products'/name;tmp=path.with_suffix('.nc.partial')
            with Dataset(tmp,'w',format='NETCDF4') as out:
                for k,n in [('time',len(dates)),('y',ny),('x',nx),('bounds',2)]:out.createDimension(k,n)
                if key.startswith('soil_'):out.createDimension('depth',len(ref.dimensions['depth']))
                out.Conventions='CF-1.10'
                out.conventions_validation='CF-style metadata; no comprehensive external CF checker run'
                out.title=f'SWAP-WOFOST {key}, Kalmthoutseheide, daily 2025-01-01 through 2026-10-01'
                out.institution='Wageningen Environmental Research (WENR), Wageningen University & Research'
                out.contact='ab.veldhuizen@wur.nl';out.source=ref.source
                out.source_results_commit=BASELINE;out.source_simulation_commit=ref.baseline_git_commit
                out.product_status='PROVISIONAL_MODEL_RESULTS_NOT_INDEPENDENTLY_VALIDATED'
                out.delivery_layout='One scientific data variable per file, all 639 reporting days; coordinates and ancillary metadata retained'
                out.spatial_ref='EPSG:32631';out.spatial_resolution='250 m'
                out.time_coverage_start='2025-01-01T00:00:00Z'
                out.time_coverage_end='2026-10-02T00:00:00Z'
                out.time_coverage_end_convention='Exclusive end of final daily interval; final simulation_date is 2026-10-01'
                out.reporting_period_start=START.isoformat();out.reporting_period_end_inclusive=END.isoformat()
                out.time_convention=ref.time_convention
                out.output_depth_convention=ref.output_depth_convention
                out.spatial_limitations=ref.spatial_limitations;out.model_scope=ref.model_scope
                out.source_files=json.dumps([{'file':p.name,'sha256':SOURCE_SHA[p.name]} for p in sources])
                out.history='2026-10-28: concatenated verified annual candidate files, selected reporting dates, reindexed cells to their original grid without interpolation; physical values unchanged'
                out.geospatial_x_min=float(xx[0]-125);out.geospatial_x_max=float(xx[-1]+125)
                out.geospatial_y_min=float(yy[0]-125);out.geospatial_y_max=float(yy[-1]+125)
                out.geospatial_bounds_crs='EPSG:32631'
                out.export_complete=0
                t=out.createVariable('time','f8',('time',));attrs(ref['time'],t);t.units=UNITS;t.calendar=CALENDAR
                tb=out.createVariable('time_bounds','f8',('time','bounds'));tb.units=UNITS;tb.calendar=CALENDAR
                sd=out.createVariable('simulation_date',str,('time',));sd.long_name='UTC reporting-day label for the preceding complete daily interval at time'
                sd[:]=np.array(dates,dtype=object)
                for label,values,standard in [('x',xx,'projection_x_coordinate'),('y',yy,'projection_y_coordinate')]:
                    v=out.createVariable(label,'f8',(label,));v[:]=values;v.units='m';v.standard_name=standard;v.axis=label.upper();v.bounds=label+'_bounds'
                    b=out.createVariable(label+'_bounds','f8',(label,'bounds'));b[:]=np.stack([values-125,values+125],axis=1);b.units='m'
                crs=out.createVariable('crs','i4');attrs(ref['crs'],crs);crs.assignValue(0)
                static=['cell','vegetation_class','crop_model','water_fraction','dominant_land_fraction','landcover_input_flags','parent_cell_500m','native_model']
                if key=='GPP':static.append('crop_carbon_fraction')
                for k in static:
                    original=ref[k];a=np.asarray(original[:]);grid=np.empty((ny,nx),dtype=a.dtype);grid[rows,cols]=a
                    v=out.createVariable(k,str if original.dtype==str else original.dtype,('y','x'));attrs(original,v);v[:]=grid
                if key.startswith('soil_'):
                    for k in ('depth','requested_depth'):
                        v=out.createVariable(k,'f8',('depth',));attrs(ref[k],v);v[:]=ref[k][:]
                    out['depth'].axis='Z'
                native=ref[key];dims=('time','depth','y','x') if key.startswith('soil_') else ('time','y','x')
                chunks=(16,1,ny,nx) if key.startswith('soil_') else (16,ny,nx)
                data=out.createVariable(key,native.dtype,dims,fill_value=FILL,zlib=True,complevel=4,shuffle=True,fletcher32=True,chunksizes=chunks)
                attrs(native,data,exclude=('coordinates','ancillary_variables'));data.coordinates='simulation_date'
                data.missing_value=np.asarray(FILL,dtype=native.dtype);data.grid_mapping='crs'
                if key=='GPP':
                    out.GPP_contract=ref.GPP_contract
                    out.GPP_covered_cells=int(np.isfinite(ref['crop_carbon_fraction'][:].filled(np.nan)).sum())
                    out.GPP_coverage_fraction=out.GPP_covered_cells/(ny*nx)
                    data.ancillary_variables='GASST_flag crop_carbon_fraction'
                if key=='ET':out.ET_contract=ref.ET_contract;data.ancillary_variables='canopy_reset_flag'
                if key=='soil_moisture':out.soil_moisture_contract=ref.soil_moisture_contract
                flags=['GASST_flag'] if key=='GPP' else ['canopy_reset_flag'] if key=='ET' else []
                for k in flags:
                    v=out.createVariable(k,ref[k].dtype,('time','y','x'),zlib=True,complevel=4,chunksizes=(16,ny,nx));attrs(ref[k],v)
                pos=0
                for p,ids in blocks:
                    with nullcontext(handles[p]) as d:
                        n=len(ids);sl=slice(pos,pos+n)
                        t[sl]=normalize_time(d['time'],d['time'][ids],d)
                        tb[sl]=normalize_time(d['time'],d['time_bounds'][ids],d)
                        for start in range(0,n,16):
                            ix=ids[start:start+16];s=slice(pos+start,pos+start+len(ix))
                            a=np.ma.filled(d[key][ix],np.nan)
                            grid=np.full((len(ix),ny,nx)+(a.shape[2:] if a.ndim==3 else ()),np.nan,dtype=a.dtype)
                            grid[:,rows,cols]=a
                            if a.ndim==3:grid=np.moveaxis(grid,-1,1)
                            data[s]=np.ma.masked_invalid(grid)
                            for k in flags:
                                g=np.empty((len(ix),ny,nx),dtype=d[k].dtype);g[:,rows,cols]=d[k][ix];out[k][s]=g
                        pos+=n
                out.export_complete=1
            tmp.replace(path)
            manifest.append({'variable':key,'file':name,'bytes':path.stat().st_size,'sha256':sha(path),'days':len(dates),'spatial_shape':[ny,nx],'depths':5 if key.startswith('soil_') else None})
            print('WROTE',name,path.stat().st_size,flush=True)
    receipt={'status':'REPACKAGED_PENDING_VALIDATION','source_commit':BASELINE,'source_files':SOURCE_SHA,'start':START.isoformat(),'end_inclusive':END.isoformat(),'reporting_days':len(dates),'time_coordinate':'Preserved end of UTC day; first 2025-01-02 00:00Z, final 2026-10-02 00:00Z. Use simulation_date for daily labels.','fill_value':FILL,'grid_reindexing':'row/col to time[,depth],y,x with y ascending; no resampling','products':manifest}
    (output/'metadata/product_manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);a=p.parse_args();main(a.source,a.output)
