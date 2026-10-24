"""Retain all failed rounds and the final bounded real-owner execution."""
import base64,hashlib,io,json,re,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;W=ROOT.parent
sha=lambda b:hashlib.sha256(b).hexdigest()
files={};excluded={}
for p in sorted(W.glob('andelst-macro-bbc*')):
 if not p.is_dir():continue
 for f in sorted(p.rglob('*')):
  if not f.is_file()or f.is_symlink():continue
  b=f.read_bytes();key=p.name+'/'+str(f.relative_to(p))
  if f.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):excluded[key]=dict(bytes=len(b),sha256=sha(b));continue
  files[key]=b
for p in sorted(W.glob('macro-scalar-*')):
 if p.is_file():files[p.name]=p.read_bytes();continue
 for q in p.rglob('*'):
  if q.is_file():
   b=q.read_bytes()
   if not b.startswith(b'\x7fELF'):files[p.name+'/'+str(q.relative_to(p))]=b
for opt in ['O0','O2']:files['build-'+opt+'.json']=(W/('fresh-build-'+opt)/'column/build-complete.json').read_bytes()
results={};masses=[];cross=[]
for opt in ['O0','O2']:
 prefix='andelst-macro-bbc6-'+opt+'/';r=json.loads(files[prefix+'RESULT.json'])
 assert r['status']=='PROBE_COMPLETE' and r['candidate_physical_pass'] and r['incumbent_three_owner_output_exact']
 assert r['bbc_sha256']=='ed83fe31870676cef7a57a27ce2372abc53cc0755b0f4ea6b0b6248e152480ff'
 for name,path in [('candidate_backend.f90','src/runtime/mod_fmr_serialized_reference_backend.f90'),('candidate_binding.f90','src/adapter/mod_reference_richards_legacy_binding.f90')]:assert files[prefix+name]==(ROOT/path).read_bytes()
 for driver in ['trial','replay']:
  assert files[prefix+driver+'-incumbent-canonical.stdout']==files[prefix+driver+'-incumbent-candidate.stdout']
  assert r['results'][driver+'-canonical-mode2']!=0
  for mode in [1,2,3]:
   key=driver+'-candidate-mode'+str(mode);assert r['results'][key]==0
   raw=files[prefix+key+'.stdout'];assert b'RUTTER_BOESTEN_MACROPORE' in raw
   if driver=='replay':
    assert b'RUTTER_BOESTEN_MACROPORE_RESTART=PASS' in raw and b'RUTTER_UNSUPPORTED_ENVELOPE_10_REJECT=PASS' in raw
   vals=[abs(float(v))for v in re.findall(rb'\|MASS=([^|\r\n]+)',raw)];assert vals and max(vals)<1e-9;masses+=vals
   if opt=='O2':cross.append(raw==files['andelst-macro-bbc6-O0/'+key+'.stdout'])
 results[opt]=r['results']
scalar=json.loads(files['macro-scalar-preservation.json']);assert len(scalar)==8 and all(e['returncode']==0 for e in scalar)
summary=dict(scalar_contracts_O0_O2_canonical_stdout_exact=True,status='BOUNDED_ORIGINAL_BBC_THREE_OWNER_PHYSICAL_PASS',results=results,physical_candidate_sources_exact=True,
 O0_O2_six_stdout_byte_exact=all(cross),max_observed_water_residual_cm=max(masses),canonical_original_BBC_preflight_rejection_preserved=True,
 incumbent_three_owner_stdout_exact=True,original_assertion_bodies_retained=True,heat_drainage_negative_controls_retained=True,
 qualified=False,canonically_admitted=False,full_original_Andelst=False,
 blocker='Native bootstrap and combined thermal/drainage state/execution contracts remain absent; this is only original BBC plus constructed four-cell MIGMAC10 composition')
files['SUMMARY.json']=json.dumps(summary,indent=2).encode();files['EXCLUDED.json']=json.dumps(excluded,sort_keys=True).encode()
files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode();stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;m.mode=0o644;t.addfile(m,io.BytesIO(b))
b=stream.getvalue();path=HERE/'ANDELST_COMPOSITION_EVIDENCE.tar.xz.b64';path.write_bytes(base64.b64encode(b))
index=dict(path=str(path.relative_to(ROOT)),sha256=sha(b),bytes=len(b),members=len(files))
(HERE/'ANDELST_COMPOSITION_RESULT.json').write_text(json.dumps(dict(**summary,evidence=index),indent=2)+'\n')
p=HERE/'ANDELST_COMPOSITION_STATUS.json';r=json.loads(p.read_text());r.update(tested=True,qualified=False,results='integration/mc-sol01/drainage/ANDELST_COMPOSITION_RESULT.json',next_action='Current owning source/provenance succession, independent Robin/matrix-area oracle, heat/drainage combined layout and native bootstrap before canonical admission',blockers=[summary['blocker']],production_candidate_sha256={path:sha((ROOT/path).read_bytes())for path in ['src/runtime/mod_fmr_serialized_reference_backend.f90','src/adapter/mod_reference_richards_legacy_binding.f90']});p.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(summary,indent=2))
