"""Source-bound original MACROINIT and bounded production initialization owner."""
import base64,hashlib,io,json,re,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BASE='9118712678cd305e9bbe96bc0a1ad8e6a51ada15';D='integration/mc-sol01/drainage/';STATUS=D+'NATIVE_MACRO_INITIAL_STATUS.json';SELF='integration/audits/verify_native_macro_initial_current.py';PARENT='integration/audits/verify_native_macro_geometry_current.py';SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits'];sha=lambda b:hashlib.sha256(b).hexdigest()
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def projection():
 t=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
 for name,args in [('source','reader,changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
  at=re.search(r'^def '+name+r'\(',t,re.M).start();end=t.index('):',at)+2
  if t[end:end+1]!='\n':t=t[:end]+'\n '+t[end:]
  end+=1;t=t[:end]+" if (ROOT/'"+STATUS+"').is_file():return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n"+t[end:]
 return t.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
 s=json.loads(reader(STATUS));assert s['baseline']==BASE;git('merge-base','--is-ancestor',BASE,'HEAD');assert not git('status','--porcelain','--',*SCIENCE),'unpersisted source'
 delta={x.split('\t')[1]:x.split('\t')[0]for x in git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()};assert delta==s['scientific_delta'],'foreign initialization delta';assert reader(PARENT)==projection(),'changed predecessor assertions'
 old=lambda p:subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
 p='tools/solute/legacy_reader_sources.py';assert reader(p)[:len(old(p))]==old(p),'old reader materializer changed'
 p='src/process/macropore/mod_macropore_dynamic_shrinkage.f90';t=reader(p).decode();t=t.replace('  public :: prepare_initial_dynamic_crack_profile\n','');t=re.sub(r'^  subroutine prepare_initial_dynamic_crack_profile\b.*?^  end subroutine prepare_initial_dynamic_crack_profile\n\n','',t,flags=re.M|re.S);assert t.encode()==old(p),'old dynamic trial procedures changed'
 p='src/process/macropore/mod_macropore_standard_storage.f90';t=reader(p).decode();a=t.index('      ! Original tapered IC domains');b=t.index('      capacity=sum',a);assert 'and.any(state%water_domain_cp(id,top_node:bottom)/=0.0_real64))return' in t[a:b];t=t[:a]+t[b:];anchor='      if(bottom<top_node .or. bottom>n)return\n';t=t.replace(anchor,anchor+'      if(state%volume_domain_cp(id,bottom)<=1.0e-8_real64)return\n');assert t.encode()==old(p),'foreign storage change'
 for p,h in s['postimages'].items():assert sha(reader(p))==h,p
 if changed is not None:
  for p in changed:assert p in delta or subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'foreign caller'
 return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def capsule():
 e=json.loads((ROOT/STATUS).read_bytes())['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes(),validate=True);assert sha(raw)==e['sha256']and len(raw)==e['bytes']
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==e['members']==len({m.name for m in ms});assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms);f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()};return f
def validate(f):
 js=lambda p:json.loads(f[p]);parent=js('parent/owner.json');assert parent['result']['qualified']and parent['result']['original_native_macro_geometry']and len(parent['negative_controls'])==17
 raw=f['parent/commit.raw'];assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
 for p,h in js('executed-hashes.json').items():assert sha((ROOT/p).read_bytes())==h and sha(f['executed/'+p])==h,p
 for p,h in js('raw-hashes.json').items():assert sha(f[p])==h,p
 r=js('initial/RESULT.json');assert r['status']=='ORIGINAL_MACROINIT112_FIVE_DOMAIN_TYPED_O0_O2_PASS'and r['source_input_unmodified']and r['source_dummy_invariance']and r['source_per_layer_hydraulics']==8 and not r['full_water_dispatch']and not r['file_restart']
 assert len(r['events'])==38 and all((e['returncode']==0)==e['expected_success']for e in r['events'])
 assert r['results']['O0']==r['results']['O2']and f['initial/O0.nml']==f['initial/O2.nml']
 for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
 rawpath='integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/rawpath).read_bytes())),mode='r:gz')as archive:
  original={Path(m.name).name:archive.extractfile(m).read()for m in archive.getmembers()if m.isfile()}
 for opt in ['O0','O2']:
  b=js('initial/'+opt+'/build-complete.json');assert b['status']=='BUILT'and not b['full_water_kernel_linked']and len(b['events'])==5 and all(e['returncode']==0 for e in b['events'])
  identity=b['original_source_identity'];generated=f['initial/'+opt+'/original_macro_initial.f90'];assert sha(generated)==b['generated_source_sha256']
  for p,h in identity['initial_raw_sha256'].items():assert sha(original[p])==h,p
  # Verify exact selected procedure bytes are present in the generated translation
  # unit and the archived authority; no copied hydraulic/Parlange implementation.
  for name,h in identity['initial_procedure_sha256'].items():
   text=original['MOD_MvG_functions.f90'if name.lower()in ['calc_cofgen_extra','set_cofgen_pointers','watcon','moiscap','hconduc','prhead']else'macropore.f90'].decode('latin1')
   kind='function'if name.lower()in ['watcon','moiscap','hconduc','prhead','shrink']else'subroutine'
   pattern=r'^ *'+(r'real\(8\) +'if kind=='function'else'')+kind+' '+name+r'\b.*?^ *end '+kind+' '+name+r'\b';m=re.search(pattern,text,re.I|re.M|re.S);assert m;body=m.group().encode('latin1');assert sha(body)==h and body in generated,name
  assert original['calcgwl.f90']in generated
  assert sha(f['initial/'+opt+'.nml'])==r['results'][opt]['descriptor_sha256']
  assert sha(f['initial/'+opt+'-consumer.stdout'])==r['results'][opt]['consumer_stdout_sha256']
  assert b'PRODUCTION_PASS nodes=112 domains=5'in f['initial/'+opt+'-consumer.stdout']
  assert b'canonical initial storage'in f['initial/'+opt+'-predecessor.stdout']
  for name in ['frost','macro-off','solute-on','empirical','bad-shrink','open-drain','drain-model']:
   output=f['initial/'+opt+'-'+name+'.stdout'];assert b'SWP_MACRO_GEOMETRY_REJECTED:'in output and b'File does not exist'not in output
  g=js('geometry/RESULT.json');assert g['status']=='ORIGINAL_MACRO112_FIVE_DOMAIN_GEOMETRY_O0_O2_TYPED_PASS'and len(g['events'])==18
  for name in ['macro-off','solute-on','bad-diameter']:assert b'File does not exist'not in f['geometry/'+opt+'-'+name+'.stdout']
  assert b'Range error of identifier'in f['geometry/'+opt+'-bad-diameter.stdout']
  thermal=js('thermal-'+opt+'/RESULT.json');assert thermal['phase']=='pilot'and len(thermal['events'])==3 and all(e['returncode']==0 for e in thermal['events'])
  for p,h in thermal['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
  for trace in [0,1]:
   name='replay-rutter-static-'+str(trace)+'.stdout';out=f['thermal-'+opt+'/'+name];assert out==f['prior-thermal-'+opt+'/'+name]
   for marker in [b'MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS',b'PPA_WU05A9_FMR_TOP_INPUT_REJECT_REPLAY=PASS',b'PPA_WU05_MIGMAC10_RUTTER_BOESTEN_MACROPORE_RESTART=PASS',b'PPA_WU05A9_FMR_TOP_INPUT_RESTART=PASS']:assert marker in out,marker
   assert len([x for x in out.splitlines()if x.startswith(b'MACRO_TRACE_CHECK_PASS')])==2 if trace else True
 values=r['results']['O2']['values'];assert len(values)==7 and values[0]>1.6 and values[1]>.14 and values[2]>.87 and values[3]>1.7 and values[4]>15 and values[5]>0 and abs(values[6])<1e-12
 result=dict(parent['result']);result.update(qualified=True,original_native_macro_initial_preparation=True,macroinit=True,canonical_macro_initial_state=True,old_trial_profile_source_exact=True,exactly_dry_tapered_tip_supported=True,nonempty_degenerate_tip_still_rejects=True,initial_O0_O2_exact=True,initial_macro_water_cm=values[0],initial_dynamic_volume_cm=values[1],initial_rapid_kd=values[2],initial_mass_residual_cm=values[6],current_bounded_thermal_native_processes=4,current_bounded_thermal_predecessor_exact=True,current_matrix_days=0,current_NUT_runs=0,current_NUT_separate_process_restarts=0,prior_geometry_negative_file_lookup_not_inherited=True,full481_reexecuted=False,full_original_Andelst=False,file_macro_heat_restart=False,whole_water_dispatch=False,canonically_admitted=False)
 return result
def verify():source();return validate(capsule())
def fsi35_successors():
 source();deps=json.loads((ROOT/'integration/audits/FCI93_NON_M1_COMPILE_DEPENDENCIES_20261011.json').read_bytes())['dependencies']
 for d in deps:assert git('rev-parse','HEAD:'+d['path'])==git('rev-parse',BASE+':'+d['path']),d['path']
 return dict(status='UNCHANGED_EXECUTABLE_DEPENDENCIES',dependencies=len(deps),baseline=BASE)
def self_test():
 source();f=capsule();validate(f);passed=[]
 def reject(name,fn):
  try:fn()
  except(AssertionError,KeyError,ValueError,TypeError,UnicodeError):passed.append(name);return
  raise AssertionError('accepted corrupt native initialization proof '+name)
 for p in json.loads((ROOT/STATUS).read_bytes())['postimages']:reject('source '+p,lambda p=p:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b'')))
 reject('foreign caller',lambda:source(changed={'src/foreign_initial.f90':'A'}))
 for p in ['initial/RESULT.json','initial/O2.nml','initial/O0-consumer.stdout','initial/O2/original_macro_initial.f90','initial/O0-macro-off.stdout','thermal-O2/replay-rutter-static-0.stdout','parent/commit.raw']:
  bad=dict(f);bad[p]+=b'!';reject('raw '+p,lambda bad=bad:validate(bad))
 return passed
if __name__=='__main__':print(json.dumps(dict(result=verify(),negative_controls=self_test()),indent=2))
