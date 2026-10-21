"""Discriminating source mutations; every changed component must fail natively."""
import argparse,json,os,pathlib,shutil,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
component='src/adapter/mod_soil_n_crop_extended_output.f90'
s=(ROOT/component).read_text()
changes={
 'uptake_units':('trial%totals(1)+1d4*u','trial%totals(1)+1d3*u'),
 'phosphorus_ratio':('trial%totals(2)+0.1d0*1d4*u','trial%totals(2)+0.2d0*1d4*u'),
 'surface_organ':('saved_dm_kg_ha(3)+saved_dm_kg_ha(4)','saved_dm_kg_ha(3)+saved_dm_kg_ha(1)'),
 'bottom_nitrogen':('trial%totals(7)+saved_n_kg_ha(1)','trial%totals(7)+saved_n_kg_ha(2)'),
 'residue_threshold':('trial%totals(3)>=1d-6','trial%totals(3)>=1d-5'),
 'report_reset':('trial%totals=0d0','trial%totals=1d0'),
 'minimum_extrema':('min(trial%extrema(1),','max(trial%extrema(1),'),
 'receipt_clock':('if(t0/=state%clock.or.t1<=t0.or.abs(t1)>1d8)return','if(t1<=t0.or.abs(t1)>1d8)return'),
 'empty_minima':('extrema(8)=[1d0,0d0,1d0,0d0,1d0,0d0,1d0,0d0]','extrema(8)=[0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0]')}
results={}
for name,(before,after)in changes.items():
 assert s.count(before)==1,name
 b=OUT/name;b.mkdir();repo=b/'repo'
 for path in [component,'tests/nut-output/test_crop_extended_output.f90','tests/nut-output/run_crop_extended_output.py','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64']:
  q=repo/path;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/path,q)
 (repo/component).write_text(s.replace(before,after,1))
 t=time.perf_counter();r=subprocess.run(['python',repo/'tests/nut-output/run_crop_extended_output.py','--output',b/'run'],capture_output=True)
 (b/'stdout').write_bytes(r.stdout);(b/'stderr').write_bytes(r.stderr)
 # A compilation or setup failure is not evidence that a science assertion works.
 events=json.loads((b/'run/events.json').read_text())
 assert events[0]['category']=='compile_link'and events[0]['returncode']==0,name
 assert events[-1]['category']=='native'and events[-1]['returncode']!=0,name
 assert b'FAIL:'in(b/'run'/events[-1]['stdout']).read_bytes(),name
 results[name]=dict(returncode=r.returncode,native_returncode=events[-1]['returncode'],seconds=time.perf_counter()-t,before=before,after=after)
 # Keep raw failed native receipts; omit duplicated immutable source archive.
 shutil.rmtree(repo)
(OUT/'result.json').write_text(json.dumps(dict(status='CROP_EXT_NINE_MUTATIONS_REJECTED',controls=results),indent=2)+'\n')
print('CROP_EXT_NINE_MUTATIONS_REJECTED')
