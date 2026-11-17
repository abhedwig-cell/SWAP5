"""Seal and independently reread the actual reference outputs, not another model."""
from pathlib import Path
import argparse,csv,hashlib,io,json,math,zipfile

sha=lambda b:hashlib.sha256(b).hexdigest()
ROOT=Path(__file__).resolve().parents[2]

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--ubuntu',type=Path);p.add_argument('--own-ubuntu',type=Path);p.add_argument('--windows',type=Path);p.add_argument('--verify',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
 if not a.verify:
  assert a.ubuntu and a.own_ubuntu and a.windows
  folders={
   'windows/adaptive-O2':a.windows/'local-wetting-independent01',
   'windows/adaptive-O0':a.windows/'local-wetting-independent-O0',
   'windows/nominal-replay':a.windows/'local-wetting-independent-nominal-replay',
   'windows/fine-replay':a.windows/'local-wetting-independent-replay',
   'target/fine-grid':a.windows/'local-wetting-independent-grid',
   'target/nominal-grid':a.windows/'local-wetting-independent-nominal-grid'}
  assets={};files={};archive=out/'RAW.zip';excluded={'.exe','.dll','.o','.mod','.smod','.a','.pyc'}
  with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
   def add(name,data):
    if Path(name).suffix.lower() in excluded or Path(name).name in ('original_reference','day_donor','day_kernel'):return
    h=sha(data);files[name]={'sha256':h,'bytes':len(data)}
    if h not in assets:z.writestr('sha256/'+h,data);assets[h]='sha256/'+h
   for label,folder in folders.items():
    for f in sorted(folder.rglob('*')):
     if f.is_file():add(label+'/'+f.relative_to(folder).as_posix(),f.read_bytes())
   with zipfile.ZipFile(a.ubuntu) as incoming:
    for n in incoming.namelist():
     if not n.endswith('/'):add('ubuntu/'+n,incoming.read(n))
   with zipfile.ZipFile(a.own_ubuntu) as incoming:
    for n in incoming.namelist():
     if not n.endswith('/'):add('ubuntu-own/'+n,incoming.read(n))
  index=json.dumps({'files':files,'assets':assets},indent=2).encode();(out/'RAW.json').write_bytes(index);(out/'SEAL.json').write_bytes(json.dumps({'archive_sha256':sha(archive.read_bytes()),'index_sha256':sha(index),'ubuntu_artifact_sha256':sha(a.ubuntu.read_bytes()),'own_ubuntu_artifact_sha256':sha(a.own_ubuntu.read_bytes()),'paths':len(files),'unique_assets':len(assets)},indent=2).encode())
 seal=json.loads((out/'SEAL.json').read_bytes());index=(out/'RAW.json').read_bytes();assert sha(index)==seal['index_sha256'];assert sha((out/'RAW.zip').read_bytes())==seal['archive_sha256'];idx=json.loads(index)
 with zipfile.ZipFile(out/'RAW.zip') as z:
  for h,n in idx['assets'].items():assert sha(z.read(n))==h
  def read(name):
   m=idx['files'][name];data=z.read(idx['assets'][m['sha256']]);assert len(data)==m['bytes'];return data
  reports={}
  for label in ('windows/adaptive-O2','windows/adaptive-O0','windows/nominal-replay','windows/fine-replay','ubuntu/adaptive','ubuntu/nominal-replay','ubuntu/fine-replay'):
   reports[label]=json.loads(read(label+'/RESULT.json'))
  fixture=json.loads((out/'INPUT.json').read_bytes());assert sha((out/'INPUT.zip').read_bytes())==fixture['zip_sha256']
  with zipfile.ZipFile(out/'INPUT.zip') as f:target=json.loads(f.read('TARGET.json'))
  record={'status':'QUALIFIED_BOUNDED_INDEPENDENT_NUMERICAL_ATTRIBUTION','source_scope':'original431 Newton/residual/control; no production HeadCalc or budget object','window_days':[363,364,365],'water_guard_cm':1e-10,'input_tolerances_changed':False,'full_nominal_equivalence':'FAIL_PRESERVED','universal_reference_qualification':'NOT_CLAIMED','production_GWL_error_bound':'NOT_CLAIMED','platforms':{},'reference_models':0,'reference_days':0,'maximum_BALDEV_cm':0.0}
  for platform in ('windows','ubuntu'):
   all_profiles={}
   labels=['windows/adaptive-O0','windows/adaptive-O2','windows/nominal-replay','windows/fine-replay'] if platform=='windows' else ['ubuntu/adaptive','ubuntu/nominal-replay','ubuntu/fine-replay']
   for label in labels:
    report=reports[label];assert not report['production_imports'] and not report['shared_swap5_headcalc'] and not report['shared_swap5_mass_guard'] and report['water_guard_cm']==1e-10
    for name,r in report['profiles'].items():
     key=('nominal' if label.endswith('nominal-replay') else 'fine' if label.endswith('fine-replay') else 'adaptive')+'/'+name
     assert r['status']=='COMPLETE_INDEPENDENT_ORIGINAL_BALANCE_PASS' and r['returncode']==100 and r['seconds']<=20
     body=read(label+'/'+name+'-build/headcalc.f90');assert sha(body)==r['source_sha256']['headcalc.f90'];assert b'hybrid_' not in body.lower() and b'projected_water_residual' not in body
     linked=[p.replace('\\','/') for p in r['linked_objects']];assert all('/swap-obj/' in p or p.endswith(('/swap.o','/headcalc.o')) for p in linked);assert not any('hybrid' in p.lower() for p in linked)
     for n,v in fixture['files'].items():
      if n.startswith('seed/'):assert r['inputs'][n[5:]]==v['sha256']
     raw=read(label+'/'+name+'/result_output.csv').decode('cp1252');rows=list(csv.DictReader(s for s in raw.splitlines() if s and not s.startswith('*')));assert len(rows)==4 and rows[0]==r['initial'] and rows[1:]==r['daily']
     assert float(rows[0]['WTOT'])==target['initial_saved_day362_WTOT_cm']
     for row in rows[1:]:assert math.isfinite(float(row['GWL'])) and abs(float(row['BALDEV']))<=1e-10 and float(row['IRRIG'])==0
     if key.startswith(('nominal/','fine/')):
      assert r['accepted_grid_exact'] and r['accepted_steps']==(449 if key.startswith('nominal/') else 120008)
      logged=[tuple(map(float,s.split()[1:])) for s in read(label+'/'+name+'/stdout').decode().splitlines() if s.startswith('INDEPENDENT_ACCEPTED_GRID')];expected=[tuple(map(float,s.split())) for s in read(label+'/'+name+'/reference-grid.txt').decode().splitlines()];assert logged==expected
     record['maximum_BALDEV_cm']=max(record['maximum_BALDEV_cm'],max(abs(float(row['BALDEV'])) for row in rows[1:]))
     all_profiles[key]=dict(day364_GWL_cm=float(rows[2]['GWL']),seconds=r['seconds'],max_BALDEV_cm=max(abs(float(row['BALDEV'])) for row in rows[1:]));record['reference_models']+=1;record['reference_days']+=3
   data={};opt_diff=0.
   for route,cap in [('adaptive',.0004),('adaptive',.0001),('adaptive',.000025),('nominal',.04),('fine',.000025)]:
    name=format(cap,'.9g').replace('.','p');u=all_profiles[route+'/O0-'+name];v=all_profiles[route+'/O2-'+name];opt_diff=max(opt_diff,abs(u['day364_GWL_cm']-v['day364_GWL_cm']));data[route+'_'+name]=v['day364_GWL_cm']
   changes=[abs(data['adaptive_0p0004']-data['adaptive_0p0001']),abs(data['adaptive_0p0001']-data['adaptive_2p5e-05'])];assert changes[1]<changes[0]
   data.update(same_nominal_grid_difference_cm=target['target_nominal_day364_GWL_cm']-data['nominal_0p04'],same_fine_grid_difference_cm=target['target_fine_day364_GWL_cm']-data['fine_2p5e-05'],reference_refinement_changes_cm=changes,observed_refinement_order=math.log(changes[0]/changes[1],4),maximum_O0_O2_GWL_difference_cm=opt_diff,maximum_model_seconds=max(v['seconds'] for v in all_profiles.values()))
   record['platforms'][platform]=data
  assert (record['reference_models'],record['reference_days'])==(20,60)
  # Separate the same-input portable test above from Ubuntu's actual own
  # nominal trajectory. Its saved state and accepted grid are independently
  # observed and must not be silently replaced by the Windows fixture.
  own=json.loads(read('ubuntu-own/owned/OWN_TARGET.json'));capture=json.loads(read('ubuntu-own/capture/RESULT.json'));assert capture['status']=='GRID_OBSERVER_PHYSICAL_EXACT'
  own_values={}
  for mode in ('own-adaptive','own-replay'):
   label='ubuntu-own/'+mode;report=json.loads(read(label+'/RESULT.json'));assert not report['shared_swap5_headcalc'] and not report['shared_swap5_mass_guard']
   for name,r in report['profiles'].items():
    assert r['status']=='COMPLETE_INDEPENDENT_ORIGINAL_BALANCE_PASS' and r['seconds']<=20
    rows=list(csv.DictReader(s for s in read(label+'/'+name+'/result_output.csv').decode('cp1252').splitlines() if s and not s.startswith('*')));assert len(rows)==4 and rows[1:]==r['daily']
    assert float(rows[0]['WTOT'])==float(own['initial']['WTOT']) and float(rows[0]['PD_VOL'])==float(own['initial']['PD_VOL'])
    body=read(label+'/'+name+'-build/headcalc.f90');assert sha(body)==r['source_sha256']['headcalc.f90'] and b'hybrid_' not in body.lower()
    for n,v in r['inputs'].items():
     assert sha(read(label+'/'+name+'/'+n))==v
     if n!='reference-grid.txt':assert sha(read('ubuntu-own/owned/seed/'+n))==v
    assert max(abs(float(v['BALDEV'])) for v in rows[1:])<=1e-10
    record['maximum_BALDEV_cm']=max(record['maximum_BALDEV_cm'],max(abs(float(v['BALDEV'])) for v in rows[1:]))
    if mode=='own-replay':
     assert r['accepted_grid_exact'] and r['accepted_steps']==capture['steps']==456
     expected=[tuple(map(float,s.split())) for s in read('ubuntu-own/owned/own-grid.txt').decode().splitlines()];observed=[tuple(map(float,s.split()[1:])) for s in read(label+'/'+name+'/stdout').decode().splitlines() if s.startswith('INDEPENDENT_ACCEPTED_GRID')];assert observed==expected
    own_values[mode+'/'+name]={'day364_GWL_cm':float(rows[2]['GWL']),'seconds':r['seconds']};record['reference_models']+=1;record['reference_days']+=3
  assert (record['reference_models'],record['reference_days'])==(28,84)
  own_ref=own_values['own-replay/O2-0p04']['day364_GWL_cm'];record['ubuntu_owned_trajectory']={'target_GWL_cm':float(own['nominal_day364']['GWL']),'reference_GWL_cm':own_ref,'same_nominal_grid_difference_cm':float(own['nominal_day364']['GWL'])-own_ref,'saved_stock_cm':float(own['initial']['WTOT']),'accepted_steps':456,'capture_seconds':capture['seconds'],'profiles':own_values}
  record['interpretation']='Original independent physical solve reproduces target on both recorded time grids; original own refinement changes shrink; nominal B0 discrepancy classified as numerical time-grid/history sensitivity in this window. No new scientific tolerance or nominal-equivalence PASS is introduced.'
  (out/'QUALIFICATION.json').write_bytes(json.dumps(record,indent=2).encode());print(json.dumps(record,indent=2))
if __name__=='__main__':main()
