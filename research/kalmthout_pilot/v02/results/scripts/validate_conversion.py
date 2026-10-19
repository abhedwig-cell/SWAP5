"""Independent dimensional and complete-array checks for the candidate products."""
from pathlib import Path
import argparse,json
import numpy as np
from netCDF4 import Dataset
from convert_symphonica import plain,sha,convert

def main(source,root,rebuild=False):
 receipts=[];checks=[]
 for year in (2024,2025,2026):
  src=source/f'Kalmthout_SW431_V02_daily_{year}.nc';product=root/'products'/f'SYMPHONICA_Kalmthout_V02_daily_{year}.nc'
  if rebuild:receipts.append(convert(src,product))
  with Dataset(src) as s,Dataset(product) as d:
   assert d.source_sha256==sha(src) and d.export_complete==1
   assert np.array_equal(s['time'][:],d['time'][:]) and np.array_equal(s['time_bounds'][:],d['time_bounds'][:])
   assert np.array_equal(s['cell'][:],d['cell'][:]) and np.array_equal(s['depth'][:],d['depth'][:])
   expected=10*(plain(s['TACT'])+plain(s['EACT'])+plain(s['EIC']));assert np.array_equal(plain(d['ET']),expected)
   assert np.allclose(plain(d['ET_including_pond'])-plain(d['ET']),10*plain(s['EPD']),atol=1e-14,rtol=0)
   wc=plain(s['WC'])*1000;err=float(np.max(np.abs(plain(d['soil_moisture'])-wc)));assert err<4e-5
   assert np.array_equal(plain(s['T']),plain(d['soil_temperature']))
   native=plain(s['GASST']);gpp=plain(d['GPP']);crop=np.array(s['crop_model'][:]);flags=np.array(s['GASST_flag'][:]);nd=len(s.dimensions['time'])
   for name,fraction in [('grass',.45),('maize',.4)]:
    sel=crop==name
    # Invert the mole flux to daily carbon mass per area, without the converter's factor helper.
    carbon_from_GPP=gpp[:,sel]*86400/1e6*12 # g C m-2 per daily interval
    carbon_native=native[:,sel]*fraction/10 # kg ha-1 to g m-2
    assert np.allclose(carbon_from_GPP,carbon_native,atol=2e-14,rtol=2e-15)
   assert np.all(np.isnan(gpp[:,crop=='prescribed']))
   assert np.all(gpp[flags==1]==0) and np.all(np.isfinite(gpp[flags==0]))
   assert np.array_equal(d['GASST_flag'][:],s['GASST_flag'][:]) and np.array_equal(d['canopy_reset_flag'][:],s['canopy_reset_flag'][:])
   assert d['GPP'].units=='umol m-2 s-1' and d['GPP'].substance=='CO2'
   assert np.array_equal(plain(d['independent_balance_residual']),10*plain(s['independent_balance_residual']))
   checks.append({'year':year,'all_cells':len(s.dimensions['cell']),'days':nd,'depths':5,'ET_exact':True,'GPP_carbon_inverse_all_arrays':True,'GPP_flag_preservation':True,'soil_temperature_exact':True,'max_moisture_rounding_kg_m3':err,'product_sha256':sha(product)})
 if receipts:
  p=root/'evidence/analysis_summary.json';r=json.loads(p.read_text());r['conversion_products']=receipts;p.write_text(json.dumps(r,indent=2)+'\n')
 report={'status':'PASS','unit_examples':{'WC_0_25_kg_m3':250,'ET_T_0_2_E_0_05_IC_0_03_cm_mm_d':2.8,'GASST_100_grass_umol_m2_s':100*.45*1000/12/10000*1e6/86400,'GASST_100_maize_umol_m2_s':100*.4*1000/12/10000*1e6/86400},'checks':checks}
 (root/'evidence/conversion_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('root',type=Path);p.add_argument('--rebuild',action='store_true');a=p.parse_args();main(a.source,a.root,a.rebuild)
