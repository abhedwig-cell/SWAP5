"""Matched actual carrier selection and literal-original pointwise comparison."""
import argparse,collections,copy,hashlib,json,subprocess,sys,tarfile,tempfile,io
from pathlib import Path
from full_profile_evidence import unpack
from solute_route_evidence import dat,select,read_csv
from solute_route_observer import ROUTE,MAIN
from matched_solute_observer import instrument,literal,GENERATOR,INVERSE
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='MATCHED_SOLUTE_EVIDENCE_20261104'
ORIGIN='0fdfc407a2ed62660e1272106d6b28eb34a97ba8'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))

def choose(raw,accepted):
 candidates=collections.defaultdict(set)
 for r in raw:assert len(r)==13;candidates[r[:6]].add(r)
 chosen=[]
 for a in accepted:
  options=candidates[a[:6]];assert len(options)==1,'missing or ambiguous matched original receipt'
  r=next(iter(options));assert r[11]==1 and r[12]==0,'qualified actual source regime'
  assert all(0<=v<1e-12 for v in r[6:11]),'existing literal dynamic-heat concentration/inventory bound'
  chosen.append(r)
 return chosen

def audit(files,original_oracle):
 reports={}
 for opt in ('O0','O2'):
  b=json.loads(files[opt+'/build/BUILD.json']);assert b['original_solute_source_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
  assert sha(files[opt+'/build/observed.exe'])==b['executable_sha256']
  assert '-'+opt in b['baseline_build']['flags']
  assert files[opt+'/build/b111_literal_oracle.f90'].decode().replace('\r\n','\n')==original_oracle
  assert sha(files[opt+'/build/b111_literal_oracle.f90'])==b['literal_source_sha256']
  inverse=files[opt+'/build/matrix_nonlinear_oracle.f90'];assert sha(inverse)==b['inverse_source_sha256']
  assert sha(inverse.replace(b'\r\n',b'\n'))==norm(INVERSE)
  generator=files[opt+'/build/literal-generator.py'];assert sha(generator)==b['generator_sha256'] and sha(generator.replace(b'\r\n',b'\n'))==norm(GENERATOR)
  expected=instrument((ROOT/ROUTE).read_text(),(ROOT/MAIN).read_text())
  assert b['source_patches'].keys()=={ROUTE,MAIN}
  for n,text in zip((ROUTE,MAIN),expected):
   patch=b['source_patches'][n];raw=files[opt+'/build/'+patch['postimage']]
   assert sha(raw)==patch['after'] and raw.decode().replace('\r\n','\n')==text
   origin=[h for p,h in b['baseline_build']['source_sha256'].items() if p.replace('\\','/').endswith('/'+n)]
   assert origin==[patch['before']]
  own_objects=[n for n in files if n.startswith(opt+'/build/') and n.endswith('.o')];assert len(own_objects)==4
  for n in own_objects:
   pins=[h for p,h in b['object_sha256'].items() if p.replace('\\','/').endswith('/'+n)]
   assert pins==[sha(files[n])]
  link=json.loads(files[opt+'/build/LINK.json']);assert sha(files[opt+'/build/link.args'])==link['response_sha256']
  response='\n'.join('"'+str(x).replace('\\','/')+'"' for x in link['arguments']).encode()
  assert files[opt+'/build/link.args']==response
  assert link['arguments']==['-fopenmp','-Wl,--stack,16777216',*b['object_sha256'],b['baseline_build']['publication_provider']['object'],b['baseline_build']['ttutil_archive'],'-o',str(Path(link['arguments'][-1]))]
  w=opt+'/whole/';tail=opt+'/strict-own-1088/'
  accepted=dat(files[w+'solute_accepted.dat'],9);raw=dat(files[w+'solute_trials.dat'],28)
  selected,_=select(raw,accepted,1077,1096,read_csv(files[w+'budget.csv']))
  matched=dat(files[w+'solute_matched.dat'],13);chosen=choose(matched,accepted)
  resumed=choose(dat(files[tail+'solute_matched.dat'],13),dat(files[tail+'solute_accepted.dat'],9))
  assert resumed==[r for r in chosen if r[0]>=1088]
  assert files[w+'checkpoint.bin']==files[tail+'checkpoint.bin']
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   assert [r for r in read_csv(files[w+name]) if float(r[clock])>1088]==read_csv(files[tail+name])
  controls=[]
  for label in ('missing','shifted','ambiguous','concentration','node_inventory','signed_flux','source_regime'):
   r,a=copy.deepcopy((matched,accepted));key=a[0][:6]
   if label=='missing':r=[x for x in r if x[:6]!=key]
   elif label=='shifted':v=list(a[0]);v[0]+=1e-6;a[0]=tuple(v)
   else:
    i=next(i for i,x in enumerate(r) if x[:6]==key);v=list(r[i])
    v[{'ambiguous':6,'concentration':6,'node_inventory':7,'signed_flux':10,'source_regime':11}[label]]+=1e-6
    if label=='ambiguous':r.append(tuple(v))
    else:r=[tuple(v) if x[:6]==key else x for x in r]
   try:choose(r,a)
   except AssertionError:controls.append(dict(control=label,rejected=True))
   else:raise AssertionError('accepted matched defect '+label)
  maxima={name:max(r[i] for r in chosen) for name,i in [('concentration_mg_cm3',6),('node_total_mass_mg_cm2',7),('surface_mass_mg_cm2',8),('decay_mg_cm2',9),('signed_net_export_mg_cm2',10)]}
  reports[opt]=dict(selected_substeps=len(chosen),nodes_per_step=34,node_process_comparisons=34*len(chosen),
                    raw_matched_trials=len(matched),maxima=maxima,existing_literal_bound=1e-12,
                    negative_controls=controls,strict_own_matched_trace_exact=True,
                    exact_qualified_prior_route_trace=True,exact_unobserved_typed_and_daily_endpoints=True)
 return dict(status='ACTUAL_MATCHED_NATIVE_LITERAL_TRANSPORT_O0_O2_PASS',optimizations=reports,
             native_execution='Windows checked O0/O2 actual1077->1096; POSIX data remeasurement only',
             matched_process_agreement=True,whole_trajectory_equivalence_qualified=False,
             global_physical_mechanism_qualified=False,production_correction_qualified=False,whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/solute_route_evidence.py')],cwd=ROOT,check=True)
 subprocess.run(['git','merge-base','--is-ancestor',ORIGIN,'HEAD'],cwd=ROOT,check=True)
 origin=subprocess.check_output(['git','show',ORIGIN+':integration/dataqual15_hupsel/SOLUTE_ROUTE_EVIDENCE_20261104.json'],cwd=ROOT)
 assert sha(origin.replace(b'\r\n',b'\n'))==norm(BASE/'SOLUTE_ROUTE_EVIDENCE_20261104.json')
 prior=json.loads(origin);old=unpack(BASE/'SOLUTE_ROUTE_EVIDENCE_20261104.tar.xz',prior['files_sha256'])
 with tempfile.TemporaryDirectory(prefix='swap5-literal-generator-') as temp:original_oracle=literal(Path(temp))
 if a.capture:
  folder=a.capture.resolve();fresh={};reused={}
  for opt in ('O0','O2'):
   b=json.loads((folder/opt/'build/BUILD.json').read_text());assert b['baseline_build']==json.loads(old[opt+'/build/BUILD.json'])['baseline_build']
   assert all(sha(Path(p).read_bytes())==h for p,h in b['object_sha256'].items())
   for f in (folder/opt).rglob('*'):
    if not f.is_file() or not (f.suffix in ('.json','.dat','.bin','.csv','.f90','.exe','.o','.args','.nml','.swp','.crp','.met','.dra','.stdout','.stderr') or f.name in ('stdout','stderr')):continue
    n=opt+'/'+f.relative_to(folder/opt).as_posix();raw=f.read_bytes()
    if n in old and raw==old[n]:reused[n]=sha(raw)
    else:fresh[n]=raw
   fresh[opt+'/build/literal-generator.py']=GENERATOR.read_bytes()
  files={**{n:old[n] for n in reused},**fresh};result=audit(files,original_oracle)
  fresh['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode();archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz') as t:
   for n,b in sorted(fresh.items()):
    m=tarfile.TarInfo(n);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
  deps=dict(prior['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/matched_solute_observer.py','tests/dataqual15_hupsel/matched_solute_evidence.py',
            'tests/nut-sol/run_nonlinear_pond.py','tests/nut-sol/matrix_nonlinear_oracle.f90',
            '.github/workflows/hupsel-matched-solute.yml','integration/dataqual15_hupsel/MATCHED_SOLUTE_PREREGISTRATION_20261104.json',
            'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'):
   deps[n]=norm(ROOT/n)
  record=dict(status=result['status'],archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b) for n,b in fresh.items()},
              reused_qualified_files_sha256=reused,normalized_repository_dependency_sha256=deps,whole_scientific_admission=False)
  (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  archive=BASE/(STEM+'.tar.xz');assert sha(archive.read_bytes())==record['archive_sha256']
  fresh=unpack(archive,record['files_sha256']);assert not set(fresh)&set(record['reused_qualified_files_sha256'])
  assert all(n in old and sha(old[n])==h for n,h in record['reused_qualified_files_sha256'].items())
  files={**{n:old[n] for n in record['reused_qualified_files_sha256']},**fresh};result=audit(files,original_oracle)
  assert result==json.loads(files['AUDIT.json'])
 # Bind actual unchanged accepted trials/carriers, source inputs and state to
 # the already independently qualified observation. No asserted Boolean alone.
 for opt in ('O0','O2'):
  b=json.loads(files[opt+'/build/BUILD.json']);assert b['baseline_build']==json.loads(old[opt+'/build/BUILD.json'])['baseline_build']
  for phase in ('whole','strict-own-1088'):
   root=opt+'/'+phase+'/'
   for n in ('solute_trials.dat','solute_accepted.dat','checkpoint.bin','budget.csv','crop.csv'):
    assert files[root+n]==old[root+n],root+n
   run=json.loads(files[root+'RESULT.json']);assert run['returncode']==0 and run['executable_sha256']==b['executable_sha256']
   expected_seed=json.loads(old[root+'RESULT.json'])['restart_sha256'];assert run['restart_sha256']==expected_seed
   assert run['scope']==json.loads(old[root+'RESULT.json'])['scope']
   for n,h in run['inputs'].items():assert sha(files[root+n])==h and files[root+n]==old[root+n]
 print(result['status']);print(json.dumps({opt:r['maxima'] for opt,r in result['optimizations'].items()}))

if __name__=='__main__':main()
