"""Seal this work unit's actual native observations; no execution is inferred."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
SCRATCH=ROOT.parent;HERE=Path(__file__).resolve().parent
BASE='57e1b3f2635559df0db0350a96f0e06b2e3b9cc7'
sha=lambda b:hashlib.sha256(b).hexdigest()
f={}
def add(prefix,path):
 path=Path(path)
 if path.is_dir():
  for p in sorted(path.rglob('*')):
   if p.is_file()and not p.is_symlink()and p.suffix not in ['.o','.mod','.a','.pyc']:
    b=p.read_bytes()
    if not b.startswith(b'\x7fELF'):f[prefix+'/'+str(p.relative_to(path))]=b
 else:f[prefix]=path.read_bytes()
add('predecessor',SCRATCH/'drain-frozen-zero-predecessor')
add('retained/prior-demand-predecessor',SCRATCH/'drain-frozen-predecessor')
for opt,bundle in [('O0','drain-final-O0'),('O2','drain-event-O2')]:
 add('native-'+opt,SCRATCH/('drain-qualified469-'+opt))
 add('joint-plain-'+opt,SCRATCH/('drain-final-plain-'+opt))
 add('joint-boesten-'+opt,SCRATCH/('drain-event-joint-'+opt))
 add('preserved-'+opt,SCRATCH/('drain-preserve-boesten2-'+opt if opt=='O0'else'drain-preserve-boesten-'+opt))
 for name in ['state.csv','endpoint.csv','budget.csv','restart.bin']:add('prior481-'+opt+'/'+name,SCRATCH/('boesten-authority-native-'+opt)/'historical/full'/name)
 failed=SCRATCH/('drain-event-long2-O0'if opt=='O0'else'drain-event-long-O2')
 pending=list(failed.glob('full.pending-*'));assert len(pending)==1;add('failed470-'+opt,pending[0])
 wet=SCRATCH/('drain-wet-'+opt);add('wet-'+opt+'/result.json',wet/'result.json');add('wet-'+opt+'/prefix',wet/'prefix')
 pending=[p for p in wet.glob('wet.pending-*')if not p.is_symlink()];assert len(pending)==1;add('wet-'+opt+'/rejected',pending[0])
 add('research-'+opt,SCRATCH/('drain-fct-preserved-'+opt))
 b=SCRATCH/bundle
 for name in ['bundle.json','events.json']:add('build-'+opt+'/'+name,b/name)
 for name in ['column','read_project','read_crop','read_root']:add('build-'+opt+'/'+name,b/name)
 for name in ['drain-native-'+opt+'/shared','drain-event-'+opt+'-physical']:
  folder=SCRATCH/name
  add('build-'+opt+'/'+folder.name+'/build-complete.json',folder/'build-complete.json')
  for p in folder.glob('*.stdout'):add('build-'+opt+'/'+folder.name+'/'+p.name,p)
  for p in folder.glob('*.stderr'):add('build-'+opt+'/'+folder.name+'/'+p.name,p)
add('nut/hist',SCRATCH/'drain-zero-current-hist');add('nut/joint',SCRATCH/'drain-zero-current-joint')
add('nut/prior-hist-result.json',Path('/workspace/scratch/281436eb488f/nut-zero-hist-02/result.json'))
add('nut/prior-joint-result.json',Path('/workspace/scratch/281436eb488f/nut-zero-joint-01/result.json'))
add('retained/prior-demand-current-hist',SCRATCH/'drain-nut-final2-hist');add('retained/prior-demand-current-joint',SCRATCH/'drain-nut-final-joint')
add('input-controls',SCRATCH/'drain-input-controls');add('cpu',SCRATCH/'drain-cpu')
add('headtol-diagnostic',SCRATCH/'drain-day470-headtol')
for name in ['drain-short-O2','drain-short2-O2','drain-short3-O2','drain-long-O2','drain-exchange-long-O2','drain-day271-debug','drain-day271-debug2','drain-joint-O2','drain-joint2-O2']:
 add('retained/'+name,SCRATCH/name)
for ref,label in [('19f45cbe9','initial'),('d6ed15435','profile'),('7528ad394','exchange'),('da035fe41','event-diagnostic')]:
 f['retained/source-'+label+'.f90']=subprocess.check_output(['git','show',ref+':src/runtime/mod_fmr_serialized_reference_backend.f90'],cwd=ROOT)
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta={line.split('\t')[1]:line.split('\t')[0]for line in subprocess.check_output(['git','diff','--name-status',BASE,'--',*science],cwd=ROOT,text=True).splitlines()}
tracked=['integration/audits/verify_native_drainage.py','integration/mc-sol01/drainage/seal.py',*delta]
tracked+=['src/process/mod_drainage_dramet3_response.f90','src/process/mod_drainage_spatial_distribution.f90','src/solver/mod_b111_profile_groundwater_projection.f90','src/process/mod_restricted_surface_evaporation.f90','src/adapter/mod_matrix_joint_restart_file.f90','src/runtime/mod_fmr_b111_pond_solute_route.f90','src/process/mod_b111_soil_n_daily_exchange.f90','integration/mc-nut01/demand_candidate/STATUS.json','integration/mc-sol01/fct_accepted_trace/EVIDENCE.tar.xz.b64']
tracked+=['src/process/mod_b111_soil_organic_turnover.f90','src/process/mod_b111_soil_organic_dissimilation.f90','integration/mc-nut01/zero_pool_rates/STATUS.json']
r=json.loads((HERE/'STATUS.json').read_text());r.update(scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(set(tracked))})
for path in sorted(set(tracked)):
 # Existing immutable reference capsules remain repository dependencies;
 # retain their hashes, rather than nesting their compressed bytes again.
 if not path.endswith('.b64'):f['current-source/'+path]=(ROOT/path).read_bytes()
f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz')as t:
 for p,b in sorted(f.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(b))
raw=out.getvalue();(HERE/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r['evidence']=dict(path='integration/mc-sol01/drainage/EVIDENCE.tar.xz.b64',sha256=sha(raw),bytes=len(raw),members=len(f))
(HERE/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
