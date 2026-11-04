"""Source-bound complete-corpus private safeguard audit; never runtime admission."""
import argparse,base64,gzip,io,json,tarfile
from pathlib import Path,PurePosixPath
import film_refinement_candidate as c
f=c.f;STEM='FILM_REFINEMENT_WINDOWS_20261104'

def audit(files,context):
 scope,raw,corpus,table=context;source=(f.ROOT/c.owner.SOURCE).read_text();cases=c.owner.selected(corpus);body=c.candidate(source)
 observed=json.loads(files['observation/RESULT.json']);trial=json.loads(files['candidate/RESULT.json'])
 assert observed['status']=='ACTUAL_O0_O2_REFINEMENT_OBSERVATION_AND_EXACT_FULL_CORPUS_CONTROLS_PASS'
 assert trial['status']=='PRIVATE_TWO_SUCCESSIVE_REFINEMENTS_COMPLETE_CORPUS_AND_FAIL_CLOSED_CONTROLS_PASS'
 assert observed['source_sha256']==trial['source_sha256']==f.sha(source.encode())
 assert trial['candidate_sha256']==f.sha(body.encode()) and observed['input_sha256']==trial['input_sha256']==f.sha(raw)
 assert all(x['production_admission']is False and x['whole_scientific_admission']is False for x in (observed,trial))
 assert trial['reference_trajectory_accuracy_qualified']is False
 carrier=json.loads((f.ROOT/'integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json').read_text());literal=gzip.decompress(base64.b64decode(carrier['gzip_base64']));assert f.sha(literal)=='8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87'
 parent=json.loads((f.BASE/'FILM_ACCURACY_WINDOWS_20261104.json').read_text())
 with tarfile.open(fileobj=io.BytesIO((f.BASE/parent['archive']).read_bytes()))as t:oracle={opt:[list(map(float,line.split()))for line in t.extractfile(opt+'/certified.stdout').read().decode().splitlines()]for opt in ('O0','O2')}
 result={}
 for opt in ('O0','O2'):
  paths=['observation/'+opt+'-plain','observation/'+opt+'-observed','candidate/'+opt]
  for prefix in paths:
   expected=source if prefix.endswith('plain')else c.owner.observed(source,cases)if prefix.endswith('observed')else body
   assert files[prefix+'/waterfilm.f90'].decode().replace('\r\n','\n')==expected
   assert files[prefix+'/fixture.f90'].decode().replace('\r\n','\n')==f.MODULE
   assert files[prefix+'/oxygen.f90'].decode().replace('\r\n','\n')==f.adapted_source(literal.decode())
   assert files[prefix+'/driver.f90'].decode().replace('\r\n','\n')==f.adapted_driver((f.ROOT/'tests/dataqual15_hupsel/original_factor_comparison.f90').read_text())
   meta=json.loads(files[prefix+'/BUILD.json']);assert f.sha(files[prefix+'/compare.exe'])==meta['executable_sha256']
   assert set(meta['source_sha256'])=={'fixture.f90','oxygen.f90','driver.f90','waterfilm.f90','tests/dataqual15_hupsel/matched_oxygen_owners.f90',*[path for path in scope['factor_repository_order']if path!=c.owner.SOURCE]}
   for path,pin in meta['source_sha256'].items():
    key=prefix+'/'+path if '/'not in path else 'compiled-source/'+path
    assert f.sha(files[key])==pin
    if '/'in path:assert files[key].replace(b'\r\n',b'\n')==(f.ROOT/path).read_bytes().replace(b'\r\n',b'\n')
  plain,watched,changed=paths
  original=files[plain+'/comparison.stdout'];assert original==files[watched+'/comparison.stdout']
  assert f.sha(original)==observed['builds'][opt]['exact_unobserved_stdout_sha256']
  receipts=c.owner.receipts(files[watched+'/comparison.stderr'],cases);assert receipts==observed['builds'][opt]['observations']
  assert receipts[0]['exit_level']==3 and receipts[0]['accepted_successive_relative_change']<=1e-5 and receipts[0]['independent_relative_integral_error']>1e-5
  base=[list(map(float,line.split()))for line in original.decode().splitlines()];rows=[list(map(float,line.split()))for line in files[changed+'/comparison.stdout'].decode().splitlines()]
  before=c.errors(base,corpus,table);after=c.errors(rows,corpus,table);m=trial['builds'][opt]
  assert before==m['before'] and after==m['after'] and before['maximum_relative_integral_error']>1e-5 and after['maximum_relative_integral_error']<=1e-5
  assert all(x[:5]+x[6:8]==y[:5]+y[6:8]for x,y in zip([line.split()for line in original.splitlines()],[line.split()for line in files[changed+'/comparison.stdout'].splitlines()]))
  factor=max(abs(x[5]-y[4])for x,y in zip(rows,oracle[opt]));assert factor==m['certified_original_factor_maximum']<=1e-4
  probes=m['fault_controls'];assert len(probes)==9
  assert files['faults/'+opt+'/probe.f90'].decode().replace('\r\n','\n')==c.probe_source(corpus[1247][12])
  variants={'candidate':body,'candidate-cap2':body.replace('do level = 2, 24','do level = 2, 2'),'incumbent-cap2':source.replace('do level = 2, 24','do level = 2, 2')}
  for variant,expected in variants.items():
   prefix='faults/'+opt+'/'+variant;assert files[prefix+'/waterfilm.f90'].decode().replace('\r\n','\n')==expected
   meta=json.loads(files[prefix+'/BUILD.json']);assert f.sha(files[prefix+'/probe.exe'])==meta['executable_sha256']
   assert set(meta['source_sha256'])=={'mod_bartholomeus_waterfilm.f90','waterfilm.f90','probe.f90'}
   for name,pin in meta['source_sha256'].items():
    key='compiled-source/src/physics/oxygen/'+name if name.startswith('mod_')else 'faults/'+opt+'/probe.f90'if name=='probe.f90'else prefix+'/'+name
    assert f.sha(files[key])==pin
  for probe in probes:
   prefix='faults/'+opt+'/'+probe['variant'];data=files[prefix+'/'+probe['mode']+'.stdout'].decode().split();assert (data[0]=='T')==probe['ok']and float(data[1])==probe['returned']
   expected=probe['variant']=='incumbent-cap2'or(probe['variant']=='candidate'and probe['mode']in ('ordinary','dry'))
   assert probe['ok']==expected
  result[opt]=dict(before=before,after=after,certified_original_factor_maximum=factor,actual_observer_exact=True,native_refusals=6)
 return dict(status='ACTUAL_REFINEMENT_DIAGNOSIS_PRIVATE_SAFEGUARD_AND_FAIL_CLOSED_DATA_PASS',profiles=3206,rooted_nodes=41678,builds=result,production_admission=False,whole_scientific_admission=False,changed_runtime_qualified=False)

