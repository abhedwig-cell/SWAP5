"""Preserve successful and rejected research; no production admission."""
import hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];files={};reports={}
folders={'geometry':'/tmp/perf01-geometry-screen-v2','boesten':'/tmp/perf01-boesten-screen-v6','combined':'/tmp/perf01-combined-screen-v7','O0':'/tmp/perf01-combined-O0','failed-interface':'/tmp/perf01-geometry-screen','rejected-boesten-v3':'/tmp/perf01-boesten-screen-v3','rejected-boesten-v4':'/tmp/perf01-boesten-screen-v4','rejected-boesten-v5':'/tmp/perf01-boesten-screen-v5'}
sha=lambda b:hashlib.sha256(b).hexdigest()
for label,path in folders.items():
 folder=Path(path)
 for p in folder.rglob('*'):
  if not p.is_file()or p.suffix in ['.o','.mod','.a']:continue
  b=p.read_bytes()
  if not b.startswith(b'\x7fELF'):files[label+'/'+str(p.relative_to(folder))]=b
 if label in ['geometry','boesten','combined','O0']:
  r=json.loads((folder/'RESULT.json').read_text());assert r['status']=='GEOMETRY_RESEARCH_SCREEN_COMPLETED'and all(v['physical_screen_pass']for v in r['cases'].values());reports[label]=r['cases']
for rain in [1,4]:
 for arm in ['head','flux']:
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert(Path(folders['O0'])/f'8-{rain}'/arm/name).read_bytes()==(Path(folders['combined'])/f'8-{rain}'/arm/name).read_bytes(),('O0/O2 drift',rain,arm,name)
checks=json.loads((Path(folders['combined'])/'RESTART_CHECK.json').read_text());assert len(checks)==4 and all(v['restart_exact']and v['max_total_evaporation_difference_mm']<.01 for v in checks.values())
result=dict(status='RESEARCH_GEOMETRY_BOESTEN_PICARD_O2_AND_SELECTED_O0_PASS',production_qualified=False,production_changed=False,
 scope='120cm8/24 cells; zero tracer; lookup hydraulics; prescribed bottom; full97day1x/4x. O0 eight-cell subset byte-exact to O2; O2 combined day48 restart exact.',cases=reports,restarts=checks,
 open_scope=['continuous MvG Picard','seasonal historical forcing','implicit solute transport','positive chemistry','full481day combined project','current production owner qualification'])
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(files.items())},indent=2).encode()
target=ROOT/'benchmarks/performance/PERF01_GEOMETRY_BOESTEN_20261024_EVIDENCE.tar.xz'
with tarfile.open(target,'w:xz')as t:
 for p,b in sorted(files.items()):m=tarfile.TarInfo(p);m.size=len(b);t.addfile(m,io.BytesIO(b))
result['evidence']=dict(path=str(target.relative_to(ROOT)),sha256=sha(target.read_bytes()),members=len(files))
(ROOT/'benchmarks/performance/PERF01_GEOMETRY_BOESTEN_20261024_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['evidence']))
