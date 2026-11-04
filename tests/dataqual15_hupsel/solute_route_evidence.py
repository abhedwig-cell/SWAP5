"""Exact accepted-carrier selection and independent solute route quadrature."""
import argparse,collections,copy,csv,hashlib,io,json,math,subprocess,sys,tarfile
from pathlib import Path
from full_profile_evidence import unpack
from solute_route_observer import instrument,ROUTE,MAIN
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='SOLUTE_ROUTE_EVIDENCE_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
read_csv=lambda raw:list(csv.DictReader(io.StringIO(raw.decode())))

def dat(raw,n):
 rows=[tuple(map(float,line.split())) for line in raw.decode().splitlines()]
 assert rows and all(len(r)==n and all(math.isfinite(v) for v in r) for r in rows)
 return rows

def select(raw,accepted,start,end,budget):
 trials=collections.defaultdict(set)
 for row in raw:assert len(row)==28;trials[row[:6]].add(row)
 selected=[]
 assert accepted[0][0]==start and accepted[-1][1]==end
 for i,a in enumerate(accepted):
  assert len(a)==9 and a[8]==1 and a[1]>a[0]
  if i:assert accepted[i-1][1]==a[0],'accepted clock gap or replay'
  choices=trials[a[:6]];assert len(choices)==1,'missing or ambiguous exact accepted chemical carrier'
  r=next(iter(choices));assert r[20]==0,'quadrature is Reference transport only'
  assert r[13]==a[1]-a[0] and a[6]==r[6]
  assert abs(math.fsum(r[6:11])-a[5])<=1e-10,'component identity'
  assert abs(a[3]-a[2]-a[4]+a[5])<=1e-10
  assert abs(r[8]-r[17])<=1e-10 and abs(r[9]-r[18])<=1e-10 and abs(r[7]-r[19])<=1e-10,'q*C*dt identity'
  selected.append(r)
 byday=collections.defaultdict(list)
 for r in selected:byday[int(math.ceil(r[1]-1e-9))].append(r)
 assert sorted(byday)==list(range(start+1,end+1))
 assert [float(r['t1_day']) for r in budget]==list(range(start+1,end+1))
 daily=[]
 for day,b in zip(sorted(byday),budget):
  parts=byday[day];assert parts[0][0]==day-1 and parts[-1][1]==day
  incoming=math.fsum(r[4] for r in parts);outgoing=math.fsum(r[5] for r in parts)
  assert abs(incoming-float(b['solute_in_mg_cm2']))<=1e-10
  assert abs(outgoing-float(b['solute_out_mg_cm2']))<=1e-10
  assert abs(parts[0][2]-float(b['solute_start_mg_cm2']))<=1e-10 and abs(parts[-1][3]-float(b['solute_end_mg_cm2']))<=1e-10
  components={name:math.fsum(r[i] for r in parts) for name,i in [('decay',6),('root',7),('lateral_drain',8),('bottom',9),('runoff',10)]}
  assert abs(math.fsum(components.values())-outgoing)<=1e-10
  daily.append(dict(day=day,accepted_substeps=len(parts),external_input=incoming,external_output=outgoing,
                    components=components,bottom_input=math.fsum(r[11] for r in parts),
                    lateral_input=math.fsum(r[12] for r in parts),
                    lateral_water_cm=math.fsum(r[14] for r in parts),bottom_water_out_cm=math.fsum(r[15] for r in parts),
                    reconstructed_lateral_export=math.fsum(r[17] for r in parts),
                    reconstructed_bottom_export=math.fsum(r[18] for r in parts),reconstructed_root_export=math.fsum(r[19] for r in parts)))
 return selected,daily

