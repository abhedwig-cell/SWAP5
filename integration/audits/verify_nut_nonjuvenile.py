"""Nonjuvenile allocation with unchanged predecessor assertions and explicit scope."""
from pathlib import Path
import hashlib,json,re,subprocess,runpy
import numpy as np
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[2];BASE='47a50ea0bcf0dd17e4c32e502ee0917e689cb9f8';UNIT='integration/mc-nut01/competing_sinks/';STATUS=UNIT+'NONJUVENILE_INPUTS.json';PARENT='integration/audits/verify_nut_partition.py';SELF='integration/audits/verify_nut_nonjuvenile.py';DAILY='src/process/mod_b111_soil_n_daily_exchange.f90'
sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record():return json.loads((ROOT/STATUS).read_bytes())
def projection():
 s=before(PARENT).decode()
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  s=re.sub(r'^def '+name+r'\(\):(?=\S)','def '+name+'():\n ',s,flags=re.M);at=s.index('\n',re.search(r'^def '+name+r'\(',s,re.M).start())+1
  s=s[:at]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+s[at:]
 return s.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 r=record();assert r['base']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD')
 delta={s.split('\t')[1]:s.split('\t')[0]for s in git('diff','--name-status',BASE,'HEAD','--',*r['science_paths']).splitlines()}
 assert delta==r['scientific_delta']and not git('status','--porcelain','--',*r['science_paths']);assert {p for p in delta if p.startswith('src/')}=={DAILY}
 assert reader(PARENT)==projection()
 for p,h in r['postimages'].items():assert sha(reader(p))==h,('nonjuvenile source',p)
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def predecessor():
 n=dict(__file__=str(ROOT/PARENT),__name__='historical_juvenile_assertions');exec(compile(before(PARENT),PARENT,'exec'),n)
 class Archived:
  def read_bytes(self):return before(DAILY)
 class HistoricalRoot:
  def __str__(self):return str(ROOT)
  def __fspath__(self):return str(ROOT)
  def __truediv__(self,p):return Archived()if p==DAILY else ROOT/p
 n['ROOT']=HistoricalRoot()
 def projected(reader=None,changed=None):
  if reader is None:return source(changed=changed)
  def mapped(p):
   b=reader(p)
   if p==DAILY:
    old=before(p)
    if b in [old,old+b'!']:return (ROOT/p).read_bytes()+b[len(old):]
   return b
  return source(mapped,changed)
 projected(lambda p:(n['ROOT']/p).read_bytes());n['source']=projected;return n
def files():
 n=predecessor();return {k:n['unpack'](e)for k,e in record()['evidence'].items()}
def validate(f):
 n=predecessor();assert n['validate'](n['files']())['qualified']
 daily=f['daily'];r=json.loads(daily['current/result.json']);assert r['cases_per_optimization']==2016 and r['incumbent_byte_exact']==2496
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 es=json.loads(daily['current/events.json']);assert all(e['returncode']==0 for e in es)
 outputs=dict(zip(['O0','O2'],[np.array([list(map(float,l.split()))for l in daily['current/'+e['stdout']].splitlines()])for e in es if e['category']=='opt_in']))
 script=(ROOT/(UNIT+'run_nonjuvenile.py')).read_text();body=script[script.index("assert np.max(abs(outputs['O0']"):script.index('\nr=dict(status=')];ns=dict(np=np,solve_ivp=solve_ivp,outputs=outputs,cases=json.loads(daily['current/input.json']));exec(compile(body,'nonjuvenile_independent_oracle','exec'),ns)
 assert ns['counts']==r['branch_counts']
 streams=lambda cat:[daily['current/'+e['stdout']]for e in es if e['category']==cat]
 assert streams('incumbent_current')==streams('incumbent_baseline')and len(streams('incumbent_current'))==2
 for raw in streams('invalid_opt_in'):assert len(raw.splitlines())==3 and all(int(l.split()[0])!=0 for l in raw.splitlines())
 # Retain the predecessor's complete coupled/restart/ledger assertion block.
 script=before(PARENT).decode();body=script[script.index(" for label,prefix,count in"):script.index(" f=allfiles['hist'];")]
 ns=dict(allfiles=f,js=lambda f,p:json.loads(f[p]),inputs=lambda r:[(_ for _ in ()).throw(AssertionError(p))for p,h in r['input_sha256'].items()if sha((ROOT/p).read_bytes())!=h],sha=sha,struct=__import__('struct'))
 exec(compile('if True:\n'+body,'nonjuvenile_coupled_assertions','exec'),ns)
 h=json.loads(f['hist']['result.json']);old=json.loads(n['files']()['hist']['result.json']);assert h['results']==old['results']
 for p,hsh in h['input_sha256'].items():assert sha((ROOT/p).read_bytes())==hsh
 es=json.loads(f['hist']['events.json']);assert all(e['returncode']==0 for e in es)and sum(e['category']in ['native','restart_native','trace_native']for e in es)==78
 reuse=json.loads(f['hist']['REUSE.json']);assert reuse['fresh_compile_events']==44 and reuse['reused_compile_events']==612 and reuse['fresh_native_events']==78 and reuse['all_original_assertions_completed']
 assert set(reuse['changed_inputs'])=={DAILY}and sum(e['category']=='compile'for e in es)==656
 excluded=json.loads(f['hist']['excluded-build-artifacts.json'])
 for e in es:
  if e['category']=='compile'and e['receipt_scope'].startswith('REUSED_'):
   opt=next(v[1:]for v in e['command']if v in ['-O0','-O2']);assert e['object_sha256']==excluded[opt+'/'+Path(e['command'][-1]).name]['sha256']
 for opt,row in h['results'].items():
  assert sha(f['hist'][opt+'/default.endpoint'])==row['default_endpoint']
  for case,digest in row['endpoint'].items():assert sha(f['hist'][opt+'/'+case+'.endpoint'])==digest
 return dict(qualified=True,status='NONJUVENILE_PARTITION_CURRENT_DAILY_HIST_RUNTIME_DEFAULT_QUALIFIED',daily_cases=2016,incumbent_byte_exact=2496,HIST_processes=78,coupled_runs=4,coupled_restarts=8,default_coupled_runs=30,default_coupled_restarts=60,historical_predecessor_scope='46 original controls and mathematical assertion bodies, one explicitly archived daily provider; fresh current proof separate',canonically_admitted=False,full_mc_nut01_closed=False)
def verify():source();return validate(files())
def self_test():
 source();f=files();validate(f);passed=['historical-juvenile:'+p for p in predecessor()['self_test']()]
 def reject(label,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError):passed.append(label);return
  raise AssertionError('accepted nonjuvenile corruption '+label)
 for p in record()['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_nonjuvenile.f90':'A'}))
 for label,p in [('daily','current/input.json'),('runtime','current/O0/crop_both.endpoint'),('runtime','current/O2/crop_nh4.fresh-4.ledger'),('default','O0/empty_both.endpoint'),('hist','O0/default.endpoint')]:
  bad={k:dict(v)for k,v in f.items()};bad[label][p]+=b'!';reject('raw '+label+'/'+p,lambda bad=bad:validate(bad))
 return passed
def fsi35_successors():source();return predecessor()['fsi35_successors']()
if __name__=='__main__':
 import sys
 print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
