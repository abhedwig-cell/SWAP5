"""Prepare the locally refined 250m grid for numerical heat and SWAP-WOFOST."""
from pathlib import Path
from collections import Counter
import argparse,csv,hashlib,json,math,os,re,shutil

REQUESTED='RAIN,RUNOFF,IRRIG,DRN,BOT,EPOT,EACT,TPOT,TACT,EPD,EIC,DSTOR,BALDEV,GASST,GWL,WC[-10.0;-20.0;-40.0;-80.0;-160.0],T[-10.0;-20.0;-40.0;-80.0;-160.0]'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def setting(s,key,value):
    s,n=re.subn(r'(?m)^(\s*'+key+r'\s*=)[^\n]*',lambda m:m[1]+' '+str(value),s)
    assert n==1,(key,n)
    return s
def table(s,header,body):
    s,n=re.subn(r'(?m)^\s*'+re.escape(header)+r'\s*\n.*?^\s*\* End of table',header+'\n'+body+'\n* End of table',s,flags=re.S)
    assert n==1,(header,n)
    return s
def prepare(root,base,distribution,limit=None):
    root.mkdir(exist_ok=True,parents=True)
    (root/'forcing').mkdir(exist_ok=True);(root/'crops').mkdir(exist_ok=True);(root/'cells').mkdir(exist_ok=True)
    for f in (base/'model/forcing').iterdir():shutil.copyfile(f,root/'forcing'/f.name)
    with (root/'forcing/hourly.met').open() as f:met=list(csv.DictReader((l for l in f if not l.startswith('*')),delimiter=' '))
    surface=sum(float(r['TEMP']) for r in met[:24])/24
    deep=sum(float(r['TEMP']) for r in met if r['DATE'].startswith('2024'))/(366*24)
    crop_changes={'SWCO2':0,'SWSALINITY':0}
    for name in ('maize','grass'):
        s=(distribution/'data/crops/dynamic'/f'{name}.crp').read_text()
        for key,val in crop_changes.items():s=setting(s,key,val)
        (root/'crops'/f'{name}.crp').write_text(s)
    rows=list(csv.DictReader((base/'model_local/cell_register.csv').open()))
    if limit:rows=rows[:limit]
    counts=Counter()
    for row in rows:
        identity=row['cell_id'];source=base/'model_local/cells'/identity;dest=root/'cells'/identity;dest.mkdir(exist_ok=True)
        m=json.loads((source/'cell_manifest.json').read_text());s=(source/'swap.swp').read_text()
        s=setting(s,'SWHEA',1);s=setting(s,'SWCALT',2);s=setting(s,'SWTOPBHEA',1);s=setting(s,'SWBOTBHEA',1)
        thermal=[]
        for layer in m['layers']:
            raw=layer['used_inputs_raw_units'];total=sum(float(raw[k]) for k in ('sand','silt','clay'))
            fractions=[float(raw[k])/total for k in ('sand','silt','clay')]
            om=1.724*float(layer['used_soc_percent'])/100
            assert 0<=om<1
            thermal.append(' '.join(f'{x:.12e}' for x in (*fractions,om)))
        s=table(s,'PSAND PSILT PCLAY ORGMAT','\n'.join(thermal))
        s=table(s,'TSOILTB =',f'0.0 {surface:.12e}\n-200.0 {deep:.12e}')
        s=setting(s,'INLIST_CSV',repr(REQUESTED+',WTOT,PD_VOL,IC_VOL'))
        s=setting(s,'SWCSV',1)
        s+='\nNUM_DECIMALS = 8\n'
        code=int(row['dominant_land_class']);kind={30:'grass',40:'maize'}.get(code,'prescribed')
        files=[]
        if kind!='prescribed':
            periods=[]
            for year in (2024,2025,2026):
                start,end=(f'{year}-01-01',f'{year}-12-31') if kind=='grass' else (f'{year}-05-01',f'{year}-10-15')
                periods.append(f"{start} {end} '{kind}' 2")
            s=table(s,'CROPSTART    CROPEND  CROPFIL CROPTYPE','\n'.join(periods))
            target=dest/(kind+'.crp')
            if target.is_symlink():target.unlink()
            target.symlink_to(Path('../../crops')/(kind+'.crp'));files.append(target.name)
        else:
            for f in source.glob('*.crp'):
                shutil.copyfile(f,dest/f.name);files.append(f.name)
        for name in ('hourly.met','kalmthout.rain'):
            target=dest/name
            if target.is_symlink():target.unlink()
            target.symlink_to(Path('../../forcing')/name);files.append(name)
        (dest/'swap.swp').write_text(s);files.append('swap.swp')
        m.update(model_version='V02_LOCAL_WOFOST_NUMERICAL_HEAT',crop_model=kind,heat={'SWHEA':1,'SWCALT':2,'top_boundary':'air temperature','bottom_boundary':'zero heat flux','initial_surface_C':surface,'initial_200cm_C':deep,'initial_profile':'linear; not a measured profile; no spin-up','orgmat':'SoilGrids SOC mass fraction *1.724; explicit conversion assumption'},input_sha256={f:sha(dest/f) for f in files})
        if kind!='prescribed':
            m['vegetation_v01_reference']=m['vegetation']
            m['vegetation']={'name':'WOFOST_'+kind,'parameter_file':kind+'.crp','parameter_source':'SWAP4.3.1 data/crops/dynamic','prescribed_LAI':False,'management':'source grass biomass-dependent mowing' if kind=='grass' else 'assumed annual maize1May-15Oct; source germination retained'}
        extra=['NUMERICAL_HEAT_AIR_TOP_NO_SPINUP','THERMAL_ORGMAT_FROM_SOC_FACTOR_1_724']
        if kind!='prescribed':extra+=['CO2_CORRECTION_OFF', 'MAIZE_PROXY_NOT_OBSERVED_ROTATION' if kind=='maize' else 'WOFOST_GRASS_STANDARD_MANAGEMENT_PRIOR']
        m['flags']=list(dict.fromkeys(m['flags']+extra));row['flags']=';'.join(dict.fromkeys(row['flags'].split(';')+extra))
        (dest/'cell_manifest.json').write_text(json.dumps(m,indent=2)+'\n')
        row.update(crop_model=kind,native_model='SWAP_WOFOST_'+kind.upper() if kind!='prescribed' else 'SWAP_PRESCRIBED_VEGETATION',heat_module='NUMERICAL',status='PREPARED_V02');counts[kind]+=1
    with (root/'cell_register.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    shutil.copyfile(base/'model_local/grid_250m.geojson',root/'grid_250m.geojson')
    receipt={'cells':len(rows),'crop_counts':dict(counts),'requested_output':REQUESTED,'crop_sources':'Original SWAP4.3.1 distribution data/crops/dynamic; archive SHA256 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360','crop_overrides':crop_changes,'override_reasons':{'SWCO2':'No SSP5-8.5 projection substituted for historical CO2; source base response retained.','SWSALINITY':'No solute simulation or observed salinity in this regional setup.'},'annual_crop_prior':'Maize annually 1May-15Oct; source germination and harvest switches retained; not observed crop rotation','grass_prior':'Source WOFOST grass with annual calendar and biomass-dependent mowing; applies to mapped grass class, which may include unmanaged grass','prescribed_vegetation':'Forest, heath, urban soil surrogate and wetland retain LAI route; GASST unavailable','heat_initialization':{'surface_C':surface,'200cm_C':deep,'basis':'First day and annual2024 mean of the same ERA5 air-temperature series; linear initial profile; no spin-up'},'status':'PREPARED_NOT_YET_EXECUTED'}
    (root/'preparation.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('--base',type=Path,default=Path('baseline'));p.add_argument('--distribution',type=Path,default=Path('sources/distribution/SWAP_4.3.1'));a=p.parse_args();prepare(a.root,a.base,a.distribution)
