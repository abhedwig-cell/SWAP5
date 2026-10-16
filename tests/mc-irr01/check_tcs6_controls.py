"""Negative admission witnesses: source identity, real commands, native owners and retained raw science."""
import copy,json,sys
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parent))
import verify_tcs6_successor as v
count=0
def rejects(label,call):
 global count
 try:call()
 except (ValueError,AssertionError,KeyError,FileNotFoundError,StopIteration):count+=1;print('TCS6_CONTROL_'+label+'=PASS');return
 raise AssertionError('accepted invalid '+label)
assert v.verify_qualification()['qualified']
g=v.git
for surface in ('src','tests','reference'):
 def foreign(*args,surface=surface):
  text=g(*args);return text+'\nA\t'+surface+'/unreviewed'if args[:2]==('diff','--name-status')else text
 rejects('FOREIGN_'+surface,lambda:v.verify_source(foreign))
def dirty(*args):return ' M src/crop/unknown'if args[:2]==('status','--porcelain')else g(*args)
rejects('DIRTY',lambda:v.verify_source(dirty))
for p in v.PRODUCTION:
 r=copy.deepcopy(v.record());r['postimages'][p]['blob']='0'*40
 with patch.object(v,'record',return_value=r):rejects('STALE_'+Path(p).stem,v.verify_source)
r=copy.deepcopy(v.record());r['phase']='IMPLEMENTED'
with patch.object(v,'record',return_value=r):rejects('UNFINISHED',v.verify_qualification)
r=copy.deepcopy(v.record());r['science_archive']['decoded_sha256']='0'*64
with patch.object(v,'record',return_value=r):rejects('CORRUPT_ARCHIVE',v.evidence)
data=v.evidence()
for label,change in [
 ('MISSING_TRAJECTORY',lambda r:r['results'].pop()),('DUPLICATE_TRAJECTORY',lambda r:r['results'].__setitem__(-1,r['results'][0])),
 ('FAILED_TRAJECTORY',lambda r:r['results'][0].__setitem__('returncode',1)),('MISSING_COMMAND',lambda r:r['events'].__setitem__(next(i for i,e in enumerate(r['events'])if 'native-resume'in e['command']),{'command':['false'],'returncode':0})),
 ('NO_TRAPS',lambda r:next(e for e in r['events']if '-c'in e['command'])['command'].remove('-ffpe-trap=invalid,zero,overflow'))]:
 d=dict(data);r=json.loads(d['physical/RESULTS.json']);change(r);d['physical/RESULTS.json']=json.dumps(r).encode();rejects(label,lambda:v.validate_science(d))
for label,p in [('NATIVE_ENDPOINT','physical/o0/test-weekly_dcs1.morning.resumed'),('UNEXECUTED_GENERATOR','physical/weekly_dcs1.f90'),('LITERAL','direct/literal_tcs6.f90')]:
 d=dict(data);d[p]+=b'changed';rejects(label,lambda:v.validate_science(d))
for label,p in [('MISSING_RAW',next(p for p in data if p.startswith('physical/')and p.endswith('.stderr'))),('MISSING_NATIVE','physical/o0/test-weekly_dcs1.dayend.active.resumed')]:
 d=dict(data);d.pop(p);rejects(label,lambda:v.validate_science(d))
d=dict(data);p='physical/DECODER_0_weekly_dcs1_neutral.json';r=json.loads(d[p]);r.pop();d[p]=json.dumps(r).encode();rejects('MISSING_DECODER_NEGATIVE',lambda:v.validate_science(d))
d=dict(data);p='review/projections.json';r=json.loads(d[p]);r.pop(next(iter(r)));d[p]=json.dumps(r).encode();rejects('MISSING_BODY_REVIEW',lambda:v.validate_science(d))
print('TCS6_ADMISSION_NEGATIVES='+str(count)+'|PASS')
