"""Cold data qualification of the exact original input-grid continuation."""
import argparse,copy,hashlib,io,json,math,tarfile
from pathlib import Path
import original_oxygen_grid_continuation as owner
ROOT=owner.ROOT;BASE=owner.BASE;STEM='ORIGINAL_OXYGEN_GRID_EVIDENCE_20261104';sha=owner.sha
NAMES=['REGISTRATION.json','RESULT.json','stdout','stderr','case/swap.ok',*['case/'+n for n in owner.INPUTS],
       'case/result_output.csv','case/hupsel_profiles.csv','case/swap.log','case/swap.wrn','case/result.bal','case/result.blc']

def refuse(files,parent,cap,precision):
 count=0
 def rejected(f):
  nonlocal count
  try:owner.audit(f,parent,cap,precision)
  except (AssertionError,ValueError,KeyError):count+=1
  else:raise AssertionError('corrupted original refinement accepted')
 def change_json(f,name,edit):
  r=json.loads(f[name]);edit(r);f[name]=(json.dumps(r)+'\n').encode()
 def reseal(f,name):change_json(f,'RESULT.json',lambda r:r['output_sha256'].__setitem__(name,sha(f['case/'+name])))
 f=dict(files);f['case/potato.crp']+=b'\n';change_json(f,'REGISTRATION.json',lambda r:r['inputs_sha256'].__setitem__('potato.crp',sha(f['case/potato.crp'])));rejected(f)
 f=dict(files);change_json(f,'REGISTRATION.json',lambda r:r.__setitem__('executable_sha256','0'*64));rejected(f)
 f=dict(files);f['case/result_output.csv']=b'\n'.join(f['case/result_output.csv'].splitlines()[:-1])+b'\n';reseal(f,'result_output.csv');rejected(f)
 f=dict(files);lines=f['case/hupsel_profiles.csv'].splitlines();parts=lines[35].split(b',');parts[5]=b'0.9';lines[35]=b','.join(parts);f['case/hupsel_profiles.csv']=b'\n'.join(lines)+b'\n';reseal(f,'hupsel_profiles.csv');rejected(f)
 f=dict(files);change_json(f,'RESULT.json',lambda r:r.__setitem__('status','CENSORED'));rejected(f)
 f=dict(files);change_json(f,'REGISTRATION.json',lambda r:r.__setitem__('checkpoint_seed','foreign.bin'));rejected(f)
 f=dict(files);change_json(f,'REGISTRATION.json',lambda r:r.__setitem__('cap_day',owner.CAPS[1] if cap==owner.CAPS[0] else owner.CAPS[0]));rejected(f)
 f=dict(files);lines=f['case/hupsel_profiles.csv'].splitlines();lines[1],lines[2]=lines[2],lines[1];f['case/hupsel_profiles.csv']=b'\n'.join(lines)+b'\n';reseal(f,'hupsel_profiles.csv');rejected(f)
 f=dict(files);f['case/swap.ok']=b'simulation failed';rejected(f)
 f=dict(files);change_json(f,'RESULT.json',lambda r:r.__setitem__('production_admission',True));rejected(f)
 assert count==10
 return count

