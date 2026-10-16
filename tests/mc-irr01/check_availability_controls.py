"""Fail-closed AVAIL admission controls, using actual source and retained raw science."""
import copy,json,sys
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_availability_successor as v
count=0
def rejects(label,call):
 global count
 try:call()
 except(ValueError,AssertionError,KeyError,FileNotFoundError,StopIteration):count+=1;print('AVAIL_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
assert v.verify_qualification()['qualified'];g=v.git
for surface in ['src','tests','reference']:
 def foreign(*a,surface=surface):
  text=g(*a);return text+'\nA\t'+surface+'/unreviewed'if a[:2]==('diff','--name-status')else text
 rejects('FOREIGN_'+surface,lambda:v.verify_source(foreign))
def dirty(*a):return ' M src/runtime/foreign'if a[:2]==('status','--porcelain')else g(*a)
rejects('DIRTY',lambda:v.verify_source(dirty))
for p in [*v.PRODUCTION,'tests/mc-irr01/verify_tcs6_successor.py']:
 r=copy.deepcopy(v.record());r['postimages'][p]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(p).stem,v.verify_source)
r=copy.deepcopy(v.record());r['phase']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED',v.verify_qualification)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_ARCHIVE',v.evidence)
data=v.evidence()
for label,change in [
 ('MISSING_TRAJECTORY',lambda p:p['rows'].pop()),('DUPLICATE_TRAJECTORY',lambda p:p['rows'].__setitem__(-1,p['rows'][0])),('FAILED_TRAJECTORY',lambda p:p['rows'][0].__setitem__('returncode',1)),
 ('MISSING_COMMAND',lambda p:p['events'].__setitem__(next(i for i,e in enumerate(p['events'])if 'native-resume'in e['command']),{'command':['false'],'returncode':0})),
 ('NO_TRAPS',lambda p:next(e for e in p['events']if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow')),
 ('DONOR_ARTIFACT',lambda p:p['reuse']['compiled_artifacts'].pop(next(iter(p['reuse']['compiled_artifacts'])))),('DONOR_COMPILER',lambda p:p['reuse']['compiler'].__setitem__('launcher_sha256','0'*64))]:
 d=dict(data);p=json.loads(d['physical/RESULTS.json']);change(p);d['physical/RESULTS.json']=json.dumps(p).encode();rejects(label,lambda:v.validate_science(d))
for label,p in [('NATIVE_ENDPOINT','physical/o0/test-root2.morning.resumed'),('UNEXECUTED_GENERATOR','physical/root2.f90'),('LITERAL','direct/literal.f90'),('INCUMBENT','review/incumbent.json')]:
 d=dict(data);d[p]+=b'changed';rejects(label,lambda:v.validate_science(d))
for label,p in [('MISSING_RAW',next(p for p in data if p.startswith('physical/')and p.endswith('.stderr'))),('MISSING_NATIVE','physical/o0/test-sensor7.native-resume.final')]:
 d=dict(data);d.pop(p);rejects(label,lambda:v.validate_science(d))
for label,mutate in [('MISSING',lambda rows:rows.pop()),('DUPLICATE',lambda rows:rows.__setitem__(-1,rows[0])),('UNBOUND',lambda rows:rows[0].__setitem__('input_sha256','0'*64)),('FAILED',lambda rows:rows[0].__setitem__('returncode',1))]:
 d=dict(data);p='physical/DECODER_0_sensor7_neutral.json';rows=json.loads(d[p]);mutate(rows);d[p]=json.dumps(rows).encode();rejects('DECODER_'+label,lambda:v.validate_science(d))
d=dict(data);p='review/projections.json';r=json.loads(d[p]);r.pop(next(iter(r)));d[p]=json.dumps(r).encode();rejects('MISSING_BODY_REVIEW',lambda:v.validate_science(d))
print('AVAIL_ADMISSION_NEGATIVES='+str(count)+'|PASS')
