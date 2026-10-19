from pathlib import Path
from collections import Counter
import argparse,csv,datetime as dt,json,sys,hashlib
import numpy as np
from netCDF4 import Dataset
from convert_symphonica import plain,carbon_fraction,gpp_factor,convert,sha

NAMES={10:'Forest',20:'Heath',30:'Grass',40:'Maize proxy',50:'Urban surrogate',90:'Wetland'}
def savecsv(path,rows):
 if not rows:return
 with path.open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def stats(x):return {'min':float(np.nanmin(x)),'p10':float(np.nanquantile(x,.1)),'median':float(np.nanmedian(x)),'p90':float(np.nanquantile(x,.9)),'max':float(np.nanmax(x))}
def main(source,root):
 root.mkdir(parents=True,exist_ok=True)
 for n in ('tables','evidence','products','figures'):(root/n).mkdir(exist_ok=True)
 expected=json.loads((source/'netcdf_export_receipt.json').read_text())['files'];receipts=[];annual=[];byclass=[];seasonal=[];months=[];depthtable=[];ranges=[];arrays={};meta=None;cellperiod=[]
 for identity in expected:
  file=source/identity['name'];assert sha(file)==identity['sha256']
  year=int(file.stem[-4:]);print('READ',year,flush=True)
  with Dataset(file) as d:
   dates=np.array([dt.date.fromisoformat(s) for s in d['simulation_date'][:]]);years=np.array([x.year for x in dates]);dayofyear=np.array([x.timetuple().tm_yday for x in dates]);month=np.array([x.month for x in dates]);cl=np.array(d['vegetation_class'][:]);crop=np.array(d['crop_model'][:]);cf=carbon_fraction(crop);z=plain(d['depth']);n=len(cl)
   if meta is None:
    meta={'cell':np.array(d['cell'][:]),'class':cl,'crop':crop,'cf':cf,'easting':plain(d['easting']),'northing':plain(d['northing']),'water_fraction':plain(d['water_fraction']),'land_fraction':plain(d['dominant_land_fraction']),'flags':np.array(d['landcover_input_flags'][:]),'depth_cm':z,'row':np.array(d['row'][:]),'col':np.array(d['col'][:])}
   a={k:plain(d[k]) for k in 'RAIN RUNOFF IRRIG DRN BOT EPOT EACT TPOT TACT EPD EIC DSTOR BALDEV GASST GWL independent_balance_residual'.split()}
   a['WC']=plain(d['WC'])*1000;a['T']=plain(d['T']);a['ET']=10*(a['TACT']+a['EACT']+a['EIC']);a['ET4']=a['ET']+10*a['EPD'];a['GPP']=a['GASST']*gpp_factor(cf,np.full(len(dates),86400.));a['carbon']=a['GASST']*cf[None,:]*.1
   gflag=np.array(d['GASST_flag'][:]);cflag=np.array(d['canopy_reset_flag'][:]);active=np.isfinite(cf)
   aprsep=(month>=4)&(month<=9)
   def summarize(mask,select,label):
    daily=lambda k:np.nanmean(a[k][mask][:,select],axis=1)
    total=lambda k:float(np.nansum(daily(k)))
    answer={'year':year,'period':label,'days':int(mask.sum()),'class':'Domain' if isinstance(select,slice) else NAMES[int(cl[select][0])],'cells':n if isinstance(select,slice) else int(np.sum(select)), 'P_mm':total('RAIN')*10,'ET_mm':total('ET'),'ET_mean_mm_d':float(np.mean(daily('ET'))),'T_mm':total('TACT')*10,'soil_E_mm':total('EACT')*10,'canopy_term_mm':total('EIC')*10,'pond_E_mm':total('EPD')*10,'ET_including_pond_mm':total('ET4'),'net_bottom_outflow_mm':-total('BOT')*10,'runoff_mm':total('RUNOFF')*10,'storage_change_mm':total('DSTOR')*10,'native_BALDEV_sum_mm':total('BALDEV')*10,'T_potential_mm':total('TPOT')*10,'T_ratio':total('TACT')/total('TPOT') if total('TPOT')>0 else np.nan}
    if not isinstance(select,slice) and np.isfinite(cf[select]).all():
     answer['GPP_gC_m2']=total('carbon');answer['GPP_mean_umol_m2_s']=float(np.mean(daily('GPP')))
    else:answer['GPP_gC_m2']=np.nan;answer['GPP_mean_umol_m2_s']=np.nan
    answer['balance_residual_check_mm']=answer['P_mm']-answer['ET_including_pond_mm']-answer['net_bottom_outflow_mm']-answer['runoff_mm']-answer['storage_change_mm']-answer['native_BALDEV_sum_mm']
    return answer
   annual.append(summarize(np.ones(len(dates),bool),slice(None),'Available year'))
   seasonal.append(summarize(aprsep,slice(None),'April to September'))
   for code in NAMES:
    sel=cl==code;byclass.append(summarize(np.ones(len(dates),bool),sel,'Available year'));byclass.append(summarize(aprsep,sel,'April to September'))
   for m in np.unique(month):
    sel=month==m;r=summarize(sel,slice(None),f'{year}-{m:02d}');r['month']=int(m);months.append(r)
   for level,zz in enumerate(z):
    for label,tm in [('Available year',np.ones(len(dates),bool)),('April to September',aprsep)]:
     for code,sel in [(0,np.ones(n,bool)),*[(c,cl==c) for c in NAMES]]:
      w=a['WC'][tm][:,sel,level];t=a['T'][tm][:,sel,level];r={'year':year,'period':label,'class':'Domain' if code==0 else NAMES[code],'depth_cm':float(zz),'cells':int(sel.sum()),'days':int(tm.sum()),'moisture_mean_kg_m3':float(w.mean()),'moisture_spatial_mean_p10':float(np.quantile(w.mean(axis=0),.1)),'moisture_spatial_mean_p90':float(np.quantile(w.mean(axis=0),.9)),'temperature_mean_C':float(t.mean()),'temperature_min_C':float(t.min()),'temperature_max_C':float(t.max()),'moisture_min_kg_m3':float(w.min()),'moisture_max_kg_m3':float(w.max())};depthtable.append(r)
   # Small derived arrays support reproducible plotting without storing another source copy.
   out={'date':np.array([x.isoformat() for x in dates]),'doy':dayofyear,'month':month,'P':a['RAIN'].mean(axis=1)*10,'ET':a['ET'].mean(axis=1),'EPD':a['EPD'].mean(axis=1)*10,'Tact':a['TACT'].mean(axis=1)*10,'Esoil':a['EACT'].mean(axis=1)*10,'Eic':a['EIC'].mean(axis=1)*10,'WC_mean':a['WC'].mean(axis=1),'WC_p10':np.quantile(a['WC'],.1,axis=1),'WC_p90':np.quantile(a['WC'],.9,axis=1),'Tsoil_mean':a['T'].mean(axis=1),'max_residual_mm':np.max(np.abs(a['independent_balance_residual']),axis=1)*10,'canopy_flag_count':cflag.sum(axis=1)}
   for code in NAMES:
    sel=cl==code
    for k in ('ET','WC','T','GPP','carbon','TACT','TPOT'):
     if k=='GPP' or k=='carbon':
      if code not in (30,40):continue
     out[f'{k}_class{code}']=a[k][:,sel].mean(axis=1)
   for k in ('ET','ET4','TACT','EACT','EIC','EPD','TPOT','BOT','RUNOFF','DSTOR'):
    out[k+'_aprsep_cell']=a[k][aprsep].sum(axis=0)
   out['carbon_aprsep_cell']=np.sum(a['carbon'][aprsep],axis=0)
   out['WC_aprsep_cell']=a['WC'][aprsep].mean(axis=0)
   out['T_aprsep_cell']=a['T'][aprsep].mean(axis=0)
   out['WC_monthly']=np.stack([a['WC'][month==m].mean(axis=(0,1)) for m in np.unique(month)])
   out['T_monthly']=np.stack([a['T'][month==m].mean(axis=(0,1)) for m in np.unique(month)])
   for lab,tm in [('JFM',month<=3),('JJA',(month>=6)&(month<=8))]:
    out['WC_'+lab+'_class']=np.stack([a['WC'][tm][:,cl==c].mean(axis=(0,1)) for c in NAMES])
   im=int(np.argmin(out['WC_mean'][:,0]));out['drydate']=np.array(dates[im].isoformat());out['WC_drydate_cell']=a['WC'][im];out['T_drydate_cell']=a['T'][im]
   # Whole-year spatial distribution of cell totals, not standard errors.
   for k in ('ET','ET4'):
    for code in NAMES:ranges.append({'year':year,'class':NAMES[code],'variable':k,**stats(a[k][:,cl==code].sum(axis=0))})
   for i,id in enumerate(meta['cell']):
    r={'cell_id':str(id),'class':NAMES[int(cl[i])],'year':year,'days':len(dates),'ET_mm':float(a['ET'][:,i].sum()),'ET_aprsep_mm':float(out['ET_aprsep_cell'][i]),'T_aprsep_mm':float(out['TACT_aprsep_cell'][i]*10),'GPP_aprsep_gC_m2':float(out['carbon_aprsep_cell'][i]),'WC10_aprsep_kg_m3':float(out['WC_aprsep_cell'][i,0]),'WC160_aprsep_kg_m3':float(out['WC_aprsep_cell'][i,-1])};cellperiod.append(r)
   np.savez_compressed(root/'evidence'/f'aggregates_{year}.npz',**out)
   print('CONVERT',year,flush=True)
  receipts.append(convert(file,root/'products'/f'SYMPHONICA_Kalmthout_V02_daily_{year}.nc'))
 np.savez_compressed(root/'evidence/spatial_metadata.npz',**meta)
 for name,rows in [('annual_domain',annual),('annual_and_seasonal_classes',byclass),('common_period_domain',seasonal),('monthly_domain',months),('depth_statistics',depthtable),('spatial_ET_ranges',ranges),('cell_results',cellperiod)]:savecsv(root/'tables'/f'{name}.csv',rows)
 # Weather is source forcing, not inferred from soil temperature.
 forcing=source.parent/'forcing/hourly.met'
 with forcing.open() as f:r=list(csv.DictReader((l for l in f if not l.startswith('*')),delimiter=' '))
 air=np.array([float(x['TEMP']) for x in r]).reshape(-1,24).mean(axis=1);rad=np.array([float(x['RAD']) for x in r]).reshape(-1,24).sum(axis=1)/1000.
 np.savez_compressed(root/'evidence/weather_daily.npz',air_C=air,radiation_MJ_m2=rad)
 summary={'baseline_commit':'48c7897c6500309e5e83377986ca2ff3e20917e3','annual':annual,'common_period':seasonal,'class_counts':{NAMES[c]:int(np.sum(meta['class']==c)) for c in NAMES},'GPP_covered_cells':int(np.isfinite(meta['cf']).sum()),'GPP_covered_fraction':float(np.isfinite(meta['cf']).mean()),'source_forcing_sha256':sha(forcing),'conversion_products':receipts,'complete_cell_days':4096*1005,'temporal_comparison':'2026 is partial; April to September has 183 days in all years'}
 (root/'evidence/analysis_summary.json').write_text(json.dumps(summary,indent=2,allow_nan=True).replace('NaN','null')+'\n');print(json.dumps(summary,indent=2),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('output',type=Path);a=p.parse_args();main(a.source,a.output)
