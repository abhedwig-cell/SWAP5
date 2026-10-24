"""Seal current and retained failed observations for this existing HIST work unit."""
import base64,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;sha=lambda b:hashlib.sha256(b).hexdigest();f={};excluded={}
def add(name,p):
 b=p.read_bytes()
 if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):
  excluded[name]={'bytes':len(b),'sha256':sha(b)};return
 f[name]=b
for opt in ['O0','O2']:
 for label,folder in [('macro-'+opt,'macro-trace-qualified-'+opt),('bbc-'+opt,'macro-trace-bbc-'+opt),('build-'+opt,'macro-trace-final-build-'+opt),('initial-build-'+opt,'macro-trace-'+opt)]:
  p=W/folder
  for q in sorted(p.rglob('*')):
   if q.is_file():add(label+'/'+str(q.relative_to(p)),q)
for label,folder in [('nut-joint','macro-trace-nut-joint'),('nut-nonjuvenile','macro-trace-nut-nonjuvenile')]:
 p=W/folder
 for q in sorted(p.rglob('*')):
  if q.is_file():add(label+'/'+str(q.relative_to(p)),q)
 old=Path('/workspace/scratch/25ee4c13acd4/runs')/('corner-'+label)/'result.json';f['prior/'+label+'.json']=old.read_bytes()
for folder in ['macro-trace-pilot-O0','macro-trace-pilot2-O0','macro-trace-pilot3-O0','macro-trace-full-O0','macro-trace-full-O2','macro-trace-final-O0','macro-trace-final-O2','macro-trace-v4full-O0','macro-trace-v4full-O2']:
 p=W/folder
 if p.exists():
  for q in sorted(p.rglob('*')):
   if q.is_file():add('earlier-rounds/'+folder+'/'+str(q.relative_to(p)),q)
f['parent/proof.json']=(W/'macro-parent-proof.json').read_bytes();base='2d21939f285615818ba94352187d40abe2466d8e'
f['parent/commit.raw']=subprocess.check_output(['git','cat-file','commit',base],cwd=ROOT)
f['parent/owner.py']=subprocess.check_output(['git','show',base+':integration/audits/verify_picard_corner_current.py'],cwd=ROOT)
inputs={}
for name,b in list(f.items()):
 if name in ['macro-O0/RESULT.json','macro-O2/RESULT.json','nut-joint/result.json','nut-nonjuvenile/result.json','bbc-O0/RESULT.json','bbc-O2/RESULT.json']:
  for p,h in json.loads(b)['input_sha256'].items():
   raw=(ROOT/p).read_bytes();assert sha(raw)==h,('seal stale input',p);inputs[p]=h;f['executed-sources/'+p]=raw
f['EXCLUDED.json']=json.dumps(excluded,indent=2).encode();f['INPUTS.json']=json.dumps(inputs,indent=2).encode()
compiler=W/'compiler/usr/bin/x86_64-linux-gnu-gfortran-13';f['TOOLCHAIN.json']=json.dumps({'compiler_sha256':sha(compiler.read_bytes()),'version':subprocess.check_output([str(W/'compiler/bin/gfortran'),'--version'],text=True).splitlines()[0],'OMP_NUM_THREADS':os.environ.get('OMP_NUM_THREADS','UNSET'),'numerical_scope':'No speed claim; checked original flags and every process/return retained'},indent=2).encode()
f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in sorted(f.items())},sort_keys=True).encode();buf=io.BytesIO()
with tarfile.open(fileobj=buf,mode='w:xz')as t:
 for name,b in sorted(f.items()):
  i=tarfile.TarInfo(name);i.size=len(b);i.mtime=0;t.addfile(i,io.BytesIO(b))
raw=buf.getvalue();path='integration/mc-sol01/drainage/MACRO_TRACE_EVIDENCE.tar.xz.b64';(ROOT/path).write_bytes(base64.b64encode(raw));r=json.loads((ROOT/'integration/mc-sol01/drainage/MACRO_TRACE_STATUS.json').read_text());r.update(stage='CURRENT_NATIVE_AND_RETained_QUALIFICATION_SEALED',qualified=True,canonically_admitted=False,evidence={'path':path,'sha256':sha(raw),'bytes':len(raw),'members':len(f)},source_bound_executed_inputs=len(inputs),next_action='Validate current source/raw controls and strict docs, safely publish/merge and verify actual canonical tree; full native Andelst remains excluded')
science=['src','app','tools','tests','examples','reference','.github','integration/audits'];delta={x.split('\t')[1]:x.split('\t')[0]for x in subprocess.check_output(['git','diff','--name-status',base,'--',*science],cwd=ROOT,text=True).splitlines()}
# Include this unit's new guard and new test helper before the candidate commit.
for p in ['integration/audits/verify_macro_trace_current.py']:delta[p]='A'
r['scientific_delta']=delta;r['postimages']={p:sha((ROOT/p).read_bytes())for p in delta}
for p in ['integration/mc-sol01/drainage/qualify_macro_trace.py','integration/mc-sol01/drainage/preserve_macro_trace_bbc.py','integration/mc-sol01/drainage/seal_macro_trace.py','integration/mc-sol01/drainage/MACRO_TRACE_CONTRACT.md']:r['postimages'][p]=sha((ROOT/p).read_bytes())
(ROOT/'integration/mc-sol01/drainage/MACRO_TRACE_STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'evidence_bytes':len(raw),'members':len(f),'executed_inputs':len(inputs),'scientific_delta':delta}))
