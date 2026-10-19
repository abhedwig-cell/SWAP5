"""Collect validated native day output into compressed annual NetCDF4 files."""
from pathlib import Path
import argparse,csv,datetime as dt,json,re,time
import numpy as np
from netCDF4 import Dataset
from run_v02 import SCALARS,sha

def export(root,out,selected=None,wait=False):
    rows=list(csv.DictReader((root/'cell_register.csv').open()))
    if selected:rows=[r for r in rows if r['cell_id'] in set(selected)]
    else:assert len(rows)==4096
    out.mkdir(exist_ok=True,parents=True);n=len(rows);datasets={};start=time.perf_counter()
    first=root/'cells'/rows[0]['cell_id']/'result_output.csv'
    with first.open() as f:header=next(csv.DictReader(l for l in f if not l.startswith('*')))
    wc=[k for k in header if k.startswith('WC[')];ts=[k for k in header if k.startswith('T[')]
    depths=[float(k[3:-1]) for k in wc];assert len(depths)==5
    for year,ndays in ((2024,366),(2025,365),(2026,274)):
        path=out/f'Kalmthout_SW431_V02_daily_{year}.nc.partial';d=Dataset(path,'w',format='NETCDF4');datasets[year]=d
        d.createDimension('time',ndays);d.createDimension('cell',n);d.createDimension('depth',5);d.createDimension('bounds',2)
        d.Conventions='CF-1.10';d.title='Kalmthout SWAP4.3.1 V02; numerical soil heat, WOFOST grass and maize proxy'
        d.model_scope='Locally refined 250m grid, independent1D soil columns; not calibrated; same groundwater priors as V01'
        d.source='SWAP4.3.1 original hydrological, thermal and WOFOST sources; explicit GNU output portability patch'
        d.time_convention='Native DATE labels the simulation day. time is the end of that UTC day; time_bounds is the complete preceding daily interval. State variables are at time; fluxes integrate over time_bounds.'
        d.output_depth_convention='Native selection returns compartment-centre values, without interpolation to requested depths. depth is the true signed depth; requested_depth records user selections.'
        d.assimilation_contract='GASST is native gross CH2O assimilation, not carbon GPP. Not simulated for prescribed vegetation. Zero assigned only for native unavailable GASST when no active dynamic crop; GASST_flag records this conversion.'
        d.balance_contract='BALDEV and DSTOR retain native definitions. independent_balance_residual compares fluxes with consecutive printed soil+pond+canopy stores; known crop-calendar canopy resets remain explicitly flagged.'
        d.executable_sha256=json.loads((root/'cells'/rows[0]['cell_id']/'v02_run_receipt.json').read_text())['executable_sha256']
        d.full_grid_complete=int(n==4096);d.crop_assumptions=json.dumps(json.loads((root/'preparation.json').read_text()),ensure_ascii=False)
        t=d.createVariable('time','f8',('time',));t.units=f'days since {year}-01-01 00:00:00';t.calendar='proleptic_gregorian';t.standard_name='time';t.bounds='time_bounds';t[:]=np.arange(1,ndays+1)
        b=d.createVariable('time_bounds','f8',('time','bounds'));b[:]=np.column_stack((np.arange(ndays),np.arange(1,ndays+1)))
        dates=d.createVariable('simulation_date',str,('time',));dates[:]=np.array([(dt.date(year,1,1)+dt.timedelta(days=i)).isoformat() for i in range(ndays)],dtype=object)
        c=d.createVariable('cell',str,('cell',));c[:]=np.array([r['cell_id'] for r in rows],dtype=object)
        z=d.createVariable('depth','f8',('depth',));z.units='cm';z.positive='up';z.long_name='actual native compartment centre below soil surface';z[:]=depths
        rz=d.createVariable('requested_depth','f8',('depth',));rz.units='cm';rz.positive='up';rz[:]=[-10,-20,-40,-80,-160]
        for key,axis in (('easting','X'),('northing','Y')):
            v=d.createVariable(key,'f8',('cell',));v.units='m';v.standard_name='projection_x_coordinate' if axis=='X' else 'projection_y_coordinate';v[:]=[float(r[key]) for r in rows]
        crs=d.createVariable('crs','i4');crs.grid_mapping_name='transverse_mercator';crs.longitude_of_central_meridian=3.;crs.latitude_of_projection_origin=0.;crs.scale_factor_at_central_meridian=.9996;crs.false_easting=500000.;crs.false_northing=0.;crs.semi_major_axis=6378137.;crs.inverse_flattening=298.257223563;crs.epsg_code='EPSG:32631'
        cover=d.createVariable('vegetation_class','i2',('cell',));cover[:]=[int(r['dominant_land_class']) for r in rows]
        kind=d.createVariable('crop_model',str,('cell',));kind[:]=np.array([r['crop_model'] for r in rows],dtype=object)
        for key in ('water_fraction','dominant_land_fraction'):
            v=d.createVariable(key,'f4',('cell',));v.units='1';v[:]=[float(r[key]) for r in rows]
        for key in ('row','col'):
            v=d.createVariable(key,'i2',('cell',));v[:]=[int(r[key]) for r in rows];v.index_base=1
        for key,source in (('landcover_input_flags','flags'),('parent_cell_500m','parent_500m'),('native_model','native_model')):
            v=d.createVariable(key,str,('cell',));v[:]=np.array([r[source] for r in rows],dtype=object)
        d.spatial_limitations='Dominant terrestrial column only; water_fraction and landcover_input_flags retain mixed-water, urban-surrogate, soil-imputation and boundary-prior limitations. Not a complete lake or urban water balance.'
        for k in SCALARS+['WC','T','independent_balance_residual']:
            dims=('time','cell','depth') if k in ('WC','T') else ('time','cell')
            chunks=(min(32,ndays),min(64,n),5) if len(dims)==3 else (min(32,ndays),min(64,n))
            v=d.createVariable(k,'f4' if k in ('WC','T') else 'f8',dims,zlib=True,complevel=4,shuffle=True,fletcher32=True,chunksizes=chunks,fill_value=np.nan)
            v.units={'WC':'m3 m-3','T':'degree_Celsius','GASST':'kg ha-1'}.get(k,'cm')
            v.cell_methods='time: point' if k in ('GWL','WC','T') else 'time: sum'
            v.grid_mapping='crs';v.coordinates='easting northing'
            if k=='GASST':v.substance='CH2O equivalents'
            if k=='BOT':v.positive='into the soil column'
            if k=='GWL':v.positive='up relative to the soil surface';v.missing_native_value=999.
        for k in ('canopy_reset_flag','GASST_flag'):
            v=d.createVariable(k,'u1',('time','cell'),zlib=True,complevel=4,shuffle=True,chunksizes=(min(32,ndays),min(64,n)))
            v.flag_values=np.array([0,1,2],dtype='u1') if k=='GASST_flag' else np.array([0,1],dtype='u1')
            v.flag_meanings='native_value no_active_dynamic_crop_zero_assigned assimilation_not_simulated' if k=='GASST_flag' else 'no_flag crop_calendar_canopy_accounting_discontinuity'
    offsets={2024:(0,366),2025:(366,731),2026:(731,1005)}
    try:
        for first_i in range(0,n,64):
            group=rows[first_i:first_i+64];data={k:[] for k in SCALARS+['WC','T','independent_balance_residual','canopy_reset_flag','GASST_flag']}
            for row in group:
                case=root/'cells'/row['cell_id'];receipt_path=case/'v02_run_receipt.json'
                while wait and not receipt_path.exists():time.sleep(2)
                receipt=json.loads(receipt_path.read_text());assert receipt['status'] in ('SUCCESS','COMPLETED_WITH_CANOPY_RESET_FLAG')
                assert sha(case/'result_output.csv')==receipt['output_sha256']
                with (case/'result_output.csv').open() as f:r=list(csv.DictReader(l for l in f if not l.startswith('*')))
                assert len(r)==1006;keys=list(r[0]);a=np.array([[float(x[k]) for k in keys[1:]] for x in r]);col={k:a[:,keys[1:].index(k)] for k in keys[1:]}
                native={k:col[k][1:].copy() for k in SCALARS};gas_flag=np.zeros(1005,dtype='u1')
                if row['crop_model']=='prescribed':native['GASST'][:]=np.nan;gas_flag[:]=2
                else:
                    missing=native['GASST']==-999.999;native['GASST'][missing]=0.;gas_flag[missing]=1
                native['GWL'][native['GWL']==999.]=np.nan
                for k in SCALARS:data[k].append(native[k])
                data['WC'].append(np.column_stack([col[k][1:] for k in wc]));data['T'].append(np.column_stack([col[k][1:] for k in ts]))
                storage=sum(col[k] for k in ('WTOT','PD_VOL','IC_VOL'))
                independent=col['RAIN'][1:]+col['IRRIG'][1:]+col['BOT'][1:]-sum(col[k][1:] for k in ('RUNOFF','EACT','EPD','TACT','EIC','DRN'))-np.diff(storage)
                data['independent_balance_residual'].append(independent)
                flag=np.zeros(1005,dtype='u1')
                for item in receipt['audit']['canopy_reset_flags']:
                    ix=(dt.date.fromisoformat(item['date'])-dt.date(2024,1,1)).days;flag[ix]=1
                    if item['interpretation']=='two-day output accounting jump':flag[ix-1]=1
                data['canopy_reset_flag'].append(flag);data['GASST_flag'].append(gas_flag)
            for k,values in data.items():
                array=np.stack(values,axis=1)
                for year,d in datasets.items():
                    lo,hi=offsets[year];d[k][:,first_i:first_i+len(group)]=array[lo:hi]
            if first_i%256==0:print(json.dumps({'exported_cells':first_i+len(group),'total':n,'elapsed_s':round(time.perf_counter()-start,1)}),flush=True)
        for d in datasets.values():d.export_complete=1
    finally:
        for d in datasets.values():d.close()
    for year in datasets:
        (out/f'Kalmthout_SW431_V02_daily_{year}.nc.partial').replace(out/f'Kalmthout_SW431_V02_daily_{year}.nc')
    receipt={'cells':n,'years':{str(y):hi-lo for y,(lo,hi) in offsets.items()},'requested_scalars':SCALARS,'actual_depth_cm':depths,'requested_depth_cm':[-10,-20,-40,-80,-160],'files':[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(out.glob('*.nc'))],'wall_seconds':time.perf_counter()-start,'wall_seconds_includes_wait_for_native_runs':wait,'spatial_flags_included':True,'status':'COMPLETE' if n==4096 else 'PROTOTYPE_SELECTED_CELLS'}
    (out/'netcdf_export_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('out',type=Path);p.add_argument('--cells',nargs='+');p.add_argument('--wait',action='store_true');a=p.parse_args();export(a.root,a.out,a.cells,a.wait)
