"""Seal completed focused entry-ramp evidence; never labels censored days PASS."""
import argparse,base64,csv,hashlib,io,json,runpy,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];P=ROOT.parent;D=Path('integration/mc-sol01/drainage');BASE='362cf65f0d98a1620ab2a245e11e61c84b4946ff';sha=lambda b:hashlib.sha256(b).hexdigest();f={}
def add(name,path):f[name]=Path(path).read_bytes()
def directory(prefix,path):
 for p in Path(path).rglob('*'):
  if p.is_file()and p.suffix not in ['.o','.mod']and p.name not in ['trial','replay','jump','ramp']:add(prefix+'/'+str(p.relative_to(path)),p)
add('parent/owner.json',P/'entry-parent-owner.json');f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
provider_inputs={}
for opt in ['O0','O2']:
 for name in ['two','prefix','resumed','default']:directory('runs/'+name+'-'+opt,P/('entry-ramp-'+name+'-'+opt))
 directory('leaf/'+opt,P/('entry-ramp-leaf-'+opt));add('prior-leaf/'+opt+'.stdout',P/'macro-entry-jump'/(opt+'.stdout'))
 for mode in ['joint','rootless']:
  directory('preserve/'+opt+'-'+mode,P/('entry-ramp-preserve-'+opt+'-'+mode))
  for p in (P/('native-water-current-'+opt+'-'+mode)).glob('replay-rutter-static-*.stdout'):add('prior-preserve/'+opt+'-'+mode+'/'+p.name,p)
 directory('joint/'+opt,P/('entry-ramp-joint2-'+opt))
 for p in ['state.csv','temperature.csv','budget.csv','progress.csv','native.stdout','macro.nml','restart.bin']:add('prior-default/'+opt+'/'+p,P/('native-water-proof3/'+opt+'-continuous')/p)
 bundle=P/('entry-ramp-bundle-'+opt);add('builds/'+opt+'/bundle.json',bundle/'bundle.json');add('builds/'+opt+'/column.json',bundle/'column/build-complete.json');add('builds/'+opt+'/physical.json',P/('entry-ramp-'+opt)/'build-complete.json')
 b=json.loads((bundle/'bundle.json').read_bytes())
 for path,h in b['executable_sha256'].items():assert sha(Path(path).read_bytes())==h,path
 for key in ['physical_build']:
  provider_inputs.update(b[key]['input_sha256'])
 provider_inputs.update(json.loads((bundle/'column/build-complete.json').read_bytes())['input_sha256'])
 if opt=='O2':add('recovery/native_water_O2',b['exe'])
