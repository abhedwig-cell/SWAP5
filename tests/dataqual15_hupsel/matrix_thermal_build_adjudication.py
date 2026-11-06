"""Retain actual MC physical passes and the uncensored broad science refusal."""
import argparse,gzip,json,struct,zipfile,zlib
from pathlib import Path
import matrix_thermal_build as owner
p=owner.private;D=p.ROOT/'integration/dataqual15_hupsel';STEM='MATRIX_THERMAL_BUILD_ADJUDICATION_20261106'

def observe():
 archives=['MATRIX_THERMAL_BUILD_MC_SOURCE_20261106.zip','MATRIX_THERMAL_BUILD_MC_SOURCE_20261106.log.gz','MATRIX_THERMAL_BUILD_BASELINE_20261106.zip'];pins={n:p.sha((D/n).read_bytes()) for n in archives}
 assert pins[archives[0]]=='4617cbed502023e3f76ef2c93d4ed05d834a858477d61cfbb61ca90f3aa533a7'
 text=gzip.decompress((D/archives[1]).read_bytes()).decode();assert 'verify_dataqual12_current.py' in text and 'AssertionError: unreviewed delta' in text
 assert '##[error]Process completed with exit code 1.' in text
 with zipfile.ZipFile(D/archives[2]) as z:
  before=json.loads(z.read('RESULT.json'));stderr=z.read('baseline.stderr');assert p.sha(stderr)==before['stderr_sha256'] and before['baseline']==owner.BASE and before['returncode']!=0
  assert before['status']=='ACTUAL_PREDECESSOR_DATAQUAL12_FIRST_SOURCE_REFUSAL_RETAINED_NO_SCIENCE_PASS' and b'AssertionError: unreviewed delta' in stderr and b'verify_dataqual12_current.py' in stderr
 cases={};proper=0
 with zipfile.ZipFile(D/archives[0]) as z:
  names=z.namelist();assert len(names)==len(set(names))
  for label in ('thermal',*['nonlinear-'+x for x in ('0.5','0.8','1.0005','1.5','2')]):
   physical=label+'-physical/';qualified=label+'-qualified/';r=json.loads(z.read(physical+'result.json'));q=json.loads(z.read(qualified+'result.json'))
   assert r['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
   assert q['status']=='DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED' and q['physical_sha256']==p.sha(z.read(physical+'result.json'))
   assert all(e['returncode']==e['expected_returncode'] for e in q['events'])
   assert sum(e['category']=='crash_native' and e['returncode']==-9 for e in q['events'])==4
   for opt in ('O0','O2'):
    row=q['results'][opt];assert row['final_relative_decay_difference']<1e-3 and row['kill_before_after_generation_exact'] is True
    for key in ('mass_delta','decay_delta'):assert all(a>b>0 for a,b in zip(row[key],row[key][1:]))
    assert row['executable_sha256']==r['executables'][opt]
    for grid in ('2','4','8','16'):
     raw=z.read(physical+opt+'/'+grid+'/full.bin');assert raw==z.read(physical+opt+'/'+grid+'/resumed.bin')
     for name in ('full.bin','resumed.bin','restart.bin'):
      data=z.read(physical+opt+'/'+grid+'/'+name);assert data[:8]==b'S5MT0001' and struct.unpack('<I',data[-4:])[0]==zlib.crc32(data[:-4]);proper+=1
   cases[label]=dict(exponent=r['exponent'],physical_sha256=p.sha(z.read(physical+'result.json')),qualified_sha256=p.sha(z.read(qualified+'result.json')),status=q['status'])
 return dict(archives=pins,cases=cases,proper_native_files_checked=proper,broad_source_gate='FAILED_RETAINED',baseline_first_refusal='DATAQUAL12_SOURCE_DELTA',current_first_refusal='DATAQUAL12_SOURCE_DELTA',classification='SAME_FIRST_DENOMINATOR_REFUSAL_NOT_IDENTICAL_FULL_DELTA_OR_LATER_SCIENCE_PASS',source_run=42159449130,source_job=127701351017,source_head='684ad5b236b3acf36c1a273540ae71eb1640572e',production_admission=False,whole_scientific_admission=False)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true');a=parser.parse_args();owner.guard();actual=observe();file=D/(STEM+'.json')
 if a.seal:file.write_text(json.dumps(actual,indent=2)+'\n')
 else:assert actual==json.loads(file.read_text())
 print('ACTUAL_SIX_MC_NATIVE_PHYSICAL_PASSES_AND_BROAD_SOURCE_REFUSAL_RETAINED_NOT_SCIENTIFIC_ADMISSION')
