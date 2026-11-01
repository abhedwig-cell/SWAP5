"""Durable raw receipts for the bounded Grassgrowth endpoint-stock audit."""
import argparse,hashlib,io,json,subprocess,tarfile,tempfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from qualify_energy_stock import verify,ROOT,CAP
DEST=ROOT/'integration/dataqual15/SPRINT04_ENERGY_EVIDENCE.tar.xz'
META=DEST.with_name('SPRINT04_ENERGY_MANIFEST.json')
sha=lambda raw:hashlib.sha256(raw).hexdigest()

def summarize(windows,linux):
 reports={name:json.loads((folder/'RESULT.json').read_text())for name,folder in [('Windows',windows),('Linux',linux)]}
 assert reports['Windows']['source_sha256']==reports['Linux']['source_sha256']
 assert reports['Windows']['observations']==reports['Linux']['observations']
 for name in ['inputs.dat','input.swp']:assert(windows/name).read_bytes()==(linux/name).read_bytes()
 groups={};rows=reports['Linux']['observations']
 for kind,label in [(0,'fixed_water'),(1,'interpolated_water'),(2,'isothermal_5C_variable_water'),(3,'isothermal_0C_variable_water')]:
  subset=[r for r in rows if r['kind']==kind];worst=max(subset,key=lambda r:abs(r['endpoint_stock_minus_boundary']))
  groups[label]=dict(cases=len(subset),maximum_stock_minus_boundary_j_cm2=max(abs(r['endpoint_stock_minus_boundary'])for r in subset),maximum_stock_identity_residual_j_cm2=max(abs(r['stock_identity_residual'])for r in subset),maximum_independent_boundary_residual_j_cm2=max(abs(r['independent_boundary_residual'])for r in subset),maximum_temperature_change_c=max(r['maximum_temperature_change']for r in subset),worst_case=worst)
 return dict(status='REAL_OWNER_ENERGY_ACCOUNTING_SCOPE_RECONCILED',distinct_explicit_inputs=len(rows),native_executions=4,native_case_evaluations=4*len(rows),cross_platform_and_O0_O2_observations_exact=True,
  platforms={name:dict(compiler=r['compiler'],compile_link_native_seconds=sum(e['seconds']for e in r['events']),events=len(r['events']))for name,r in reports.items()},groups=groups,
  classification='RETAINED_CONDUCTION_EQUATION_ACCOUNTING_LIMITATION_NOT_A_NEWLY_DEMONSTRATED_IMPLEMENTATION_DIVERGENCE',
  identity='Delta(C*T) = Cmid*DeltaT + DeltaC*Tmid; reference temperature0C; valid linear unsaturated heat capacity.',
  scope='Same-state component probes from48 real bound Sprint03 snapshots. Interpolated adjacent-day water inputs and isothermal controls are explicit counterfactuals, not recorded accepted substeps or an application restart.',
  established='Real conduction storage and independently reconstructed top boundary heat agree within unchanged5e-9J/cm2; all endpoint stock differences are explained by capacity exchange to roundoff.',
  not_established='No attribution of unmeasured donor/water enthalpy, no whole1827-day physical energy ledger, no atmospheric/vegetation energy closure or physical-model promotion.',
  next_contract='Specify complete variable-water energy stock and its physical donor/advective exchange terms under existing energy ownership before claiming whole-project physical energy closure. Small conduction residual alone cannot supply those terms.',
  full_project_rerun=False,whole_project_energy_qualified=False,production_changed=False,canonical_modified=False)

def package(windows,linux,history):
 verify(windows);verify(linux);files={};summary=summarize(windows,linux)
 for label,folder in [('Windows',windows),('Linux',linux)]:
  r=json.loads((folder/'RESULT.json').read_text())
  for name in ['RESULT.json',*r['file_sha256']]:files[label+'/'+name]=(folder/name).read_bytes()
 if history:
  for p in history.rglob('*'):
   if p.is_file():files['history/'+p.relative_to(history).as_posix()]=p.read_bytes()
 files['SUMMARY.json']=(json.dumps(summary,indent=2)+'\n').encode()
 files['MANIFEST.json']=(json.dumps({k:sha(v)for k,v in sorted(files.items())},indent=2)+'\n').encode()
 with tarfile.open(DEST,'w:xz',preset=6)as t:
  for name,raw in sorted(files.items()):
   m=tarfile.TarInfo(name);m.size=len(raw);m.mtime=0;m.mode=0o644;t.addfile(m,io.BytesIO(raw))
 sources=dict(json.loads((linux/'RESULT.json').read_text())['source_sha256'])
 for p in [Path(__file__),ROOT/'.github/workflows/dataqual15-sprint04.yml']:sources[p.relative_to(ROOT).as_posix()]=sha(p.read_bytes())
 meta=dict(archive_sha256=sha(DEST.read_bytes()),archive_files=len(files),source_sha256=sources,predecessor_archive_sha256=sha(CAP.read_bytes()),production_trees={name:subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()for name in ['src','app','reference']},measurement_commit='d026fec23920778f2a2af4fa1891433e128f2df4',linux_run=41290599242,linux_job=124800855167,artifact_id=13077086748,artifact_zip_sha256='8ee2e6c6648df4db803a0b6d3e7a46f4e750d8b43cfc3e24dd6780e62d9acc22',whole_project_energy_qualified=False,canonical_modified=False)
 META.write_text(json.dumps(meta,indent=2)+'\n',newline='\n');print('PACKAGED',len(files),DEST.stat().st_size)

def consume():
 m=json.loads(META.read_text());assert sha(DEST.read_bytes())==m['archive_sha256']and sha(CAP.read_bytes())==m['predecessor_archive_sha256']
 for path,digest in m['source_sha256'].items():assert sha((ROOT/path).read_bytes())==digest,path
 for name,oid in m['production_trees'].items():assert subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=ROOT,text=True).strip()==oid
 with tarfile.open(DEST)as t:
  members=t.getmembers();assert len(members)==len({v.name for v in members})==m['archive_files'];files={}
  for v in members:
   p=PurePosixPath(v.name);assert v.isfile()and not p.is_absolute()and not PureWindowsPath(v.name).drive and '..'not in p.parts and '\\'not in v.name;files[v.name]=t.extractfile(v).read()
 assert json.loads(files.pop('MANIFEST.json'))=={k:sha(v)for k,v in files.items()}
 if 'history/RESULT.json'in files:
  failed=json.loads(files['history/RESULT.json']);assert failed['events'][-1]['label']=='link-O0'and failed['events'][-1]['returncode']!=0
  assert not any(e['label'].startswith('native-')for e in failed['events'])
  for name in ['energy_stock_driver.f90','qualify_energy_stock.py']:
   assert sha(files['history/source/'+name])==failed['source_sha256']['tests/dataqual15/'+name]
 with tempfile.TemporaryDirectory(prefix='swap5-energy-stock-',dir=ROOT.parent)as folder:
  root=Path(folder)
  assert root.resolve().parent==ROOT.parent.resolve()
  for name,raw in files.items():
   target=root.joinpath(*PurePosixPath(name).parts);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  verify(root/'Windows');verify(root/'Linux');assert summarize(root/'Windows',root/'Linux')==json.loads(files['SUMMARY.json'])
 print('SOURCE_BOUND_ENERGY_ACCOUNTING_SCOPE_EVIDENCE_PASS')
 return json.loads(files['SUMMARY.json'])

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--package',nargs=2,type=Path,metavar=('WINDOWS','LINUX'));p.add_argument('--history',type=Path);a=p.parse_args()
 if a.package:package(*a.package,a.history)
 else:consume()
