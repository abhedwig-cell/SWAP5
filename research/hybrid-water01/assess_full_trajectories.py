"""Reproduce complete preserved trajectory differences without executing models."""
import argparse
import csv
from datetime import date,timedelta
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess
import tempfile
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();begin=time.monotonic()
digest=lambda b:hashlib.sha256(b).hexdigest()
provenance={}
def read(name):
    path=ROOT/name;data=path.read_bytes();provenance[name]=digest(data.replace(b'\r\n',b'\n'));return json.loads(data)
def tar(name,expected,names):
    path=ROOT/name;assert digest(path.read_bytes())==expected;provenance[name]=expected;out={}
    selected=list(names)
    if name.startswith('research/hybrid-water01/hybrid-'):selected.append('MEMBER_SHA256.json')
    # Native streaming extraction avoids Python tarfile's costly large-member buffer copies.
    with tempfile.TemporaryDirectory(prefix='s5-whole-trajectory-read-') as temporary:
        scratch=Path(temporary).resolve()
        assert scratch.parent==Path(tempfile.gettempdir()).resolve() and scratch.name.startswith('s5-whole-trajectory-read-')
        subprocess.run(['tar','-xf',str(path),'-C',str(scratch),*selected],check=True,capture_output=True,timeout=30)
        out={n:(scratch/n).read_bytes() for n in selected}
    assert all(n in out for n in names)
    if 'MEMBER_SHA256.json' in out:
        members=json.loads(out['MEMBER_SHA256.json'])
        for n in names:assert digest(out[n])==members[n],n
    for n in names:provenance[name+'::'+n]=digest(out[n])
    return out
def records(data):return list(csv.DictReader(l for l in data.decode('utf-8-sig').splitlines() if l.strip() and not l.startswith('*')))
def stats(reference,current,dates,*,sentinel=False):
    pairs=[];only_reference=[];only_current=[];both_absent=0
    for i,(x,y) in enumerate(zip(reference,current)):
        assert math.isfinite(x) and math.isfinite(y)
        absent_x=sentinel and x==-999.999;absent_y=sentinel and y==-999.999
        if absent_x or absent_y:
            if absent_x and absent_y:both_absent+=1
            elif absent_x:only_current.append(dates[i])
            else:only_reference.append(dates[i])
            continue
        pairs.append((y-x,i,x,y))
    assert len(reference)==len(current)==len(dates)
    maximum=max(pairs,key=lambda x:abs(x[0])) if pairs else None
    return {'compared_days':len(pairs),'max_abs_difference':None if maximum is None else abs(maximum[0]),
        'worst':None if maximum is None else {'day':maximum[1]+1,'date':dates[maximum[1]],'reference':maximum[2],'current':maximum[3],'current_minus_reference':maximum[0]},
        'signed_sum_of_daily_differences':math.fsum(x[0] for x in pairs),
        'both_source_sentinel_days':both_absent,'reference_only_active_days':len(only_reference),'current_only_active_days':len(only_current),
        'first_active_scope_mismatch':min(only_reference+only_current) if only_reference or only_current else None}
def align(rows,ref,printed,start,n):
    assert len(rows)==len(ref)==len(printed)==n
    dates=[str(date.fromisoformat(start)+timedelta(days=i)) for i in range(n)]
    assert [r['day'] for r in rows]==list(range(1,n+1))
    assert [r['DATE'] for r in ref]==[r['DATE'] for r in printed]==dates
    assert all(r['committed'] for r in rows)
    return dates

grass_summary=read('research/hybrid-water01/HYBRID_GRASS_FULL_REFERENCE_20261111.json')
grass=tar('research/hybrid-water01/hybrid-grass-full-windows-20261111.tar.xz','cabfa1ba582b91838d9b5da851ae112ade5540e5b2d58020b94f6985094d40ad',
    ['full-trajectory/full/daily.jsonl','full-trajectory/full/original/result_output.csv'])
sealed=read('integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json')
b0=tar('integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz',sealed['evidence_sha256'],['dq15-original-nodal-reference/original/result_output.csv'])
grows=[json.loads(l) for l in grass['full-trajectory/full/daily.jsonl'].splitlines()]
gref=records(b0['dq15-original-nodal-reference/original/result_output.csv'])[1:];gprint=records(grass['full-trajectory/full/original/result_output.csv'])[1:]
gdates=align(grows,gref,gprint,'1980-01-01',1827)
assert digest(grass['full-trajectory/full/daily.jsonl'])==grass_summary['current_daily_sha256']
gfields={}
for key in ['WTOT','DSTOR','RAIN','EIC','TACT','EACT','BOT','GWL']:
    values=[]
    for r in grows:
        f=r['external_flux_cm'];values.append({'WTOT':math.fsum(r['stock_end_cm']),'DSTOR':math.fsum(r['stock_end_cm'])-math.fsum(r['stock_start_cm']),
            'RAIN':f[0],'EIC':f[7],'TACT':f[9],'EACT':f[11],'BOT':-r['bottom_outward_cm'],'GWL':r['groundwater_cm']}[key])
    gfields[key]=stats([float(r[key]) for r in gref],values,gdates)
    assert gfields[key]['max_abs_difference']==grass_summary['maximum_absolute_water_difference_cm'][key]