def controls(files,context):
 trials=[]
 for flag in ('production_admission','whole_scientific_admission','reference_trajectory_accuracy_qualified'):
  r=json.loads(files['candidate/RESULT.json']);r[flag]=True;trials.append(dict(files,**{'candidate/RESULT.json':json.dumps(r).encode()}))
 for path in ('candidate/O0/comparison.stdout','observation/O2-observed/comparison.stderr','candidate/O2/waterfilm.f90','faults/O0/candidate-cap2/waterfilm.f90','faults/O2/probe.f90'):
  changed=dict(files);changed[path]=files[path][:-30];trials.append(changed)
 r=json.loads(files['candidate/RESULT.json']);r['builds']['O0']['after']['maximum_relative_integral_error']=0;trials.append(dict(files,**{'candidate/RESULT.json':json.dumps(r).encode()}))
 for changed in trials:
  try:audit(changed,context)
  except (AssertionError,ValueError,KeyError,IndexError):pass
  else:raise AssertionError('false private convergence authority accepted')
 return len(trials)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--observation',type=Path);p.add_argument('--candidate',type=Path);p.add_argument('--faults',type=Path);a=p.parse_args();context=c.owner.load()
 if a.observation:
  assert a.candidate and a.faults;files={}
  for label,folder in [('observation',a.observation),('candidate',a.candidate),('faults',a.faults)]:
   for path in folder.rglob('*'):
    if path.is_file()and(path.name=='RESULT.json'or path.name=='BUILD.json'or path.suffix in ('.stdout','.stderr','.f90','.exe')):files[label+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
  for path in context[0]['factor_repository_order']:files['compiled-source/'+path]=(f.ROOT/path).read_bytes()
  files['compiled-source/tests/dataqual15_hupsel/matched_oxygen_owners.f90']=(f.ROOT/'tests/dataqual15_hupsel/matched_oxygen_owners.f90').read_bytes()
  result=audit(files,context);result['data_refusals']=controls(files,context)
  archive=f.BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz',preset=3)as t:
   for name,raw in sorted(files.items()):info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
  manifest=dict(result,archive=archive.name,archive_sha256=f.sha(archive.read_bytes()),files_sha256={n:f.sha(raw)for n,raw in files.items()})
  (f.BASE/(STEM+'.json')).write_text(json.dumps(manifest,indent=2)+'\n')
 else:
  record=json.loads((f.BASE/(STEM+'.json')).read_text());assert record['production_admission']is False and record['whole_scientific_admission']is False
  raw=(f.BASE/record['archive']).read_bytes();assert f.sha(raw)==record['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   members=t.getmembers();assert len(members)==len(record['files_sha256'])and all(m.isfile()and not PurePosixPath(m.name).is_absolute()and '..'not in PurePosixPath(m.name).parts for m in members)
   files={m.name:t.extractfile(m).read()for m in members}
  assert set(files)==set(record['files_sha256'])and all(f.sha(raw)==record['files_sha256'][n]for n,raw in files.items())
  result=audit(files,context);result['data_refusals']=controls(files,context)
 print(json.dumps(result))
if __name__=='__main__':main()