def audit(files):
 results={}
 for opt in ('O0','O2'):
  prefix=opt+'/';whole=prefix+'whole/';tail=prefix+'strict-own-1088/'
  meta=json.loads(files[prefix+'RESULT.json']);build=json.loads(files[prefix+'build/BUILD.json'])
  assert meta['strict_own_restart'] and meta['exact_unobserved_endpoint'] and meta['exact_daily_budget_crop']
  assert sha(files[prefix+'build/observed.exe'])==build['executable_sha256']
  object_files=[n for n in files if n.startswith(prefix+'build/') and n.endswith('.o')]
  assert len(object_files)==2
  for n in object_files:
   pins=[h for path,h in build['object_sha256'].items() if path.replace('\\','/').endswith('/'+n)]
   assert pins==[sha(files[n])],'actual observer object'
  assert build['source_patches'].keys()=={ROUTE,MAIN}
  expected=instrument((ROOT/ROUTE).read_text(),(ROOT/MAIN).read_text())
  for name,post in zip((ROUTE,MAIN),expected):
   patch=build['source_patches'][name];source=files[prefix+'build/'+patch['postimage']]
   assert sha(source)==patch['after'] and source.decode().replace('\r\n','\n')==post
   origins=[h for n,h in build['baseline_build']['source_sha256'].items() if n.replace('\\','/').endswith('/'+name)]
   assert origins==[patch['before']],'observer predecessor must be the immutable compiled provider'
  assert '-'+opt in build['baseline_build']['flags']
  for n,h in build['baseline_build']['source_sha256'].items():
   # Portable compiled-provider binding is checked by the immutable accepted
   # baseline capsule in main; Windows capture additionally checks live bytes.
   assert isinstance(h,str) and len(h)==64
  assert files[whole+'checkpoint.bin']==files[tail+'checkpoint.bin']
  full_budget=read_csv(files[whole+'budget.csv']);tail_budget=read_csv(files[tail+'budget.csv'])
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   assert [r for r in read_csv(files[whole+name]) if float(r[clock])>1088]==read_csv(files[tail+name])
  raw=dat(files[whole+'solute_trials.dat'],28);accepted=dat(files[whole+'solute_accepted.dat'],9)
  selected,daily=select(raw,accepted,1077,1096,full_budget)
  rselected,rdaily=select(dat(files[tail+'solute_trials.dat'],28),dat(files[tail+'solute_accepted.dat'],9),1088,1096,tail_budget)
  assert rselected==[r for r in selected if r[0]>=1088] and rdaily==[r for r in daily if r['day']>1088]
  controls=[]
  for name in ('missing_receipt','shifted_clock','ambiguous_receipt','route_component','quadrature','budget_export'):
   rr,aa,bb=copy.deepcopy((raw,accepted,full_budget));key=aa[0][:6]
   if name=='missing_receipt':rr=[r for r in rr if r[:6]!=key]
   elif name=='shifted_clock':a=list(aa[0]);a[0]+=1e-6;aa[0]=tuple(a)
   elif name=='budget_export':bb[0]['solute_out_mg_cm2']=str(float(bb[0]['solute_out_mg_cm2'])+1e-6)
   else:
    index=next(i for i,r in enumerate(rr) if r[:6]==key);r=list(rr[index]);r[8 if name!='quadrature' else 17]+=1e-6
    if name=='ambiguous_receipt':rr.append(tuple(r))
    else:rr=[tuple(r) if x[:6]==key else x for x in rr]
   try:select(rr,aa,1077,1096,bb)
   except AssertionError:controls.append(dict(control=name,rejected=True))
   else:raise AssertionError('observer accepted '+name)
  totals={name:math.fsum(d['components'][name] for d in daily) for name in daily[0]['components']}
  results[opt]=dict(raw_trial_receipts=len(raw),accepted_receipts=len(accepted),unselected_raw_receipts=len(raw)-len(accepted),
                   daily=daily,export_components=totals,negative_controls=controls,strict_own_selected_trace_exact=True,
                   exact_unobserved_typed_endpoint=True,exact_unobserved_budget_crop=True)
 return dict(status='ACTUAL_ACCEPTED_SOLUTE_ROUTE_AND_QUADRATURE_O0_O2_PASS',optimizations=results,
             native_execution='Windows checked O0/O2 actual1077->1096; cold POSIX data remeasurement only',
             physical_transport_mechanism_qualified=False,production_correction_qualified=False,whole_scientific_admission=False)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
 subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/solute_discrepancy_attribution.py')],cwd=ROOT,check=True)
 prior=json.loads((BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json').read_text())
 old=unpack(BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz',prior['files_sha256'])
 if a.capture:
  root=a.capture.resolve();files={}
  for opt in ('O0','O2'):
   folder=root/opt;build=json.loads((folder/'build/BUILD.json').read_text())
   inherited=json.loads(old[('build-O0' if opt=='O0' else 'build')+'/BUILD.json'])
   assert build['baseline_build']==inherited
   assert all(sha(Path(n).read_bytes())==h for n,h in build['object_sha256'].items())
   for path in folder.rglob('*'):
    if path.is_file() and (path.suffix in ('.json','.dat','.bin','.csv','.f90','.exe','.o','.stdout','.stderr','.nml','.swp','.crp','.met','.dra') or path.name in ('stdout','stderr')):
     files[opt+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
  result=audit(files);files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode()
  archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz') as t:
   for n,b in sorted(files.items()):
    m=tarfile.TarInfo(n);m.size=len(b);m.mtime=0;t.addfile(m,io.BytesIO(b))
  inherited=json.loads((BASE/'SOLUTE_ATTRIBUTION_20261104.json').read_text());deps=dict(inherited['normalized_repository_dependency_sha256'])
  for n in ('tests/dataqual15_hupsel/solute_route_observer.py','tests/dataqual15_hupsel/solute_route_evidence.py',
            '.github/workflows/hupsel-solute-route.yml','integration/dataqual15_hupsel/SOLUTE_ROUTE_PREREGISTRATION_20261104.json'):
   deps[n]=norm(ROOT/n)
  record=dict(status=result['status'],archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},
              normalized_repository_dependency_sha256=deps,whole_scientific_admission=False)
  (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert record['whole_scientific_admission'] is False
  for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
  archive=BASE/(STEM+'.tar.xz');assert sha(archive.read_bytes())==record['archive_sha256']
  files=unpack(archive,record['files_sha256']);result=audit(files);assert result==json.loads(files['AUDIT.json'])
 # Both portable and capture paths bind the actual unobserved reference data,
 # not just a Boolean asserted by the observer runner.
 for opt,prefix in [('O0','restart/O0-compatible-tail/'),('O2','case/')]:
  build=json.loads(files[opt+'/build/BUILD.json']);assert build['baseline_build']==json.loads(old[('build-O0' if opt=='O0' else 'build')+'/BUILD.json'])
  assert files[opt+'/whole/checkpoint.bin']==old[prefix+'checkpoint.bin']
  for phase in ('whole','strict-own-1088'):
   run=json.loads(files[opt+'/'+phase+'/RESULT.json'])
   assert run['returncode']==0 and run['from_start'] is False
   assert run['executable_sha256']==build['executable_sha256']
   expected_seed=old[prefix+'checkpoint-1077.bin'] if phase=='whole' else files[opt+'/whole/checkpoint-1088.bin']
   assert run['restart_sha256']==sha(expected_seed)
   expected_scope='INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION' if phase=='whole' else 'STRICT_SAME_BUILD_RESTART_MEASUREMENT'
   assert run['scope']==expected_scope
   for name,pin in run['inputs'].items():
    raw=files[opt+'/'+phase+'/'+name];assert sha(raw)==pin
    assert raw==old['case/'+name],'unchanged physical/input-window source bytes'
  for name,clock in [('budget.csv','t1_day'),('crop.csv','day')]:
   assert read_csv(files[opt+'/whole/'+name])==[r for r in read_csv(old[prefix+name]) if float(r[clock])>1077]
 print(result['status']);print(json.dumps({opt:r['export_components'] for opt,r in result['optimizations'].items()}))

if __name__=='__main__':main()
