"""Seal complete bounded runtime evidence, never scientific/production promotion."""
import argparse,copy,hashlib,io,json,struct,tarfile,tempfile,zipfile,zlib
from pathlib import Path,PurePosixPath,PureWindowsPath
import film_runtime as runtime
from film_runtime_audit import audit,ledger,rows
from film_runtime_profiles import profile4
ROOT=runtime.ROOT;BASE=runtime.BASE;STEM='FILM_RUNTIME_WINDOWS_20261104'
sha=lambda b:hashlib.sha256(b).hexdigest()

def key(path,root,workspace):
 value=path.replace('\\','/')
 if value.startswith(root+'/'):return 'source-snapshot/'+value[len(root)+1:]
 assert value.startswith(workspace+'/'),value
 return value[len(workspace)+1:]

def source_binding(files,opt,observed=False):
 prefix=opt+('/build-observed/'if observed else'/build/');b=json.loads(files[prefix+'BUILD.json']);old=b['baseline']
 main=list(old['source_sha256'])[-1].replace('\\','/');suffix='/app/solute_project/main.f90';assert main.endswith(suffix);root=main[:-len(suffix)]
 archive=old['ttutil_archive'].replace('\\','/');suffix='/baseline-'+opt+'/libttutil.a';assert archive.endswith(suffix);workspace=archive[:-len(suffix)]
 assert old['status']=='BUILT'and old['build_mode']=='clean-source'and old['reuse_candidate']is None
 assert len(old['source_sha256'])==len(b['source_sha256'])==len(b['object_sha256'])==236 and b['complete_module_closure_rebuilt']
 assert set(b['interventions'])==({runtime.counter.SOURCE,runtime.counter.MAIN}if observed else{runtime.counter.SOURCE})
 clean=lambda flags:[x for x in flags if not x.startswith(('-I','-J'))]
 assert clean(b['flags'])==clean(old['flags'])==['-'+opt,'-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
 source=files['source-snapshot/'+runtime.counter.SOURCE].decode().replace('\r\n','\n');candidate=runtime.counter.candidate.candidate(source)
 assert b['numerical_candidate_sha256']==sha(candidate.encode())
 events=b['events'];assert len(events)==237 and all(e['returncode']==0 for e in events)
 assert events==json.loads(files[prefix+'EVENTS.json'])
 actual=list(b['source_sha256'].items());objects=list(b['object_sha256'].items());external=0
 for i,(before,pin)in enumerate(old['source_sha256'].items()):
  oldkey=key(before,root,workspace);raw=files[oldkey];assert sha(raw)==pin
  relative=oldkey.removeprefix('source-snapshot/')if oldkey.startswith('source-snapshot/')else None
  if relative:assert raw.replace(b'\r\n',b'\n')==(ROOT/relative).read_bytes().replace(b'\r\n',b'\n')
  else:external+=1;assert PurePosixPath(oldkey).name=='legacy_swp_original.f90'
  name,digest=actual[i];after=files[key(name,root,workspace)];assert sha(after)==digest
  if relative==runtime.counter.SOURCE:assert after.decode().replace('\r\n','\n')==(runtime.counter.kernel(candidate)if observed else candidate)
  elif observed and relative==runtime.counter.MAIN:assert after.decode().replace('\r\n','\n')==runtime.counter.main(raw.decode().replace('\r\n','\n'))
  else:assert after==raw
  cmd=events[i]['command'];assert clean(cmd[1:cmd.index('-c')])==clean(b['flags'])and cmd[cmd.index('-c')+1]==name
  obj,pin=objects[i];assert cmd[-2]=='-o'and cmd[-1]==obj and obj.replace('\\','/').endswith('/'+str(i)+'.o')
  assert sha(files[key(obj,root,workspace)])==pin
 assert external==1
 # Platform is determined by the retained actual executable name, not host OS.
 candidates=[prefix+'swap5_hupsel_germination.exe',prefix+'swap5_hupsel_germination'];present=[p for p in candidates if p in files];assert len(present)==1 and sha(files[present[0]])==b['executable_sha256']
 pub=old['publication_provider'];assert sha(files[key(pub['source'],root,workspace)])==pub['source_sha256']
 assert sha(files[key(pub['object'],root,workspace)])==pub['object_sha256']and sha(files[key(old['ttutil_archive'],root,workspace)])==old['archive_sha256']
 args=files[prefix+'link.args'].decode().splitlines();offset=2 if '"-Wl,--stack,16777216"'in args else 1
 assert args[0]=='"-fopenmp"'and all(args[i+offset].strip('"')==objects[i][0].replace('\\','/')for i in range(236))
 assert [x.strip('"')for x in args[offset+236:]]==[pub['object'].replace('\\','/'),old['ttutil_archive'].replace('\\','/'),'-o',events[-1]['command'][1][1:].replace('\\','/').removesuffix('/link.args')+'/'+PurePosixPath(present[0]).name]
 assert events[-1]['command'][1].startswith('@')
 return b


def control_binding(folder,files,opt,build):
 from production_diagnostic_native import instrument
 base=folder/opt;sha_file=lambda p:sha(p.read_bytes());native=build['executable_sha256']
 owner=json.loads((base/'owner-controls/RESULT.json').read_text())
 assert len({e['case']for e in owner['events']})==37 and any(e['case']=='valid_nonadvancing'for e in owner['events'])
 assert owner['executable_sha256']==native and owner['checkpoint_sha256']==sha_file(base/'unobserved584/checkpoint.bin')and owner['clock']==584
 assert (base/'owner-controls/valid-original.bin').read_bytes()==(base/'unobserved584/checkpoint.bin').read_bytes()
 for e in owner['events']:
  case=base/'owner-controls'/e['case'];stdout=(case/'stdout').read_bytes();stderr=(case/'stderr').read_bytes()
  assert e['checkpoint_sha256']==sha_file(case/'restart-input.bin')
  assert e['returncode']==1 and e['status']=='PASS'and e['reached_post_read_boundary']==(e['case']=='valid_nonadvancing')
  assert (b'no requested windows remain'in stdout+stderr)==(e['case']=='valid_nonadvancing')
  if e['case']!='valid_nonadvancing':assert b'source rotation envelope rejected before publication'in stdout or b'restart rejected'in stdout
  assert not any((case/n).exists()for n in ('budget.csv','checkpoint.bin','restart.bin','crop.csv','germination.csv'))
 app=json.loads((base/'app-refusals/RESULT.json').read_text());original=(base/'unobserved584/checkpoint.bin').read_bytes()
 assert {e['case']for e in app['events']}=={'legacy3','missing','extra','crc','changed_input',*[f'{field}_{kind}'for field in (0,1)for kind in ('nan','posinf','neginf')]}
 for e in app['events']:
  kind=e['case'];case=base/'app-refusals'/kind;data=bytearray(original)
  if kind=='legacy3':data[:8]=b'S5HR0003'
  elif kind=='missing':del data[-20:-4]
  elif kind=='extra':data[-4:-4]=b'unsupported'
  elif kind=='crc':data[-20]^=1
  elif kind=='changed_input':assert (case/'grass.crp').read_bytes()==(base/'unobserved584/grass.crp').read_bytes()+b'\n'
  else:
   field,value=kind.split('_');struct.pack_into('=d',data,len(data)-20+8*int(field),dict(nan=float('nan'),posinf=float('inf'),neginf=-float('inf'))[value])
  if kind!='crc':struct.pack_into('=I',data,len(data)-4,zlib.crc32(data[:-4]))
  assert (case/'input.bin').read_bytes()==data and b'source rotation envelope rejected before publication'in(case/'stdout').read_bytes()
  assert e['returncode']==1 and not any((case/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin'))
 writer=json.loads((base/'writer-build/BUILD.json').read_text());source=base/'writer-build/main_writer_probe.f90'
 assert source.read_text()==instrument((ROOT/runtime.counter.MAIN).read_text())and sha_file(source)==writer['instrumented_main_sha256']
 assert sha_file(base/'build/BUILD.json')==writer['parent_build_sha256']
 exe=next(p for p in (base/'writer-build/writer-probe.exe',base/'writer-build/writer-probe')if p.exists());assert sha_file(exe)==writer['executable_sha256']
 measured=json.loads((base/'writer-qualification/RESULT.json').read_text());assert measured['executable_sha256']==native and measured['probe_executable_sha256']==sha_file(exe)
 w=base/'writer-qualification';assert (w/'continuous2/checkpoint.bin').read_bytes()==(w/'restart2/checkpoint.bin').read_bytes()==(w/'writer2/checkpoint.bin').read_bytes()
 for name in ('budget.csv','crop.csv'):assert (w/'continuous2'/name).read_bytes()==(w/'writer2'/name).read_bytes()
 assert [' '.join(line.split())for line in(w/'writer2/writer_probe.dat').read_text().splitlines()]==['1 1 1','1 2 1','1 3 1','2 1 1','2 2 1','2 3 1']
 assert not list((w/'writer2').glob('checkpoint.bin.*'))

def verify(folder,files):
 registration=json.loads(files['REGISTRATION.json']);assert registration==json.loads((BASE/'FILM_RUNTIME_PREREGISTRATION_20261104.json').read_text())
 assert registration['production_admission']is False and registration['whole_scientific_admission']is False
 result={}
 for opt in ('O0','O2'):
  build=source_binding(files,opt);marker=json.loads(files[opt+'/EXECUTED.json']);assert marker['production_admission']is False and marker['whole_scientific_admission']is False
  proof=audit(folder/opt)
  for name in ('app-refusals/RESULT.json','owner-controls/RESULT.json','writer-qualification/RESULT.json'):
   assert opt+'/'+name in files
  app=json.loads(files[opt+'/app-refusals/RESULT.json']);assert len(app['events'])==11
  assert all(e['returncode']==1 for e in app['events'])
  owner=json.loads(files[opt+'/owner-controls/RESULT.json']);assert len(owner['events'])==37 and all(e['status']=='PASS'and e['returncode']==1 for e in owner['events'])
  writer=json.loads(files[opt+'/writer-qualification/RESULT.json']);assert writer['finite_writer_refusals']==6 and writer['each_failed_write_preserves_prior_target_bytes']and writer['strict_restart_exact']
  assert len(writer['events'])==4 and all(e['returncode']==0 for e in writer['events'])
  control_binding(folder,files,opt,build)
  original=json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
  for name,pin in original['files_sha256'].items():assert sha(files[opt+'/unobserved584/'+name])==pin
  if opt=='O2':source_binding(files,opt,True)
  proof['real_native_controls']=dict(owner=37,app=11,public_writer=6);result[opt]=proof
 return dict(status='ACTUAL_PRIVATE_DEFAULT584_OWN_RESTART_OBSERVATION_AND_REAL_CONTROLS_PASS',platform_builds=result,production_admission=False,whole_scientific_admission=False,full1096_runtime_qualified=False)

def data_controls(folder,files):
 opt=folder/'O2';case=opt/'unobserved584';windows=[{k:float(v)for k,v in r.items()}for r in rows(case/'budget.csv')];crops=rows(case/'crop.csv');point=profile4((case/'checkpoint.bin').read_bytes());state=rows(case/'state.csv');trials=[]
 def rejected(fn):
  try:fn()
  except(AssertionError,KeyError,ValueError):return
  raise AssertionError('runtime data defect accepted')
 bad=copy.deepcopy(windows);bad[-1]['water_end_cm']+=1e-5;rejected(lambda:ledger(bad,crops,point,state));trials.append('water_mass')
 bad=copy.deepcopy(windows);bad[-1]['solute_residual_mg_cm2']=1e-5;rejected(lambda:ledger(bad,crops,point,state));trials.append('solute_report')
 rejected(lambda:ledger(windows[:-1],crops,point,state));trials.append('truncated_prefix')
 bad=copy.deepcopy(crops);bad[-1]['accepted_canopy_stock_cm']=str(float(bad[-1]['post_management_capacity_cm'])+1e-5);rejected(lambda:ledger(windows,bad,point,state));trials.append('canopy_capacity')
 bad=copy.deepcopy(point);bad['water_stock_cm']+=1e-5;rejected(lambda:ledger(windows,crops,bad,state));trials.append('primitive_stock')
 for flag in ('production_admission','whole_scientific_admission'):
  altered=dict(files);r=json.loads(altered['REGISTRATION.json']);r[flag]=True;altered['REGISTRATION.json']=json.dumps(r).encode();rejected(lambda:verify(folder,altered));trials.append(flag)
 b=json.loads(files['O0/build/BUILD.json']);root=list(b['baseline']['source_sha256'])[-1].replace('\\','/').removesuffix('/app/solute_project/main.f90');workspace=b['baseline']['ttutil_archive'].replace('\\','/').removesuffix('/baseline-O0/libttutil.a')
 for label,path in [('object_digest',key(next(iter(b['object_sha256'])),root,workspace)),('kernel_source',key(next(p for p in b['source_sha256']if p.endswith('waterfilm_private.f90')),root,workspace))]:
  altered=dict(files);altered[path]+=b'\n';rejected(lambda:source_binding(altered,'O0'));trials.append(label)
 for label,change in [('unchecked_build_flags',lambda r:r['flags'].append('-ffast-math')),('failed_compile_event',lambda r:r['events'][0].update(returncode=1))]:
  altered=dict(files);r=json.loads(altered['O0/build/BUILD.json']);change(r);altered['O0/build/BUILD.json']=json.dumps(r).encode();rejected(lambda:source_binding(altered,'O0'));trials.append(label)
 return trials


def snapshot(folder):
 """Retain exact root providers beside portable raw native artifacts."""
 folder=folder.resolve();target=folder/'source-snapshot'
 for opt in ('O0','O2'):
  path=folder/opt/'build/BUILD.json'
  if not path.exists():continue
  b=json.loads(path.read_text())
  for name,pin in b['baseline']['source_sha256'].items():
   item=Path(name)
   if item.is_relative_to(ROOT):
    raw=item.read_bytes();assert sha(raw)==pin;dest=target/item.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
 dest=target/'app/support/restart_publish.c';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((ROOT/'app/support/restart_publish.c').read_bytes())
 (folder/'REGISTRATION.json').write_bytes((BASE/'FILM_RUNTIME_PREREGISTRATION_20261104.json').read_bytes())


def verify_posix(paths):
 files={};archives={}
 for opt,path in zip(('O0','O2'),paths):
  raw=path.read_bytes();archives[opt]=dict(archive=path.name,archive_sha256=sha(raw))
  with zipfile.ZipFile(io.BytesIO(raw))as z:
   names=[n for n in z.namelist()if not n.endswith('/')];assert len(names)==len(set(names))
   assert all(not PurePosixPath(n).is_absolute()and not PureWindowsPath(n).drive and '..'not in PurePosixPath(n).parts for n in names)
   preservation=json.loads(z.read('film-preservation/RESULT.json'));assert preservation['status']=='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS'and preservation['whole_scientific_admission']is False
   for name in names:
    if not name.startswith('film-runtime/'):continue
    name2=name.removeprefix('film-runtime/');data=z.read(name)
    assert name2.startswith((opt+'/', 'baseline-'+opt+'/', 'source-snapshot/'))or name2=='REGISTRATION.json'
    if name2 in files:assert files[name2]==data
    files[name2]=data
 with tempfile.TemporaryDirectory(prefix='film-runtime-posix-')as temp:
  folder=Path(temp).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('film-runtime-posix-')
  for name,raw in files.items():dest=folder/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
  result=verify(folder,files);result['data_refusals']=data_controls(folder,files)
 return dict(result,original_artifacts=archives,files_sha256={n:sha(raw)for n,raw in files.items()})

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--snapshot',type=Path);p.add_argument('--posix-zips',type=Path,nargs=2);p.add_argument('--posix',action='store_true');a=p.parse_args()
 if a.snapshot:snapshot(a.snapshot);print('EXACT_RUNTIME_SOURCE_SNAPSHOT_RETAINED');return
 if a.posix_zips:
  result=verify_posix(a.posix_zips);(BASE/'FILM_RUNTIME_POSIX_20261104.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status']);return
 if a.posix:
  record=json.loads((BASE/'FILM_RUNTIME_POSIX_20261104.json').read_text());paths=[BASE/record['original_artifacts'][o]['archive']for o in ('O0','O2')]
  assert all(sha(p.read_bytes())==record['original_artifacts'][o]['archive_sha256']for o,p in zip(('O0','O2'),paths))
  result=verify_posix(paths);assert result==record;print(result['status']);return
 if a.capture:
  folder=a.capture.resolve();files={'REGISTRATION.json':(BASE/'FILM_RUNTIME_PREREGISTRATION_20261104.json').read_bytes()}
  for opt in ('O0','O2'):assert (folder/opt/'EXECUTED.json').is_file()
  keep={'.json','.csv','.bin','.dat','.f90','.c','.a','.o','.exe','.stdout','.stderr','.args','.nml','.swp','.crp','.met','.dra'}
  for path in folder.rglob('*'):
   if not path.is_file()or path.suffix not in keep and path.name not in ('stdout','stderr','swap5_hupsel_germination','writer-probe'):continue
   rel=path.relative_to(folder).as_posix()
   if not rel.startswith(('O0/','O2/','baseline-O0/','baseline-O2/','source-snapshot/'))and rel!='REGISTRATION.json':continue
   if rel.startswith('baseline-')and path.suffix in ('.o','.exe')and path.name!='restart_publish.o':continue
   files[rel]=path.read_bytes()
  for opt in ('O0','O2'):
   for variant in ('build','build-observed')if opt=='O2'else('build',):
    b=json.loads(files[opt+'/'+variant+'/BUILD.json'])
    for path in b['baseline']['source_sha256']:
     item=Path(path)
     if item.is_relative_to(ROOT):files['source-snapshot/'+item.relative_to(ROOT).as_posix()]=item.read_bytes()
  files['source-snapshot/app/support/restart_publish.c']=(ROOT/'app/support/restart_publish.c').read_bytes()
  result=verify(folder,files);result['data_refusals']=data_controls(folder,files)
  archive=BASE/(STEM+'.tar.xz')
  with tarfile.open(archive,'w:xz',preset=3)as t:
   for name,raw in sorted(files.items()):i=tarfile.TarInfo(name);i.size=len(raw);t.addfile(i,io.BytesIO(raw))
  (BASE/(STEM+'.json')).write_text(json.dumps(dict(result,archive=archive.name,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(raw)for n,raw in files.items()}),indent=2)+'\n')
 else:
  r=json.loads((BASE/(STEM+'.json')).read_text());assert r['production_admission']is False and r['whole_scientific_admission']is False
  raw=(BASE/r['archive']).read_bytes();assert sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   members=t.getmembers();assert len(members)==len(r['files_sha256'])and all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive and '..'not in PurePosixPath(m.name).parts for m in members)
   files={m.name:t.extractfile(m).read()for m in members}
  assert set(files)==set(r['files_sha256'])and all(sha(raw)==r['files_sha256'][n]for n,raw in files.items())
  with tempfile.TemporaryDirectory(prefix='film-runtime-audit-')as temp:
   folder=Path(temp).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('film-runtime-audit-')
   for name,raw in files.items():dest=folder/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
   result=verify(folder,files);result['data_refusals']=data_controls(folder,files)
   assert result=={k:v for k,v in r.items()if k not in ('archive','archive_sha256','files_sha256')}
 print(json.dumps(result))
if __name__=='__main__':main()