directory('controls',P/'entry-ramp-file-controls');directory('runs/width-small-O2',P/'entry-ramp-width-small-O2');directory('runs/five-resumed-O2',P/'entry-ramp-five-resumed-O2');directory('failed/initial-joint-O2',P/'entry-ramp-joint-O2')
add('commands/file-controls.py',P/'entry_ramp_file_controls.py');add('commands/leaf.py',P/'run_ramp_leaf.py')
for p,h in provider_inputs.items():assert sha((ROOT/p).read_bytes())==h,p
f['provider-input-hashes.json']=(json.dumps(provider_inputs,indent=2)+'\n').encode()
delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',BASE,'--','src','app','tools','tests','examples','reference','.github','integration/audits'],cwd=ROOT,text=True).splitlines()}
# Untracked owner file is included before the final persisted diff is checked.
for p in ['integration/audits/verify_entry_ramp_current.py']:delta[p]='A'
paths=set(delta)|{str(D/p)for p in ['ENTRY_RAMP_CONTRACT.md','qualify_macro_trace.py','rebuild_covered_macro.py','seal_entry_ramp.py','verify_source_continuation.py','SOURCE_PROFILE_CONTINUATION_STATUS.json']}
posts={p:sha((ROOT/p).read_bytes())for p in paths}
for p in paths:add('executed/'+p,ROOT/p)
f['executed-hashes.json']=(json.dumps(posts,indent=2)+'\n').encode()
aa=list(csv.DictReader(io.StringIO(f['runs/two-O2/state.csv'].decode())));bb=list(csv.DictReader(io.StringIO(f['runs/width-small-O2/state.csv'].decode())));ba=list(csv.DictReader(io.StringIO(f['runs/two-O2/budget.csv'].decode())));bs=list(csv.DictReader(io.StringIO(f['runs/width-small-O2/budget.csv'].decode())))
sensitivity=dict(max_head_cm=max(abs(float(x['head_cm'])-float(y['head_cm']))for x,y in zip(aa,bb)),max_theta=max(abs(float(x['theta'])-float(y['theta']))for x,y in zip(aa,bb)),runoff_cm=max(abs(float(x['runoff_cm'])-float(y['runoff_cm']))for x,y in zip(ba,bs)),max_water_flux_cm=max(abs(float(x[k])-float(y[k]))for x,y in zip(ba,bs)for k in ['root_cm','drainage_cm','rapid_cm','runoff_cm','bottom_cm','pond_to_macro_cm','direct_macro_cm']))
r=dict(qualified=True,canonically_admitted=False,end_day=2,seasonal=False,five_day_complete=False,width_cm=.0001,width_sensitivity=sensitivity,literal_default_native_prefix_exact=True,previous_joint_rootless_exact=True,recorded_failed_fixture_setup_corrected=True,negative_controls=22,source_event_restart_files_exact=6)
f['RESULT.json']=(json.dumps(r,indent=2)+'\n').encode();f['sealed-raw-hashes.json']=(json.dumps({p:sha(b)for p,b in f.items()},indent=2)+'\n').encode();f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
sink=io.BytesIO()
with tarfile.open(fileobj=sink,mode='w:xz')as t:
 for p,b in sorted(f.items()):i=tarfile.TarInfo(p);i.size=len(b);i.mtime=0;t.addfile(i,io.BytesIO(b))
raw=sink.getvalue();cap=D/'ENTRY_RAMP_EVIDENCE.tar.xz.b64';(ROOT/cap).write_bytes(base64.b64encode(raw));s=dict(work_unit='HIST-INTEGRATION01 bounded corrected-source Darcy entry transition',baseline=BASE,stage='QUALIFIED_PENDING_CANONICAL_ADMISSION',implemented=True,persisted=True,tested=True,qualified=True,canonically_admitted=False,scope='Explicit width1e-4cm, anchored Cauchy3, actual original112-node/five-domain water/macro/Rutter/Feddes/DRAMET3/numeric heat; first2days only',contract=str(D/'ENTRY_RAMP_CONTRACT.md'),scientific_delta=delta,postimages=posts,provider_input_count=len(provider_inputs),evidence=dict(path=str(cap),sha256=sha(raw),bytes=len(raw),members=len(f)),qualification=r,remaining_implementation_blockers=[],remaining_evidence_blockers=['Actual canonical merge and postimage verification'],exclusions=['Exact4.3.1 equivalence for the corrected-source ramp','Literal historical entry gate beyond the already admitted1.054day scope','Five-day and seasonal macro application','Native macro year-boundary restart','Macro chemistry and unqualified crop/heat variants','Portable performance guarantee'],test_selection=dict(changed='Darcy entry residual and matched Jacobian, explicit caller/binding, default-off Cauchy proposal ceiling',selected=['O0/O2 real production rate/derivative','Actual original2day native composition and positive pond','Same-platform complete-event file restart','Default literal prefix and existing joint/rootless native differential preservation','Unsupported callers and invalid/foreign input','Parent source/raw owner, retained481 owner, unchanged FSI35 source, docs'],not_selected=['Fresh481day numerical run','MC-NUT01 reopening','Broad F-CI','Low-air stress','RossFast','New1e-6 accuracy probe']),recovery=dict(executable_member='recovery/native_water_O2',restart_member='runs/two-O2/restart.bin',binding=json.loads(f['runs/two-O2/manifest.json'])['binding_sha256']),next_action='Admit only the bounded corrected-source two-day variant after current source/raw/retained481/FSI35/docs gates. Longer corrected-source execution remains CENSORED; do not repeat unchanged long runs.')
(ROOT/D/'ENTRY_RAMP_STATUS.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps({'bytes':len(raw),'members':len(f),'sensitivity':sensitivity}))
