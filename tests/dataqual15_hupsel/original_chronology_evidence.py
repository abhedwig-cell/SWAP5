"""Sealed original chronology and cold typed MICRO/oxygen replays; no scientific promotion."""
import argparse,base64,gzip,hashlib,io,json,os,subprocess,tarfile,tempfile,sys
from pathlib import Path
import original_chronology_audit as audit
import original_micro_comparison as micro
import original_oxygen_reference_gate as reference_gate
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='ORIGINAL_CHRONOLOGY_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))

def execution_controls(files):
 sys.path.insert(0,str(ROOT/'tests/dataqual15'))
 from original_sources import select_dec_branches
 provider=json.loads(files['provider/BUILD.json'])
 selected_hashes={n.replace('\\','/'):h for n,h in provider['selected_sha256'].items()}
 assert len(selected_hashes)==len(provider['selected_sha256'])
 authority=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes()))) as t:
  for name in ('swap.f90','swapoutput.f90','RWU_micro.f90','MOD_MvG_functions.f90'):
   matches=[n for n in t.getnames() if n=='SWAP/'+name];assert len(matches)==1
   raw=t.extractfile(matches[0]).read()
   selected=select_dec_branches(raw.decode('cp1252')).encode('cp1252')
   assert selected==files['provider-selected/'+name]
   assert sha(selected)==selected_hashes['selected/'+name]
 for mode in ('observed','unobserved'):
  r=json.loads(files['original/'+mode+'/RUN.json']);assert sha(files['original/'+mode+'.exe'])==r['executable_sha256']
  assert all(sha(files['original/'+mode+'/'+n])==h for n,h in r['inputs'].items())
 for label in ('reference-eps1e8','reference-eps1e10','reference-continuous-k','reference-implicit-k'):
  events=json.loads(files[label+'/EVENTS.json']);complete=json.loads(files[label+'/COMPLETE.json'])
  assert len(events)==3 and [e['returncode'] for e in events]==[0,0,100]
  assert sha(files[label+'/reference.exe'])==complete['executable_sha256']
  assert len(audit.csv_rows(files[label+'/case/result_output.csv']))==1097
 for label in ('reference-strict-balance','reference-implicit-balanced','reference-refinement'):
  r=json.loads(files[label+'/RESULT.json']);assert r['returncode']==100 and r['swap_ok']
 failed=json.loads(files['reference-implicit-unimplemented/RESULT.json'])
 assert failed['returncode']==0 and not failed['swap_ok']
 assert b'not yet implemented' in files['reference-implicit-unimplemented/case/swap.err']
 # Pin the entire actual native compiled closure, including copied treatment
 # sources; do not infer a physical effect merely from a changed executable.
 prefix='native-frozen-k/'
 build=json.loads(files[prefix+'build-O2/BUILD.json'])
 assert build['interventions']==['src/process/mod_root_micro_de_willigen_process.f90','src/runtime/mod_fmr_serialized_reference_backend.f90']
 assert build['complete_module_closure_rebuilt'] and len(build['compiled_objects_sha256'])==236
 for n,h in build['compiled_objects_sha256'].items():assert sha(files[prefix+'build-O2/'+n])==h
 for i,(_,h) in enumerate(build['source_sha256'].items()):assert sha(files[prefix+'compiled-source/'+str(i)+'.f90'])==h
 r=json.loads(files[prefix+'prefix-O2/RESULT.json'])
 assert r['returncode']==0 and r['from_start'] and r['restart_sha256'] is None
 assert r['executable_sha256']==sha(files[prefix+'build-O2/frozen-k.exe'])==build['executable_sha256']
 native=audit.csv_rows(files[prefix+'prefix-O2/budget.csv']);assert len(native)==585 and float(native[-1]['t1_day'])==584
 parent=json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text());path=BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.tar.xz'
 assert sha(path.read_bytes())==parent['archive_sha256']
 name='full-O2/budget.csv'
 with tarfile.open(path) as t:
  raw=t.extractfile(name).read();parent_build=json.loads(t.extractfile('build-O2/BUILD.json').read())
 assert build['baseline']==parent_build['baseline']
 from micro_pressure_probe import PROCESS,OLD,NEW
 backend='src/runtime/mod_fmr_serialized_reference_backend.f90'
 old='    request%numerical%consistent_provider_conductivity=self%weather_surface_active\n'
 new='    request%numerical%consistent_provider_conductivity=.false. ! isolated frozen-K control\n'
 expected={PROCESS:(ROOT/PROCESS).read_text().replace(OLD,NEW),backend:(ROOT/backend).read_text().replace(old,new)}
 base=list(build['baseline']['source_sha256'].items())
 for i,(name,h) in enumerate(base):
  matches=[n for n in expected if name.replace('\\','/').endswith('/'+n)]
  source=files[prefix+'compiled-source/'+str(i)+'.f90']
  if matches:assert source.decode().replace('\r\n','\n')==expected[matches[0]]
  else:assert sha(source)==h
 assert sha(raw)==parent['files_sha256']['full-O2/budget.csv']
 baseline=[r for r in audit.csv_rows(raw) if float(r['t1_day'])<=584]
 assert native==baseline
 return dict(original_source_authority_exact=True,native_compiled_objects=236,native_control_budget_prefix_exact=True,
  native_control_interpretation='No observable treatment response; not proof that conductivity policy causes the native discrepancy.',
  original_unimplemented_implicit_failure_retained=True)