def qualify(files,parent):
 identity=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text());parent_refusals=0
 for field,value in [('archive_sha256','0'*64),('production_admission',True)]:
  bad=dict(identity);bad[field]=value
  try:owner.require_parent_identity(bad)
  except AssertionError:parent_refusals+=1
  else:raise AssertionError('resealed parent authority accepted')
 assert parent_refusals==2
 summaries=[];series=[]
 for i in range(4):
  cap=owner.CAPS[i%2];precision='legacy' if i<2 else 'strict'
  subset={n[len(str(i))+1:]:raw for n,raw in files.items() if n.startswith(str(i)+'/')}
  result=owner.audit(subset,parent,cap,precision);result['refusal_controls']=refuse(subset,parent,cap,precision);summaries.append(result)
  series.append(owner.rows(subset['case/result_output.csv']))
 def delta(a,b):
  errors=[abs(float(x['TREDWET'])-float(y['TREDWET'])) for x,y in zip(a,b)]
  assert len(errors)==585
  return dict(maximum_cm=max(errors),day=errors.index(max(errors)))
 legacy=[owner.rows(parent['reference-refinement/case/result_output.csv']),*series[:2]]
 changes=[delta(a,b) for a,b in zip(legacy,legacy[1:])]
 strict_change=delta(series[2],series[3]);precision_effects=[delta(series[i],series[i+2]) for i in range(2)]
 bound=5.371840000016327e-7
 # Convergence observations are not an extrapolated oracle, a physical
 # correction, or permission to erase the predecessor's retained failures.
 report=dict(actual_prefix_days=584,design='two grids by original nonlinear input precision; same original executable and physics',
  legacy_step_caps_day=[.00015625,*owner.CAPS],legacy_day584_oxygen_cm=[float(s[584]['TREDWET']) for s in legacy],
  legacy_successive_oxygen_changes=changes,strict_step_caps_day=list(owner.CAPS),
  strict_day584_oxygen_cm=[float(s[584]['TREDWET']) for s in series[2:]],strict_grid_oxygen_change=strict_change,
  nonlinear_precision_oxygen_effects=precision_effects,
  interpretation='Input criteria can change the original adaptive sequence; this factorial response is not an isolated causal term or a rigorous error estimate.',
  unchanged_oxygen_bound_cm=bound,observed_last_grid_changes_within_bound=changes[-1]['maximum_cm']<=bound and strict_change['maximum_cm']<=bound,
  no_extrapolated_or_replaced_oracle=True,reference_promoted=False,production_admission=False,
  whole_scientific_admission=False,original_model_source_changed=False,runs=summaries)
 report['immutable_parent_refusal_controls']=parent_refusals
 if changes[1]['maximum_cm']>0:report['legacy_observed_change_ratio']=changes[0]['maximum_cm']/changes[1]['maximum_cm']
 return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--runs',type=Path,nargs=4)
 p.add_argument('--archive',type=Path);a=p.parse_args();parent=owner.parent_files()
 if a.capture:
  assert a.runs and a.archive;out=a.capture.resolve();out.mkdir();files={}
  for i,root in enumerate(a.runs):
   for n in NAMES:files[str(i)+'/'+n]=(root/n).read_bytes()
  report=qualify(files,parent);files['AUDIT.json']=(json.dumps(report,indent=2)+'\n').encode()
  for n,raw in files.items():f=out/n;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(raw)
  with tarfile.open(a.archive.resolve(),'w:xz',preset=6) as t:
   for n,raw in sorted(files.items()):info=tarfile.TarInfo(n);info.size=len(raw);info.mtime=0;t.addfile(info,io.BytesIO(raw))
  raw=a.archive.read_bytes();parts=[]
  for i,start in enumerate(range(0,len(raw),4*1024*1024)):
   name=STEM+'.tar.xz.part'+str(i).zfill(2);chunk=raw[start:start+4*1024*1024];(BASE/name).write_bytes(chunk);parts.append(dict(name=name,sha256=sha(chunk),bytes=len(chunk)))
  deps=['tests/dataqual15_hupsel/original_oxygen_grid_continuation.py','tests/dataqual15_hupsel/original_oxygen_grid_evidence.py','integration/dataqual15_hupsel/ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json']
  record=dict(status='ACTUAL_ORIGINAL_INPUT_REFINEMENT_NOT_PRODUCTION',archive_sha256=sha(raw),archive_parts=parts,
   files_sha256={n:sha(b) for n,b in files.items()},normalized_repository_dependency_sha256={n:sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n')) for n in deps},
   parent_original_chronology_archive_sha256=json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text())['archive_sha256'],production_admission=False,whole_scientific_admission=False)
  (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n')
 else:
  record=json.loads((BASE/(STEM+'.json')).read_text());assert not record['production_admission'] and not record['whole_scientific_admission']
  for n,h in record['normalized_repository_dependency_sha256'].items():assert sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h,n
  parts=[]
  for i,p in enumerate(record['archive_parts']):
   assert p['name']==STEM+'.tar.xz.part'+str(i).zfill(2);raw=(BASE/p['name']).read_bytes();assert len(raw)==p['bytes'] and sha(raw)==p['sha256'];parts.append(raw)
  raw=b''.join(parts);assert sha(raw)==record['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw)) as t:
   names=t.getnames();assert len(names)==len(set(names)) and set(names)==set(record['files_sha256']);files={n:t.extractfile(n).read() for n in names}
  assert all(sha(b)==record['files_sha256'][n] for n,b in files.items())
  assert record['parent_original_chronology_archive_sha256']==json.loads((BASE/'ORIGINAL_CHRONOLOGY_EVIDENCE_20261104.json').read_text())['archive_sha256']
  report=qualify(files,parent);assert report==json.loads(files['AUDIT.json'])
 print(json.dumps(report,indent=2))

if __name__=='__main__':main()
