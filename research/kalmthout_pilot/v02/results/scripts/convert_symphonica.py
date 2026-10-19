"""Derive explicitly provisional SYMPHONICA variables from immutable SWAP V02 files.

ET is the requested TACT+EACT+EIC definition. Pond evaporation remains separate.
GPP reverses SWAP431's carbon-fraction conversion, retains its management/stress
reductions, and expresses gross CO2 assimilation as a mean over time_bounds.
"""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from netCDF4 import Dataset

CFRDM={'grass':0.45,'maize':0.4}
SOURCE_HASHES={'97a23bfc7227650ef1c529737bf7590a65b3f776bdec484249a5cd29e6a65e00', 'e49a220af4ccaf290846649b0f555422e218e5c56fc653bb76e36479a15f23c7', '1b30cd007e572c9b364794223c13df536a06fd1dd7b592ff00fe76c967add84d'}
MOLAR_C_G=12.0
RHO_WATER_KG_M3=1000.0
BASELINE_COMMIT='48c7897c6500309e5e83377986ca2ff3e20917e3'
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  while b:=f.read(1024*1024):h.update(b)
 return h.hexdigest()
def plain(v):return np.asarray(np.ma.filled(v[:],np.nan),dtype='f8')
def carbon_fraction(crop):return np.array([CFRDM.get(str(x),np.nan) for x in crop],dtype='f8')
def gpp_factor(cf,seconds):
 return np.asarray(cf)*1000./MOLAR_C_G/10000.*1e6/np.asarray(seconds)[...,None]
def convert(source,destination):
 source=Path(source);destination=Path(destination)
 if sha(source) not in SOURCE_HASHES:raise ValueError('Input is not a pinned V02 source file; review crop carbon fractions and mapping before using another model version')
 destination.parent.mkdir(parents=True,exist_ok=True);tmp=destination.with_suffix('.nc.partial')
 with Dataset(source) as src,Dataset(tmp,'w',format='NETCDF4') as dst:
  assert src.export_complete==1 and src.full_grid_complete==1
  assert set(src['crop_model'][:])<=set(CFRDM)|{'prescribed'}
  for k,v in src.dimensions.items():dst.createDimension(k,len(v))
  for k in src.ncattrs():dst.setncattr(k,src.getncattr(k))
  dst.title='SYMPHONICA candidate daily products from Kalmthout SWAP431 V02'
  dst.product_status='PROVISIONAL_CANDIDATE_MAPPING_NOT_AN_APPROVED_PROJECT_SCHEMA'
  dst.source_file=source.name;dst.source_sha256=sha(source);dst.baseline_git_commit=BASELINE_COMMIT
  dst.Conventions='CF-1.10';dst.conventions_validation='Declared convention; no comprehensive external CF checker applied'
  dst.water_density_kg_m3=RHO_WATER_KG_M3;dst.molar_carbon_g_mol=MOLAR_C_G
  dst.GPP_contract='Native GASST * CFRDM converted to carbon moles, retaining management and stress reductions. Daily interval mean, positive uptake, missing where assimilation is not simulated. Grass CFRDM=0.45; maize=0.40. Not ecosystem coverage.'
  dst.ET_contract='ET=10*(TACT+EACT+EIC), mm d-1 for 86400-second intervals. Native EIC includes canopy reset accounting. EPD is separate; ET_including_pond=ET+pond_evaporation.'
  dst.soil_moisture_contract='Mass of water per bulk soil volume: 1000 * WC. Not kg kg-1 gravimetric moisture or profile-integrated storage.'
  dst.export_complete=0
  for k,v in src.variables.items():
   if k not in ('time','time_bounds','simulation_date','cell','depth','requested_depth','easting','northing','crs','vegetation_class','crop_model','water_fraction','dominant_land_fraction','row','col','landcover_input_flags','parent_cell_500m','native_model','canopy_reset_flag','GASST_flag'):continue
   t=dst.createVariable(k,str if v.dtype==str else v.dtype,v.dimensions)
   attrs={a:v.getncattr(a) for a in v.ncattrs() if a!='_FillValue'};t.setncatts(attrs);t[:]=v[:]
  cf=carbon_fraction(src['crop_model'][:]);seconds=(plain(src['time_bounds'])[:,1]-plain(src['time_bounds'])[:,0])*86400.
  assert np.all(seconds==86400.)
  c=dst.createVariable('crop_carbon_fraction','f8',('cell',),fill_value=np.nan);c.units='kg kg-1';c.long_name='CFRDM used in the native active crop file';c[:]=cf
  f=gpp_factor(cf,seconds)
  outputs={
   'ET':(10*(plain(src['TACT'])+plain(src['EACT'])+plain(src['EIC'])),'mm d-1','Requested evaporation from transpiration soil evaporation and native interception accounting','time: mean'),
   'pond_evaporation':(10*plain(src['EPD']),'mm d-1','Evaporation from ponded surface water excluded from ET','time: mean'),
   'soil_moisture':(plain(src['WC'])*RHO_WATER_KG_M3,'kg m-3','Water mass per bulk volume of soil at actual compartment centre','time: point'),
   'soil_temperature':(plain(src['T']),'degree_Celsius','Soil temperature at actual compartment centre','time: point'),
   'GPP':(plain(src['GASST'])*f,'umol m-2 s-1','Gross CO2 assimilation equivalent retaining native management and stress effects as a 24 hour mean','time: mean'),
   'independent_balance_residual':(plain(src['independent_balance_residual'])*10,'mm','Native external exchange minus change of consecutive printed soil pond and canopy stores','time: sum')}
  outputs['ET_including_pond']=(outputs['ET'][0]+outputs['pond_evaporation'][0],'mm d-1','Requested evaporation plus evaporation from ponded water','time: mean')
  for k,(a,unit,name,method) in outputs.items():
   dims=('time','cell','depth') if a.ndim==3 else ('time','cell');chunks=(32,64,5) if a.ndim==3 else (32,64)
   v=dst.createVariable(k,'f4' if a.ndim==3 else 'f8',dims,fill_value=np.nan,zlib=True,complevel=4,shuffle=True,fletcher32=True,chunksizes=chunks)
   v.units=unit;v.long_name=name;v.cell_methods=method;v.coordinates='easting northing';v.grid_mapping='crs';v[:]=a
   if k=='GPP':v.positive='uptake';v.substance='CO2';v.ancillary_variables='GASST_flag crop_carbon_fraction'
   if k in ('ET','ET_including_pond'):v.ancillary_variables='canopy_reset_flag'
  dst.export_complete=1
 tmp.replace(destination)
 return {'source_file':source.name,'source_sha256':sha(source),'file':destination.name,'bytes':destination.stat().st_size,'sha256':sha(destination)}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('destination',type=Path);a=p.parse_args();print(json.dumps(convert(a.source,a.destination),indent=2))
