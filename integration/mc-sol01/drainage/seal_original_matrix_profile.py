"""Seal literal original-profile counterexample and independent-process replay."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];D=ROOT/'integration/mc-sol01/drainage';sha=lambda b:hashlib.sha256(b).hexdigest();f={}
def tree(root,prefix):
 for p in sorted(root.rglob('*')):
  if p.is_file():f[prefix+'/'+str(p.relative_to(root))]=p.read_bytes()
for opt in ['O0','O2']:
 root=ROOT.parent/('original-matrix-'+opt);tree(root,opt);r=json.loads((root/'BLOCKER.json').read_text())
 for p,h in r['input_sha256'].items():
  b=(ROOT/p).read_bytes();assert sha(b)==h;f['executed/'+p]=b
 f[opt+'/day9-native-invocation.json']=json.dumps(dict(command=['python','-B','tools/solute/run_project.py',str(root/'project/swap.swp'),'--bundle',str(ROOT.parent/('composed-final-'+opt)),'--native-hydraulics','--native-heat','--temporal-tolerance','.01','--solute-transport','implicit_upwind','--water-conductivity','picard_continuous','--surface-exfiltration','historical_zero','--stop-after','9','--output',str(root/'day9')],observed_returncode=0,timing='Native time in publication manifest; external elapsed UNKNOWN'),indent=2).encode()
for p in ROOT.parent.glob('original-matrix-frozen10.pending-*'):tree(p,'frozen/'+p.name.replace('original-matrix-frozen10.','full.'))
for ext in ['stdout','stderr']:f['frozen/'+ext]=(ROOT.parent/('original-matrix-frozen10.'+ext)).read_bytes()
f['frozen/invocation.json']=json.dumps(dict(observed_returncode=1,stop_after=10,water_conductivity='frozen',other_options='identical existing native input and build to O2 Picard case',timing='UNKNOWN')).encode()
f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz',preset=9)as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;t.addfile(m,io.BytesIO(b))
raw=buf.getvalue();ep='integration/mc-sol01/drainage/ORIGINAL_MATRIX_PROFILE_EVIDENCE.tar.xz.b64';(ROOT/ep).write_bytes(base64.b64encode(raw));s=json.loads((D/'ORIGINAL_MATRIX_PROFILE_STATUS.json').read_text());proof=[json.loads(f[o+'/BLOCKER.json'])for o in ['O0','O2']];assert proof[0]['accepted_prefix']==proof[1]['accepted_prefix'];files=['qualify_original_matrix_profile.py','reconcile_original_matrix_blocker.py','verify_original_matrix_profile.py','seal_original_matrix_profile.py','ORIGINAL_MATRIX_PROFILE_CONTRACT.md'];s.update(stage='REPRODUCED_TECHNICAL_BLOCKER',implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,full_original_application_status='BLOCKED',supported_work_packages='MC-NUT01/MC-SOL01 remain CLOSED WITH EXCLUSIONS',evidence=dict(path=ep,sha256=sha(raw),bytes=len(raw),members=len(f)),postimages={str((D/p).relative_to(ROOT)):sha((D/p).read_bytes())for p in files},blockers=[dict(kind='REPRODUCED_TECHNICAL',capability='Full original matrix profile/heat/crop481',observed=proof[0]['failure'],reproduced=['O0 full','O2 full','O0 independent day9 restart','O2 independent day9 restart']),dict(kind='MISSING_IMPLEMENTATION',capability='Original native macropore and Rutter interception composition',note='Neither excluded selector is counted as migrated')],remaining_evidence_blockers=[],accepted_prefix=proof[0]['accepted_prefix'],test_selection='Existing production executable source/compiler/flags/artifact identity retained; no production rebuild or unrelated broad suite selected',next_action='Integrate counterexample proof and verify actual canonical postimage; no full481 PASS or migration credit',recovery_point=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip());(D/'ORIGINAL_MATRIX_PROFILE_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps(s['evidence']))