def native_trace():
 record=json.loads((BASE/'PRESSURE_OXYGEN_EVIDENCE_20261104.json').read_text())
 chunks=[]
 for i,p in enumerate(record['archive_parts']):
  assert p['name']=='PRESSURE_OXYGEN_EVIDENCE_20261104.tar.xz.part'+str(i).zfill(2)
  raw=(BASE/p['name']).read_bytes();assert len(raw)==p['bytes'] and sha(raw)==p['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert sha(raw)==record['archive_sha256']
 name='O2/whole/root_accepted.dat'
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:trace=t.extractfile(name).read()
 assert sha(trace)==record['files_sha256'][name]
 return trace

def factor_replay(files,order,opt,out,fc):
 out.mkdir();carrier=json.loads((ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text())
 literal=gzip.decompress(base64.b64decode(carrier['gzip_base64']));assert sha(literal)==carrier['sha256']
 source=out/'oxygenstress.f90';source.write_bytes(literal)
 assert all(not Path(n).is_absolute() and '..' not in Path(n).parts and (ROOT/n).is_file() for n in order)
 inputs=[ROOT/'tests/dataqual15_hupsel/matched_oxygen_owners.f90',source,*[ROOT/n for n in order],ROOT/'tests/dataqual15_hupsel/original_factor_comparison.f90']
 exe=out/'compare.exe';cmd=[str(fc),'-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out),*map(str,inputs),'-o',str(exe)]
 p=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180);(out/'compile.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 frame=out/'original_factor_inputs.dat';frame.write_bytes(files['micro/case/original_factor_inputs.dat'])
 p=subprocess.run([str(exe),str(frame)],cwd=out,capture_output=True,timeout=300)
 (out/'comparison.stdout').write_bytes(p.stdout);(out/'comparison.stderr').write_bytes(p.stderr);assert p.returncode==0,p.stderr
 rows=audit.numbers(p.stdout,9);assert len({int(r[0]) for r in rows})==3206
 binding=max(abs(r[4]-r[6]) for r in rows);difference=max(abs(r[5]-r[6]) for r in rows)
 assert binding<1e-9 and difference>1e-4 # Retain the failed assembled factor gate.
 result=dict(actual_profiles=3206,rooted_node_rows=len(rows),original_source_vs_actual_stored=binding,
  typed_vs_actual_original_maximum=difference,inside_unchanged_assembled_factor_bound=False,production_admission=False)
 (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');return result

def unpack(record):
 chunks=[]
 for i,p in enumerate(record['archive_parts']):
  assert p['name']==STEM+'.tar.xz.part'+str(i).zfill(2)
  raw=(BASE/p['name']).read_bytes();assert len(raw)==p['bytes'] and sha(raw)==p['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert sha(raw)==record['archive_sha256']
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  names=t.getnames();assert len(names)==len(set(names)) and set(names)==set(record['files_sha256'])
  files={n:t.extractfile(n).read() for n in names}
 assert all(sha(raw)==record['files_sha256'][n] for n,raw in files.items())
 return files

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path)
 p.add_argument('--replay-output',type=Path)
 p.add_argument('--compiler',default=os.environ.get('FC','gfortran'));a=p.parse_args()
 if a.capture:
  capture=a.capture.resolve();files={x.relative_to(capture).as_posix():x.read_bytes() for x in capture.rglob('*') if x.is_file()}
  collected=json.loads(files['COLLECTED.json']);assert collected['complete'] and collected['collection_sha256']==sha(files['COLLECTION.json'])
  config=json.loads(files['COLLECTION.json']);order=config['factor_repository_order']
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert not record['production_admission'] and not record['whole_scientific_admission']
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  files=unpack(record);order=record['factor_repository_order']
 trace=native_trace();result=audit.audit(files,trace);result['refusal_controls']=audit.refusal_controls(files,trace)
 result['execution_controls']=execution_controls(files)
 bound=result['unchanged_oxygen_bound_cm']
 coarse=files['reference-archive/dtmax-0.000625/result_output.csv']
 fine=files['reference-archive/dtmax-0.0003125/result_output.csv']
 refined=files['reference-refinement/case/result_output.csv']
 # Bind both older levels to the already sealed scientific source archive.
 parent=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text())
 for cap,raw in [('.000625',coarse),('.0003125',fine)]:
  name='original/dtmax-0'+cap+'/result_output.csv'
  assert sha(raw)==parent['members'][name]
 result['reference_gate']=reference_gate.assess(coarse,fine,refined,bound,result['native_oxygen_cm'])
 result['reference_refusal_controls']=reference_gate.refusal_controls(coarse,fine,refined,bound,result['native_oxygen_cm'])
 assert not result['reference_gate']['scientific_admission_permitted']
 refinement=json.loads(files['reference-refinement/PREREGISTRATION.json'])
 assert refinement['unmodified_original_executable_sha256']==sha(files['original/unobserved.exe'])
 assert json.loads(files['reference-refinement/RESULT.json'])['swap_ok']
 # A strict source/body identity check supplements the observed equality of
 # every physical output; metadata receipts alone are not sufficient.
 import original_oxygen_chronology as chronology
 import original_micro_forcing as micro_capture
 # Match Path.read_text's universal-newline treatment in the actual generator;
 # the unmodified source bytes remain independently SHA pinned in BUILD.
 source=chronology.instrument(files['provider-selected/swap.f90'].decode().replace('\r\n','\n'))
 assert source==files['original/swap.f90'].decode()
 owner=micro_capture.owner
 modified=source.replace(chronology.USE,chronology.USE+owner.USE).replace(chronology.DECL,chronology.DECL+owner.DECL)
 modified=modified.replace('      call integral(3)\n','      call integral(3)\n'+owner.BLOCK)
 assert modified==files['micro/swap.f90'].decode()
 # Binaries remain sealed with execution receipts. Cold compilation checks the
 # current typed owners against the actual original carriers independently.
 for prefix in ('original','micro'):
  complete=json.loads(files[prefix+'/COMPLETE.json'])
  if prefix=='original':assert sha(files[prefix+'/observed.exe'])==complete['observed_executable_sha256']
  else:assert sha(files[prefix+'/observed.exe'])==complete['executable_sha256']
 with tempfile.TemporaryDirectory(prefix='swap5-original-chronology-') as tmp:
  root=a.replay_output.resolve() if a.replay_output else (capture if a.capture else Path(tmp))
  if a.replay_output:root.mkdir()
  if not a.capture or a.replay_output:
   for n in ('COMPLETE.json','case/original_micro_inputs.dat','case/original_micro_tables.dat'):
    f=root/'micro'/n;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(files['micro/'+n])
  replay=root/'cold-micro';micro.run(root/'micro',replay,Path(a.compiler).resolve() if Path(a.compiler).exists() else a.compiler)
  result['micro']={}
  for opt in ('O0','O2'):
   r=json.loads((replay/opt/'RESULT.json').read_text());assert r['actual_accepted_steps']==3206 and r['maximum_node_sink_error']<=2e-5
   result['micro'][opt]={k:r[k] for k in ('actual_accepted_steps','maximum_node_sink_error','maximum_total_sink_error','integrated_total_sink_delta_cm')}
  result['factors']={opt:factor_replay(files,order,opt,root/('cold-factor-'+opt),a.compiler) for opt in ('O0','O2')}
 if a.capture:(capture/'AUDIT.json').write_text(json.dumps(result,indent=2)+'\n')
 else:
  prior=json.loads(files['AUDIT.json']);assert result['original_oxygen_cm']==prior['original_oxygen_cm'] and result['native_oxygen_cm']==prior['native_oxygen_cm']
  assert not result['inside_unchanged_scientific_bound'] and not result['production_admission']
 print(json.dumps(result,indent=2))

if __name__=='__main__':main()
