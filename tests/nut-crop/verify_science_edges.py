"""Supplementary real crop driver proof; no replacement of primary science."""
from pathlib import Path
import base64,hashlib,io,json,tarfile

MARKER='CROP_SOIL_JUVENILE_LITERAL_OVERSUPPLY_FULL_FIXATION_RFTRA_THRESHOLD=PASS'
SOURCE='c5662a5f77cca5d77c70921ec2d327c9436dbc3a'
def check(ok,label):
 if not ok:raise ValueError(label)
def read(root):
 s=json.loads((root/'integration/audits/MC_NUT01_CROP_SUPPLY_STATUS.json').read_text())['extension_evidence']
 raw=base64.b64decode((root/s['path']).read_bytes())
 check(hashlib.sha256(raw).hexdigest()==s['sha256'],'extension capsule drift')
 with tarfile.open(fileobj=io.BytesIO(raw))as a:
  ms=a.getmembers();check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe extension')
  check(len({m.name for m in ms})==len(ms),'duplicate extension member')
  data={m.name:a.extractfile(m).read()for m in ms}
 manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'extension manifest coverage')
 for p,h in manifest.items():check(hashlib.sha256(data[p]).hexdigest()==h,'extension raw drift')
 return data
def validate(root,primary,data):
 r=json.loads(data['result.json']);events=json.loads(data['events.json'])
 check(r['status']=='PASS'and r['source_tree']==SOURCE,'unfinished or stale crop edges')
 check(r['primary_result_sha256']==hashlib.sha256(primary['result.json']).hexdigest(),'wrong crop edge binding')
 required={'tests/nut-crop/test_crop_supply_edges.f90','tests/nut-crop/run_science_edges.py','tests/nut-crop/crop_fixture.inc','tests/nut-reactive/reactive_parameters.inc'}
 check(set(r['input_sha256'])==required,'incomplete edge inputs')
 for p,h in r['input_sha256'].items():check(hashlib.sha256((root/p).read_bytes()).hexdigest()==h,'crop edge input drift')
 for opt in ['O0','O2']:
  row=r['runs'][opt];check(MARKER in row['stdout'],'missing crop edge science')
  check(len(row['artifacts_before'])>=500 and row['artifacts_before']==row['artifacts_after'],'crop edge provider drift')
  old=json.loads(primary['restart_expectations/result.json'])['runs'][opt]['artifacts_after']
  check(row['artifacts_before']==old,'different primary providers')
  selected=[e for e in events if '/'+opt+'/'in e['command'][0]or any('/'+opt+'/'in a for a in e['command'][1:])]
  check([e['category']for e in selected]==['compile','link','native'],'crop edge execution matrix')
  check(data[selected[-1]['stdout_file']].decode()==row['stdout'],'crop edge native identity')
  for e in selected[:2]:check('-'+opt in e['command']and '-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'unchecked crop edges')
 check(len(events)==6,'crop edge event coverage')
 for e in events:
  check(e['returncode']==0 and e['seconds']>=0,'failed crop edge event')
  for stream in ['stdout','stderr']:check(hashlib.sha256(data[e[stream+'_file']]).hexdigest()==e[stream+'_sha256'],'crop edge raw event drift')
 return r