gcrop={k:stats([float(r[k]) for r in gref],[float(r[k]) for r in gprint],gdates,sentinel=True) for k in ['TPOT','TACT','TREDDRY','TREDWET','PHRVDM','HRVDM']}

hmeta=read('integration/dataqual15_hupsel/HIGH_PRECISION_REFERENCE.json')
hraw=tar('research/hybrid-water01/hybrid-hupsel-windows-20261111.tar.xz','678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1',
    ['hupsel-full/full/daily.jsonl','hupsel-full/full/original/result_output.csv','hupsel-O2/BUILD.json'])
hrefraw=tar('integration/dataqual15_hupsel/HIGH_PRECISION_REFERENCE.tar.xz',hmeta['evidence_sha256'],['reference/result_output.csv'])
assert digest(hrefraw['reference/result_output.csv'])==hmeta['output_sha256']
build=json.loads(hraw['hupsel-O2/BUILD.json']);assert build['inputs']==hmeta['original_inputs_sha256']
hrows=[json.loads(l) for l in hraw['hupsel-full/full/daily.jsonl'].splitlines()];hall=records(hrefraw['reference/result_output.csv']);href=hall[1:];hprint=records(hraw['hupsel-full/full/original/result_output.csv'])[1:]
hdates=align(hrows,href,hprint,'2002-01-01',1096)
hf={};hs={};uptake={};total_ref=[math.fsum(float(x[k]) for k in ['WTOT','PD_VOL','IC_VOL']) for x in hall]
for key in ['TOTAL_STOCK','SOIL_STOCK','POND','CANOPY','DSTOR_TOTAL','RAIN','IRRIG','RUNOFF','EIC','EACT','EPD','TACT','DRN','SSDI','GWL']:
    values=[];refs=[]
    column={'SOIL_STOCK':'WTOT','POND':'PD_VOL','CANOPY':'IC_VOL'}.get(key,key)
    for i,r in enumerate(hrows):
        f=r['external_flux_cm'];s=r['stock_end_cm'];old=r['stock_start_cm']
        values.append({'TOTAL_STOCK':math.fsum(s),'SOIL_STOCK':s[0],'POND':s[1],'CANOPY':s[3],'DSTOR_TOTAL':math.fsum(s)-math.fsum(old),
            'RAIN':f[0],'IRRIG':f[3],'RUNOFF':f[8],'EIC':f[7],'EACT':f[11],'EPD':f[10],'TACT':f[9],'DRN':r['drainage_outward_cm'],'SSDI':f[5],'GWL':r['groundwater_cm']}[key])
        refs.append(total_ref[i+1] if key=='TOTAL_STOCK' else total_ref[i+1]-total_ref[i] if key=='DSTOR_TOTAL' else float(href[i][column]))
    hf[key]=stats(refs,values,hdates)
for j,key in enumerate(['TPOT','TACT','TREDDRY','TREDWET','TREDSOL','TREDFRS']):
    if key in href[0]:uptake[key]=stats([float(x[key]) for x in href],[x['uptake_terms_cm'][j] for x in hrows],hdates)
for key,index in [('S_RAIN',2),('S_IRRIG',3),('S_DRN',5),('S_UPT',7),('S_STOT',0),('S_DSTOR',1),('S_BALDEV',8)]:
    hs[key]=stats([float(x[key]) for x in href],[x['solute_ledger_mg_cm2'][index] for x in hrows],hdates)
exclude=set(href[0]) & set(['DATE','RAIN','IRRIG','RUNOFF','EIC','EPD','EPOT','EACT','TPOT','TACT','TREDDRY','TREDWET','TREDSOL','DRN','SSDI','GWL','PD_VOL','IC_VOL','WTOT','DSTOR','BALDEV','S_RAIN','S_IRRIG','S_DRN','S_UPT','S_STOT','S_DSTOR','S_BALDEV'])
hcrop={key:stats([float(x[key]) for x in href],[float(x[key]) for x in hprint],hdates,sentinel=True) for key in href[0] if key not in exclude}
hscience=read('research/hybrid-water01/HYBRID_HUPSEL_REFERENCE_20261111.json')
assert hrows[583]['uptake_terms_cm'][3]==hscience['current_day584_oxygen_cm']

