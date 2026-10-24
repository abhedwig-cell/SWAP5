import argparse,base64,hashlib,io,json,os,pathlib,subprocess,tarfile,time
root=pathlib.Path(__file__).resolve().parents[3];w=root.parent;sha=lambda b:hashlib.sha256(b).hexdigest()
raw=base64.b64decode((root/'integration/mc-sol01/drainage/ANDELST_COMPOSITION_EVIDENCE.tar.xz.b64').read_bytes());t=tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz');excluded=json.load(t.extractfile('EXCLUDED.json'))
ap=argparse.ArgumentParser();ap.add_argument('--optimization',nargs='+',choices=['O0','O2'],default=['O0','O2']);args=ap.parse_args()
results=[]
for opt in args.optimization:
 out=w/('macro-robin-qualified-'+opt);out.mkdir();meta=json.load(open(w/('fresh-build-'+opt)/'column/build-complete.json'));probe=w/('andelst-macro-bbc6-'+opt)
 for p,h in meta['reused_artifact_sha256'].items():assert sha(pathlib.Path(p).read_bytes())==h,p
 objects=[];overrides={'src/runtime/mod_fmr_serialized_reference_backend.f90':'candidate_backend.o','src/adapter/mod_reference_richards_legacy_binding.f90':'candidate_binding.o'}
 for e in meta['source_build']['events']:
  if e['category']!='compile' or e['command'][-3].endswith('/app/solute_crop/main.f90'):continue
  src,obj=e['command'][-3],e['command'][-1]
  for p,name in overrides.items():
   if src.endswith('/'+p):
    obj=str(probe/name);assert sha(pathlib.Path(obj).read_bytes())==excluded['andelst-macro-bbc6-'+opt+'/'+name]['sha256']
  objects.append(obj)
 for p,h in meta['input_sha256'].items():
  if p in overrides:continue
  assert sha((root/p).read_bytes())==h,p
 flags=[f for f in meta['flags']if not f.startswith('-J')];archive=[p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a')]
 driver=root/'tests/nut-sol/test_cauchy3_macropore_oracle.f90';cmd=meta['compiler_command']+['-I'+str(probe),*flags,'-J'+str(out),str(driver),*objects,*archive,'-o',str(out/'driver')]
 events=[]
 for label,command in [('compile',cmd),('native',[str(out/'driver')])]:
  start=time.perf_counter();cp=subprocess.run(command,cwd=out,capture_output=True,env={**os.environ,'PATH':str(w/'compiler/bin')+':'+os.environ['PATH']})
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  events.append(dict(category=label,command=command,returncode=cp.returncode,seconds=time.perf_counter()-start))
  (out/'events.json').write_text(json.dumps(events,indent=2))
  if cp.returncode:print(opt,label,cp.stderr.decode()[-2500:],cp.stdout.decode()[-1500:]);raise SystemExit(1)
 print(opt,cp.stdout.decode().splitlines()[-1],flush=True)
 native=out/'native';native.mkdir();exe=native/'swap5_solute_project';driver=root/'app/solute_project/main.f90'
 command=meta['compiler_command']+['-I'+str(probe),*flags,'-J'+str(native),str(driver),*objects,*archive,'-o',str(exe)]
 start=time.perf_counter();cp=subprocess.run(command,cwd=native,capture_output=True,env={**os.environ,'PATH':str(w/'compiler/bin')+':'+os.environ['PATH']})
 (native/'compile.stderr').write_bytes(cp.stderr);assert cp.returncode==0,cp.stderr.decode()
 inputs={p:sha((root/p).read_bytes())for p in meta['input_sha256']}
 build=dict(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),generated_input_sha256={},input_sha256=inputs,executable_sha256=sha(exe.read_bytes()),compiler=meta['compiler'],flags=flags,
  reused_provider_objects=len(objects),reused_provider_artifact_sha256={p:sha(pathlib.Path(p).read_bytes())for p in objects},
  prior_provider_build=meta,events=[dict(command=command,category='link_current_application',returncode=cp.returncode,seconds=time.perf_counter()-start)])
 (native/'build-complete.json').write_text(json.dumps(build,indent=2))
 source=w/('retained/native-'+opt+'/full')
 common=[str(pathlib.Path(os.sys.executable)),str(root/'tools/solute/run_column.py'),'--exe',str(exe),'--input',str(source/'input.nml'),'--swp',str(source/'input.swp')]
 for label,extra in [('full',['--stop-after','481']),('split',['--stop-after','365']),('resumed',['--stop-after','481','--restart',str(native/'split')])]:
  command=common+['--output',str(native/label)]+extra;start=time.perf_counter();cp=subprocess.run(command,cwd=root,capture_output=True)
  for stream in ['stdout','stderr']:(native/(label+'.'+stream)).write_bytes(getattr(cp,stream))
  build['events'].append(dict(command=command,category=label,returncode=cp.returncode,seconds=time.perf_counter()-start));(native/'build-complete.json').write_text(json.dumps(build,indent=2))
  assert cp.returncode==0,cp.stderr.decode()[-2500:]
 for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
  assert(native/'full'/name).read_bytes()==(source/name).read_bytes(),(opt,name)
  if name!='budget.csv':assert(native/'full'/name).read_bytes()==(native/'resumed'/name).read_bytes(),(opt,'restart',name)
 print(opt,'CURRENT_BBC481_AND365_RESTART_BYTES_EXACT',flush=True)