alineage=read('research/hybrid-water01/whole-period-andelst-reference-lineage-20261112.json')
q=ROOT/'research/hybrid-water01/whole-period-andelst-groundwater-20261112.csv';assert digest(q.read_bytes().replace(b'\r\n',b'\n'))==alineage['canonical_lf_csv_sha256'];provenance[q.relative_to(ROOT).as_posix()]=alineage['canonical_lf_csv_sha256'];acmp=records(q.read_bytes())
q=ROOT/'research/hybrid-water01/andelst-481-application-evidence.zip';assert digest(q.read_bytes())=='02570c194df9c712a61bbb2c678d4ed5cc216f2c4def9259885e48a5a3fe83f9';provenance[q.relative_to(ROOT).as_posix()]=digest(q.read_bytes())
with zipfile.ZipFile(q) as z:araw=z.read('full/daily.jsonl');apub=z.read('full/original/result_output.csv')
ar=read('research/hybrid-water01/andelst-481-application-receipt.json');assert digest(araw)==ar['ledger_sha256'];assert ar['result']['input_sha256']==alineage['original_inputs_sha256']
arows=[json.loads(l) for l in araw.splitlines()];aprint=records(apub)[1:];adates=align(arows,[{'DATE':r['date']} for r in acmp],aprint,'1998-01-01',481)
assert all(float(x['GWL'])==float(y['refreshed_gwl_cm']) for x,y in zip(aprint,acmp))
agwl=stats([float(r['original_gwl_cm']) for r in acmp],[float(r['GWL']) for r in aprint],adates)
assert round(agwl['max_abs_difference'],5)==alineage['prior_result']['max_abs_difference_from_original']['refreshed_minus_original_cm']
native_grass=read('research/hybrid-water01/grass-ahl-successor-receipt.json')['historical_comparison']
native_hupsel=read('integration/dataqual15_hupsel/PRESSURE_FILM_CANONICAL_RECEIPT_20261105.json')['original_science']
result={'status':'PRESERVED_FULL_TRAJECTORY_ASSESSMENT_REPRODUCED_NOT_WHOLE_SCIENCE','model_runs':0,'builds':0,
 'precision_policy':'All computed differences descriptive. No new physical/scientific tolerance or reference substitution. Stock/yield sums are descriptive sums, not all physical cumulative fluxes.',
 'source_data_sha256':provenance,'text_hash_policy':'Repository JSON/promoted CSV canonical LF; archives and archived member hashes are raw bytes. Original promoted CSV raw source member hash retained in lineage.',
 'grass_original_block':{'days':1827,'water_fields_cm':gfields,'printed_crop_fields_descriptive':gcrop,'reproduces_prior_whole_period_water_comparison':True,'day188_unrounded_uptake_cm':grows[187]['external_flux_cm'][9],
    'decision':'Water output agreement at original print precision; no unrounded oxygen/crop, native thermal accuracy or whole-science qualification.'},
 'hupsel_corrected_original_block':{'days':1096,'reference_identity':'Separate retained original high-precision-output trajectory, not the frozen native application oracle and not a newly qualified replacement reference.',
    'water_fields_cm':hf,'uptake_fields_cm':uptake,'solute_fields_mg_cm2':hs,'printed_crop_fields_descriptive':hcrop,'frozen_day584_comparison':hscience,
    'maximum_water_ledger_residual_cm':max(abs(x['independent_residual_cm']) for x in hrows),'maximum_solute_ledger_residual_mg_cm2':max(abs(x['solute_independent_residual_mg_cm2']) for x in hrows),
    'reference_internal_water_accounting':hmeta['independent_daily_water_comparison'],
    'decision':'Known corrected runoff/solute endpoint/harvest accounting and nonlinear policy change the trajectory; field-wise causality of remaining differences is unresolved. Original frozen day584 comparison remains FAIL; no substitute oracle selected.'},
 'andelst_hybrid':{'days':481,'gwl_print_comparison_cm':agwl,'water_ledger_sha256':digest(araw),'signed_water_ledger_residual_cm':math.fsum(x['independent_residual_cm'] for x in arows),
    'maximum_water_ledger_residual_cm':max(abs(x['independent_residual_cm']) for x in arows),'clock_scoped_policy_source':'app/hybrid_water/daily_host.py: shared_pond_transfer and refresh_macro_final generated scopes; not a universal original-physics identity.',
    'prior_registered_profile_disposition':alineage['prior_result'],'decision':'Retain clock-scoped corrected research-policy identity. Daily mass closure and restart do not qualify original trajectory or generic correctness of the clock-scoped numerical policy. Remaining day457 sensitivity has no qualified causal repair.'},
 'native_application_science':{'grass_registered_thermal':native_grass,'hupsel_pressure_film':native_hupsel,'decision':'Retained pinned native application results; do not transfer their criteria/counts to the original-block routes.'}}
a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':result['status'],'elapsed_seconds':time.monotonic()-begin,'days':{'grass':1827,'hupsel':1096,'andelst':481},
    'hupsel_water_maxima':{k:v['max_abs_difference'] for k,v in hf.items()},'hupsel_solute_maxima':{k:v['max_abs_difference'] for k,v in hs.items()},
    'hupsel_uptake_maxima':{k:v['max_abs_difference'] for k,v in uptake.items()},'andelst_gwl':agwl['worst']}))
